import 'package:flutter/material.dart';

import 'paper_palette.dart';

/// Shared appearance for the app's Material controls.
ThemeData withPaperControls(ThemeData theme) {
  const corners = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(3)),
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
    dividerTheme: const DividerThemeData(color: line, thickness: .7),
    sliderTheme: theme.sliderTheme.copyWith(
      activeTrackColor: actionInk,
      inactiveTrackColor: line,
      thumbColor: actionInk,
      overlayColor: pressedPaper,
      trackHeight: 1.5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1),
      activeTickMarkColor: actionInk,
      inactiveTickMarkColor: muted.withValues(alpha: .45),
    ),
    popupMenuTheme: theme.popupMenuTheme.copyWith(
      color: paper,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: brandInk.withValues(alpha: .18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
        side: BorderSide(color: line, width: .7),
      ),
    ),
    expansionTileTheme: theme.expansionTileTheme.copyWith(
      iconColor: actionInk,
      collapsedIconColor: muted,
      textColor: actionInk,
      collapsedTextColor: ink,
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
        borderSide: BorderSide(color: actionInk, width: 1.2),
      ),
    ),
    dialogTheme: theme.dialogTheme.copyWith(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        side: BorderSide(color: line, width: .7),
      ),
    ),
    bottomSheetTheme: theme.bottomSheetTheme.copyWith(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
    ),
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
