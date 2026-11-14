import 'package:flutter/material.dart';

import 'paper_palette.dart';

/// Shared appearance for the app's Material controls.
ThemeData withPaperControls(ThemeData theme) {
  const corners = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(6)),
  );
  const actionInk = panelSwitchTrack;
  const actionPaper = panelSwitchThumb;
  const pressedPaper = Color(0x2274503c);
  const hoverPaper = Color(0x1274503c);
  final feedback = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.pressed)) return pressedPaper;
    if (states.contains(WidgetState.focused)) return pressedPaper;
    if (states.contains(WidgetState.hovered)) return hoverPaper;
    return null;
  });
  final quietAction = TextButton.styleFrom(
    foregroundColor: actionInk,
    minimumSize: const Size(48, 48),
    iconSize: 17,
    shape: corners,
  ).copyWith(overlayColor: feedback);
  final primaryAction = FilledButton.styleFrom(
    backgroundColor: actionInk,
    foregroundColor: actionPaper,
    minimumSize: const Size(48, 48),
    shape: corners,
  );
  final chipInk = WidgetStateColor.resolveWith(
    (states) => states.contains(WidgetState.disabled) ? muted : actionInk,
  );
  return theme.copyWith(
    hoverColor: hoverPaper,
    focusColor: pressedPaper,
    highlightColor: pressedPaper,
    splashColor: pressedPaper,
    textButtonTheme: TextButtonThemeData(style: quietAction),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: quietAction.copyWith(
        side: const WidgetStatePropertyAll(BorderSide(color: muted)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: primaryAction),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: actionInk,
        minimumSize: const Size(48, 48),
        shape: corners,
      ).copyWith(overlayColor: feedback),
    ),
    chipTheme: theme.chipTheme.copyWith(
      shape: corners,
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? const BorderSide(color: actionInk)
            : BorderSide.none,
      ),
      backgroundColor: Colors.transparent,
      selectedColor: panelSelectedColor(paper),
      disabledColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      labelStyle: theme.textTheme.labelLarge!.copyWith(color: chipInk),
      checkmarkColor: actionInk,
      showCheckmark: true,
    ),
    checkboxTheme: theme.checkboxTheme.copyWith(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) &&
                !states.contains(WidgetState.disabled)
            ? actionInk
            : null,
      ),
      checkColor: const WidgetStatePropertyAll(actionPaper),
      overlayColor: feedback,
    ),
    switchTheme: theme.switchTheme.copyWith(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        return states.contains(WidgetState.selected)
            ? actionInk
            : panelSelectedColor(paper);
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        return states.contains(WidgetState.selected) ? actionPaper : muted;
      }),
      overlayColor: feedback,
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      iconColor: actionInk,
      selectedColor: actionInk,
      selectedTileColor: panelSelectedColor(paper),
      shape: corners,
    ),
  );
}
