import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/library_controller.dart';
import '../data/model.dart';
import 'context.dart';
import 'merge.dart';
import 'remote.dart';

class SyncCoordinator extends ChangeNotifier {
  SyncCoordinator(this.controller, this.context, {this.automatic = true}) {
    controller.addListener(_changed);
    _seenGeneration = controller.localGeneration;
    if (context.account != null && automatic) {
      _poll = Timer.periodic(const Duration(seconds: 12), (_) => syncNow());
      scheduleMicrotask(() async {
        await _loadLegacy();
        await syncNow();
      });
    }
  }
  final LibraryController controller;
  final SyncContext context;
  final bool automatic;
  Timer? _poll, _debounce;
  int _seenGeneration = 0;
  bool signInRequired = false;
  bool busy = false,
      disposed = false,
      accountMismatch = false,
      legacyError = false;
  bool get available => context.remote != null;
  bool get signedIn => context.account != null;
  int legacyBooks = 0, legacyRecords = 0, conflictCopies = 0;
  String phase = 'ready';
  bool get hasLegacy =>
      !controller.library.sync.legacyImported && legacyRecords > 0;
  String get message {
    if (!available) {
      return '이 기기에 보관';
    }
    if (accountMismatch) {
      return '계정이 바뀌었습니다. 다시 불러와 주세요.';
    }
    if (!signedIn) {
      return '로그인하면 다른 기기에서 이어 쓸 수 있어요';
    }
    return switch (phase) {
      'busy' => '기기 간 동기화 중',
      'synced' => '기기 간 동기화 완료',
      'incoming' => '새 기록 도착 · 입력을 마치면 반영',
      'composing' => '한글 입력을 마치면 동기화',
      'offline' => '기기에 저장됨 · 연결되면 다시 동기화',
      'sign_in_required' => '다시 로그인하면 동기화할 수 있어요',
      'too_large' => '서버 저장 범위를 넘었습니다 · 기기 기록은 보존',
      'legacy_error' => '기존 기기 기록을 읽지 못했습니다 · 원본은 보존',
      'local_error' => '기기 저장을 확인한 뒤 동기화해 주세요',
      'invalid_library' => '기록 구조 확인이 필요합니다 · 기기 기록은 보존',
      _ => '기기에 저장됨 · 동기화 대기',
    };
  }

  void _notify() {
    if (!disposed) {
      notifyListeners();
    }
  }

  Future<void> _loadLegacy() async {
    if (disposed) {
      return;
    }
    try {
      final legacy = await context.legacy?.load();
      if (legacy != null && legacy.sync.accountId == null) {
        legacyBooks = legacy.books.length;
        legacyRecords = legacy.records.length;
        _notify();
      }
    } catch (_) {
      legacyError = true;
      _notify();
    }
  }

