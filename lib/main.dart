import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'data/library_controller.dart';
import 'entry_location.dart';
import 'data/store.dart';
import 'sync/context.dart';
import 'source/source_intake.dart';
import 'sync/context_factory.dart';
import 'sync/coordinator.dart';
import 'ui/workspace.dart';
import 'ui/paper.dart';
import 'ui/typography.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Make the web app usable by assistive technology without a hidden opt-in.
  SemanticsBinding.instance.ensureSemantics();
  normalizeEntryLocation();
  runApp(const WritingHumanApp());
}

class WritingHumanApp extends StatelessWidget {
  const WritingHumanApp({super.key, this.store, this.sourceIntake});
  final LibraryStore? store;
  final SourceIntake? sourceIntake;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '쓰는 인간',
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(textScaler: ReadingTextScaler(media.textScaler)),
        child: child!,
      );
    },
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: appFontFamily,
      fontFamilyFallback: appFontFallback,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandInk,
        surface: paper,
        primary: brandInk,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: appPaper,
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: appFontFamily,
        fontFamilyFallback: appFontFallback,
        bodyColor: ink,
        displayColor: ink,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: brandInk),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
    ),
    home: _Bootstrap(store: store, sourceIntake: sourceIntake),
  );
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap({this.store, this.sourceIntake});
  final LibraryStore? store;
  final SourceIntake? sourceIntake;
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> with WidgetsBindingObserver {
  SyncContext? syncContext;
  SyncCoordinator? sync;
  LibraryController? controller;
  LibraryStore? store;
  Object? error;
  late final bool ownsStore = widget.store == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      if (store == null) {
        if (widget.store != null) {
          store = widget.store;
        } else {
          syncContext ??= await openSyncContext();
          store = syncContext!.store;
        }
      }
      final library = await store!.load();
      if (!mounted) {
        return;
      }
      setState(() {
        controller = LibraryController(store!, library);
        if (syncContext != null) {
          sync = SyncCoordinator(controller!, syncContext!);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      sync?.syncNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sync?.dispose();
    final c = controller;
    c?.dispose();
    if (ownsStore) {
      c?.settled.then((_) => store?.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return Workspace(
        controller: controller!,
        sync: sync,
        sourceIntake: widget.sourceIntake,
      );
    }
    return Scaffold(
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '기록을 불러오지 못했습니다.',
                      style: TextStyle(fontSize: 21),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '기존 기록을 보호하기 위해 새 저장을 시작하지 않습니다.\n저장소 접근을 확인한 뒤 다시 시도해 주세요.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('다시 불러오기'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
