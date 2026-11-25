import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'paper.dart';

/// Navigation belongs to the current app instance, never to stored writing.
class PaperNavigation extends NavigatorObserver with ChangeNotifier {
  final _routes = <Route<dynamic>>[];
  final _titles = <Route<dynamic>, String>{};
  bool _notifying = false, _returning = false, _disposed = false;
  String? Function()? currentWritingPageId;
  Future<bool> Function()? canReturnToWriting;

  void _changed() {
    if (_notifying || _disposed) return;
    _notifying = true;
    scheduleMicrotask(() {
      _notifying = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    canReturnToWriting = null;
    currentWritingPageId = null;
    super.dispose();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _titles.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _titles.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _titles.remove(oldRoute);
    _changed();
  }

  void name(BuildContext context, String title) {
    final route = ModalRoute.of(context);
    if (route != null && _routes.contains(route) && _titles[route] != title) {
      _titles[route] = title;
      _changed();
    }
  }

  String parentLabel(BuildContext context) {
    final route = ModalRoute.of(context);
    final index = route == null ? -1 : _routes.indexOf(route);
    return index <= 1 ? '쓰던 쪽' : _titles[_routes[index - 1]] ?? '이전 화면';
  }

  bool hasParentScreen(BuildContext context) {
    final route = ModalRoute.of(context);
    return route != null && _routes.indexOf(route) > 1;
  }

  /// maybePop respects every form's PopScope, including intermediate screens.
  /// A refused pop must never be bypassed by popUntil or by an origin shortcut.
  Future<bool> returnToWriting() async {
    if (_returning || navigator == null) return false;
    _returning = true;
    try {
      if (await canReturnToWriting?.call() == false) return false;
      for (var count = 0; count < 64 && _routes.length > 1; count++) {
        final top = _routes.last;
        final handled = await navigator!.maybePop();
        await WidgetsBinding.instance.endOfFrame;
        if (!handled || navigator == null) return false;
        if (_routes.isNotEmpty && identical(_routes.last, top)) {
          // An internal list/detail back may now permit leaving the route.
          // A form/save guard, or a newly opened confirmation, ends this request.
          if (top.popDisposition == RoutePopDisposition.doNotPop) return false;
        } else if (_routes.isNotEmpty && _routes.last is PopupRoute) {
          return false;
        }
      }
      return _routes.length <= 1;
    } finally {
      _returning = false;
    }
  }
}

class PaperNavigationScope extends InheritedNotifier<PaperNavigation> {
  const PaperNavigationScope({
    super.key,
    required PaperNavigation navigation,
    required super.child,
  }) : super(notifier: navigation);

  static PaperNavigation? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PaperNavigationScope>()
      ?.notifier;
}

class PaperBackButton extends StatelessWidget {
  const PaperBackButton({
    super.key,
    this.label,
    this.onPressed,
    this.enabled = true,
  });
  final String? label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final target =
        label ??
        PaperNavigationScope.maybeOf(context)?.parentLabel(context) ??
        '뒤로';
    return Tooltip(
      message: target,
      child: TextButton.icon(
        key: const ValueKey('paper-back'),
        onPressed: enabled
            ? onPressed ?? () => Navigator.maybePop(context)
            : null,
        icon: const Icon(CupertinoIcons.chevron_left, size: 17),
        label: Text(target, maxLines: 2, textAlign: TextAlign.start),
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(
            fontFamily: appFontFamily,
            fontFamilyFallback: appFontFallback,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class PaperWritingReturn extends StatelessWidget {
  const PaperWritingReturn({
    super.key,
    this.force = false,
    this.enabled = true,
  });
  final bool force, enabled;

  @override
  Widget build(BuildContext context) {
    final navigation = PaperNavigationScope.maybeOf(context);
    if (navigation == null ||
        (!force && !navigation.hasParentScreen(context))) {
      return const SizedBox.shrink();
    }
    return TextButton(
      key: const ValueKey('return-to-writing'),
      onPressed: enabled ? navigation.returnToWriting : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: const Text('쓰던 쪽', style: TextStyle(fontSize: 14)),
    );
  }
}

/// A local list/detail step cannot use a route's native pop animation. Only
/// its empty outer edge participates; content drags keep their own recognizers.
class PaperInternalBack extends StatefulWidget {
  const PaperInternalBack({
    super.key,
    required this.enabled,
    required this.onBack,
    required this.child,
  });
  final bool enabled;
  final VoidCallback onBack;
  final Widget child;
  @override
  State<PaperInternalBack> createState() => _PaperInternalBackState();
}

class _PaperInternalBackState extends State<PaperInternalBack> {
  double distance = 0;
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || Theme.of(context).platform != TargetPlatform.iOS) {
      return widget.child;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 18,
          child: GestureDetector(
            key: const ValueKey('paper-internal-back-edge'),
            behavior: HitTestBehavior.translucent,
            excludeFromSemantics: true,
            onHorizontalDragStart: (_) => distance = 0,
            onHorizontalDragUpdate: (event) => distance += event.delta.dx,
            onHorizontalDragEnd: (event) {
              if (widget.enabled &&
                  (distance > 70 || (event.primaryVelocity ?? 0) > 700)) {
                widget.onBack();
              }
            },
          ),
        ),
      ],
    );
  }
}
