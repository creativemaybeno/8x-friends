/// **Every** design value in the app lives here.
///
/// No literal `Color`, `TextStyle`, radius, opacity or animation `Duration`
/// anywhere else in `lib/`. The design is going to be replaced wholesale by a
/// later revision; the codebase must survive that as a one-file swap.
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class Tokens {
  // --- Feature flags --------------------------------------------------------

  /// Per-person decay horizons. Off by default so the demo can fall back
  /// instantly.
  static const bool perPersonHorizon = false;

  // --- Palette --------------------------------------------------------------

  static const void_ = Color(0xFF04070A);
  static const sheetTop = Color(0xF20B1A21);
  static const sheetBottom = Color(0xFA060F14);
  static const sheetBlur = 18.0;

  static const cyan = Color(0xFF7DE7F7);
  static const cyanBright = Color(0xFF9DEFFF);
  static const body = Color(0xFFCFE9F2);
  static const heading = Color(0xFFE6F8FD);
  static const prose = Color(0xFF9AC6D3);
  static const meta = Color(0xFF5F93A3);
  static const faint = Color(0xFF4E7684);
  static const onAccent = Color(0xFF04121A);

  /// Decay and the nudge surface only. Nowhere else.
  static const amber = Color(0xFFFFB35C);

  /// The colour node fills and link strokes sink toward as decay rises.
  static const sink = Color(0xFF0B1A21);
  static const linkSink = Color(0xFF3E7E90);

  static const contextColors = <String, Color>{
    'family': Color(0xFF8FD9FF),
    'climb': Color(0xFF6FE3F5),
    'work': Color(0xFF9AA8FF),
    'uni': Color(0xFF7BF0C8),
    'hood': Color(0xFFC9A6FF),
  };

  static Color contextColor(String? context) =>
      contextColors[context] ?? cyan;

  /// Node fill = context colour lerped toward the sink by `0.15 + decay*0.66`.
  static Color nodeFill(String? context, double decay) =>
      Color.lerp(contextColor(context), sink, 0.15 + decay * 0.66)!;

  /// Node ring mixes toward amber past 0.60.
  static Color nodeRing(String? context, double decay) {
    final base = contextColor(context);
    if (decay <= 0.60) return base;
    return Color.lerp(base, amber, ((decay - 0.60) / 0.40).clamp(0.0, 1.0))!;
  }

  /// Links lerp toward [linkSink], then toward amber past 0.62.
  static Color linkColor(double decay) {
    final base = Color.lerp(cyan, linkSink, decay.clamp(0.0, 1.0))!;
    if (decay <= 0.62) return base;
    return Color.lerp(base, amber, ((decay - 0.62) / 0.38).clamp(0.0, 1.0))!;
  }

  /// Link opacity collapses past 0.92.
  static double linkOpacity(double decay) => decay <= 0.92
      ? 1.0
      : (1.0 - (decay - 0.92) / 0.08 * 0.85).clamp(0.0, 1.0);

  // --- Type -----------------------------------------------------------------
  //
  // Chakra Petch (sans) for anything human. JetBrains Mono for anything the
  // machine is reporting: uppercase, small, wide letter-spacing. Mono means the
  // app is stating a fact; sans means it is talking to you.
  //
  // google_fonts fetches on first run; a fetch failure degrades to the default
  // font rather than throwing (see [init]).

  static void init() {
    // Never let a failed font fetch take down the app on venue Wi-Fi.
    GoogleFonts.config.allowRuntimeFetching = true;
  }

  static TextStyle _sans({
    required double size,
    required FontWeight weight,
    required Color color,
    double? spacing,
    double? height,
  }) {
    final fallback = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
    );
    try {
      return GoogleFonts.chakraPetch(textStyle: fallback);
    } catch (_) {
      return fallback;
    }
  }

  static TextStyle _mono({
    required double size,
    required FontWeight weight,
    required Color color,
    required double spacing,
  }) {
    final fallback = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
    );
    try {
      return GoogleFonts.jetBrainsMono(textStyle: fallback);
    } catch (_) {
      return fallback;
    }
  }

  // Human voice.
  static TextStyle get wordmark =>
      _sans(size: 20, weight: FontWeight.w600, color: heading, spacing: 0.5);
  static TextStyle get sheetTitle =>
      _sans(size: 21, weight: FontWeight.w600, color: heading, height: 1.15);
  static TextStyle get sheetProse =>
      _sans(size: 14, weight: FontWeight.w300, color: prose, height: 1.45);
  static TextStyle get personName =>
      _sans(size: 16, weight: FontWeight.w500, color: body);
  static TextStyle get personNameLarge =>
      _sans(size: 26, weight: FontWeight.w600, color: heading);
  static TextStyle get input =>
      _sans(size: 18, weight: FontWeight.w400, color: heading);
  static TextStyle get buttonLabel =>
      _sans(size: 15, weight: FontWeight.w600, color: onAccent, spacing: 0.4);

  // Machine voice — uppercase at the call site.
  static TextStyle get monoLabel =>
      _mono(size: 9, weight: FontWeight.w400, color: meta, spacing: 1.6);
  static TextStyle get monoLabelBright =>
      _mono(size: 9, weight: FontWeight.w500, color: cyan, spacing: 1.6);
  static TextStyle get monoTiny =>
      _mono(size: 8.5, weight: FontWeight.w300, color: faint, spacing: 1.5);
  static TextStyle get monoNav =>
      _mono(size: 9.5, weight: FontWeight.w500, color: meta, spacing: 1.8);
  static TextStyle get monoStat =>
      _mono(size: 9.5, weight: FontWeight.w500, color: cyan, spacing: 1.4);
  static TextStyle get nodeLabel =>
      _mono(size: 9, weight: FontWeight.w400, color: body, spacing: 1.2);

  // --- Geometry -------------------------------------------------------------

  static const radiusSheet = 22.0;
  static const radiusCard = 14.0;
  static const radiusChip = 999.0;
  static const radiusButton = 12.0;

  static const gapXs = 6.0;
  static const gapS = 10.0;
  static const gapM = 16.0;
  static const gapL = 24.0;
  static const gapXl = 34.0;

  static const sheetPadding = EdgeInsets.fromLTRB(22, 18, 22, 26);
  static const sheetMaxHeightFraction = 0.52;
  static const rowHeight = 54.0;
  static const buttonHeight = 50.0;
  static const navHeight = 62.0;

  static const hairline = 1.0;
  static const borderColor = Color(0x1A7DE7F7);
  static const borderColorStrong = Color(0x387DE7F7);

  /// Phone-only, dark-only, 402x874 reference frame.
  static const referenceSize = Size(402, 874);

  // --- Graph draw geometry (from the design) --------------------------------

  static const nodeRadiusBase = 7.0;
  static const nodeRadiusPerCloseness = 2.4;
  static const nodeRadiusMe = 17.0;
  static const ringOffset = 6.0;
  static const haloOffset = 11.0;
  static const selectionRingOffset = 12.0;
  static const inviteHaloOffset = 15.0;
  static const nodeLabelOffset = 15.0;
  static const ringStroke = 1.1;
  static const selectionRingStroke = 1.6;

  static double nodeRadius(int closeness, {bool isMe = false}) =>
      isMe ? nodeRadiusMe : nodeRadiusBase + closeness * nodeRadiusPerCloseness;

  static const linkWidthBase = 0.4;
  static const linkWidthSignal = 1.5;
  static double linkWidth(double decay) =>
      linkWidthBase + (1 - decay) * linkWidthSignal;

  /// Decayed links fragment into drifting dashes.
  static const fragmentSegmentLength = 15.0;
  static const fragmentAmplitude = 11.0;

  // --- Forces ---------------------------------------------------------------

  static const repulsion = 2100.0;
  static const repulsionGhost = 780.0;
  static const repulsionClamp = 3.0;
  static const damping = 0.865;
  static const meCentring = 0.06;
  static const globalCentring = 0.0016;

  /// ORBIT: radial pull to `104 + decay * 250` at strength 0.012.
  static const orbitRadiusBase = 104.0;
  static const orbitRadiusDecay = 250.0;
  static const orbitStrength = 0.012;

  /// STRATA: attraction 0.016 to five context anchors on a circle of r = 205.
  static const strataStrength = 0.016;
  static const strataAnchorRadius = 205.0;

  // --- Motion ---------------------------------------------------------------

  static const breathingRate = 0.62;
  static const breathingAmplitude = 0.12;
  static const cameraLerp = 0.08;
  static const dimLerp = 0.09;
  static const selectionLerp = 0.16;

  static const sheetDuration = Duration(milliseconds: 580);
  static const sheetCurve = Cubic(0.16, 1, 0.3, 1);
  static const toastDuration = Duration(milliseconds: 2400);
  static const bootDuration = Duration(milliseconds: 2200);

  // --- Dim levels by mode ---------------------------------------------------

  static const dimFocus = 0.07;
  static const dimLog = 0.42;
  static const dimNudge = 0.13;
  static const dimPropose = 0.20;
  static const dimHome = 1.0;

  static const ghostOpacity = 0.22;
  static const ghostOpacityReach = 0.70;
  static const ghostOpacityFocus = 0.10;

  /// How much non-selected nodes are faded in each mode.
  static double dimFor(String mode) => switch (mode) {
    'focus' => dimFocus,
    'log' => dimLog,
    'nudge' => dimNudge,
    'propose' => dimPropose,
    _ => dimHome,
  };

  // --- Helpers --------------------------------------------------------------

  static double lerp(double a, double b, double t) => lerpDouble(a, b, t)!;

  static ThemeData theme() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: void_,
    colorScheme: const ColorScheme.dark(
      surface: void_,
      primary: cyan,
      onPrimary: onAccent,
      secondary: cyanBright,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