  Future<void> inspectLegacy() => _loadLegacy();
  void _changed() {
    if (disposed || !signedIn || accountMismatch) {
      return;
    }
    final changed = _seenGeneration != controller.localGeneration;
    if (changed) {
      _seenGeneration = controller.localGeneration;
      if (!busy) {
        phase = 'pending';
        _notify();
      }
    }
    if (automatic && (changed || phase == 'composing' || phase == 'incoming')) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1000), () => syncNow());
    }
  }

  Future<void> importLegacy() async {
    if (!signedIn || !hasLegacy || busy || accountMismatch) {
      return;
    }
    try {
      final legacy = await context.legacy!.load();
      if (legacy.sync.accountId != null) {
        return;
      }
      final merged = mergeLibraries(
        const Library(),
        legacy,
        controller.library,
      );
      final old = controller.library.sync;
      final metadata = SyncMetadata(
        accountId: context.account!.userId,
        revision: old.revision,
        baseline: old.baseline,
        lastSyncedAt: old.lastSyncedAt,
        legacyImported: true,
      );
      controller.importLocal(merged.library.copy(sync: metadata));
      await controller.settled;
      await syncNow();
    } catch (_) {
      phase = 'legacy_error';
      legacyError = true;
      _notify();
    }
  }

  Library _cloudView(Library local) {
    final metadata = local.sync;
    if (metadata.positionDirty || metadata.baseline == null) {
      return local;
    }
    final base = Library.decode(jsonEncode(metadata.baseline));
    return local.copy(
      activePageId: base.activePageId,
      clearActive: base.activePageId == null,
      writing: base.writing,
    );
  }

  Future<void> syncNow() async {
    if (disposed || busy || !signedIn || accountMismatch) {
      return;
    }
    if (controller.composing) {
      phase = 'composing';
      _notify();
      return;
    }
    busy = true;
    phase = 'busy';
    _notify();
    try {
      final identity = await context.remote!.session();
      if (identity.userId != context.account!.userId ||
          (controller.library.sync.accountId != null &&
              controller.library.sync.accountId != identity.userId)) {
        accountMismatch = true;
        _notify();
        return;
      }
      signInRequired = false;
      await controller.settled;
      if (controller.saveError != null) {
        phase = 'local_error';
        return;
      }
      for (var attempt = 0; attempt < 4; attempt++) {
        final cloud = await context.remote!.read();
        if (disposed) {
          return;
        }
        final local = controller.library;
        final capturedPosition = controller.positionGeneration;
        final projected = _cloudView(local);
        final base = local.sync.baseline == null
            ? const Library()
            : Library.decode(jsonEncode(local.sync.baseline));
        var result = mergeLibraries(
          base,
          projected,
          cloud.library ?? const Library(),
        );
        var next = result.library;
        final preview =
            controller.localGeneration > 0 && local.activePage != null
            ? next.copy(
                activePageId: local.activePageId,
                writing: local.writing,
              )
            : next;
        if (!controller.canApplySync(preview)) {
          phase = 'incoming';
          return;
        }
        CloudSnapshot accepted;
        try {
          accepted =
              cloud.library != null &&
                  sameData(cloud.library!.toCloudJson(), next.toCloudJson())
              ? cloud
              : await context.remote!.write(cloud.revision, next);
        } on RevisionConflict {
          continue;
        }
        if (disposed) {
          return;
        }
        // Rebase edits made while the request was in flight; never replace them
        // with the earlier snapshot that was just acknowledged by the server.
        final latest = controller.library;
        final rebased = mergeLibraries(
          projected,
          _cloudView(latest),
          accepted.library!,
        );
        var applied = rebased.library;
        if (controller.localGeneration > 0 && latest.activePage != null) {
          applied = applied.copy(
            activePageId: latest.activePageId,
            writing: latest.writing,
          );
        }
        final metadata = SyncMetadata(
          accountId: identity.userId,
          revision: accepted.revision,
          baseline: accepted.library!.toCloudJson(),
          lastSyncedAt: accepted.updatedAt,
          legacyImported: latest.sync.legacyImported,
          positionDirty: controller.positionGeneration != capturedPosition,
        );
        if (!controller.canApplySync(applied)) {
          phase = 'incoming';
          return;
        }
        final finalLibrary = applied.copy(sync: metadata);
        final persisted =
            sameData(controller.library.toJson(), finalLibrary.toJson())
            ? true
            : await controller.applySync(finalLibrary);
        if (disposed) {
          return;
        }
        if (!persisted) {
          phase = 'local_error';
          return;
        }
        conflictCopies += result.conflictCopies + rebased.conflictCopies;
        phase =
            sameData(
              _cloudView(controller.library).toCloudJson(),
              accepted.library!.toCloudJson(),
            )
            ? 'synced'
            : 'pending';
        if (phase == 'pending' && automatic) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(seconds: 1), syncNow);
        }
        return;
      }
      phase = 'pending';
    } on CloudFailure catch (e) {
      if (e.code == 'sign_in_required') {
        signInRequired = true;
      }
      if (e.code == 'account_changed') {
        accountMismatch = true;
      }
      phase = e.code == 'unavailable' ? 'offline' : e.code;
    } catch (_) {
      phase = 'offline';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    disposed = true;
    _poll?.cancel();
    _debounce?.cancel();
    controller.removeListener(_changed);
    context.remote?.close();
    super.dispose();
  }
}
