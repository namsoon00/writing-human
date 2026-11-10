import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'source_intake.dart';

SourceIntake createSourceIntake() => _NativeSourceIntake();

class _NativeSourceIntake extends SourceIntake {
  static const channel = MethodChannel('writing_human/source');
  final _changes = StreamController<void>.broadcast();
  bool get _mobile => Platform.isAndroid || Platform.isIOS;

  _NativeSourceIntake() {
    if (_mobile) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'shareChanged' && !_changes.isClosed) {
          _changes.add(null);
        }
      });
    }
  }

  @override
  bool get canUseCamera => _mobile;

  @override
  Future<SourcePhoto?> recoverPhoto() async {
    if (!Platform.isAndroid) return null;
    final result = await ImagePicker().retrieveLostData();
    if (result.exception != null) {
      throw const SourceIntakeException('가져오던 사진을 열지 못했어요. 다시 골라 주세요.');
    }
    final file = result.files?.firstOrNull;
    return file == null ? null : readPhoto(file);
  }

  @override
  Future<List<String>> recognize(SourcePhoto photo) async {
    try {
      return await channel.invokeListMethod<String>('recognize', photo.path) ??
          const [];
    } on PlatformException catch (error) {
      if (error.code == 'unsupported') {
        throw const SourceIntakeException(
          '이 기기에서는 사진 속 글자를 읽을 수 없어요. 붙여넣기를 사용해 주세요.',
        );
      }
      throw const SourceIntakeException('사진 속 글자를 읽지 못했어요. 더 선명한 사진을 골라 주세요.');
    }
  }

  @override
  Stream<void> get incomingChanges => _changes.stream;

  @override
  Future<List<IncomingSource>> pendingShares() async {
    if (!_mobile) return const [];
    final values =
        await channel.invokeListMethod<Object?>('pendingShares') ?? const [];
    return [
      for (final item in values)
        if (item case {'id': final String id, 'text': final String text})
          if (id.isNotEmpty &&
              text.length <= sourceLengthLimit &&
              normalizeSource(text).isNotEmpty)
            IncomingSource(id, text),
    ];
  }

  @override
  Future<void> acknowledgeShare(String id) async {
    if (_mobile) await channel.invokeMethod<void>('acknowledgeShare', id);
  }

  @override
  void dispose() {
    if (_mobile) channel.setMethodCallHandler(null);
    _changes.close();
  }
}
