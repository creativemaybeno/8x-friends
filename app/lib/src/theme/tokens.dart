/// **Every** design value in the app lives here.
///
/// v3 — the paper build. Warm off-white paper, ink type, one lime accent and
/// one clay warning. Bricolage Grotesque for anything human, DM Mono for
/// anything the machine is reporting.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../model/models.dart';

abstract final class Tokens {
  // --- Feature flags --------------------------------------------------------

  /// Per-relationship decay horizons, learned from each pair's own cadence.
  static const bool perPersonHorizon = true;

  // --- Palette (v3) ---------------------------------------------------------

  /// The paper everything sits on.
  static const paper = Color(0xFFF6F5F0);

  /// Sheets, banners, the view switcher track.
  static const card = Color(0xFFFFFFFF);

  /// Inset surfaces: fields, notes, unselected chips and day cells.
  static const soft = Color(0xFFF2F1EC);

  /// List rows, one notch lighter than [soft].
  static const rowSoft = Color(0xFFF8F7F3);

  /// Type, node cores, the dark button.
  static const ink = Color(0xFF14170F);

  /// Body copy and ghost-button labels.
  static const ink2 = Color(0xFF5F665C);

  /// Muted machine voice.
  static const mut = Color(0xFF9AA093);

  /// The caption line under the graph.
  static const hintInk = Color(0xFF8C9285);

  /// The identity line beside the wordmark.
  static const ownerInk = Color(0xFF71786D);

  /// The one accent. Me, the plan, the primary action.
  static const lime = Color(0xFFCBF54A);

  /// Lime, one step deeper: fresh links, renewal, a new consented edge.
  static const limeDeep = Color(0xFF9CCF24);

  /// A relationship in trouble. Never used for anything else.
  static const clay = Color(0xFFCF5B38);

  /// What ink fades toward as a relationship decays.
  static const grey = Color(0xFFCDCCC3);

  /// The phone bezel in the design; the boot wash here.
  static const bezel = Color(0xFFECEAE2);

  // Hairlines and scrims, all ink at low alpha.
  static const hairInk05 = Color(0x0D14170F);
  static const hairInk09 = Color(0x1714170F);
  static const hairInk14 = Color(0x2414170F);
  static const hairInk18 = Color(0x2E14170F);
  static const hairInk22 = Color(0x3814170F);

  // --- Legacy aliases -------------------------------------------------------
  //
  // The old dark palette's names, remapped onto the paper build so nothing
  // outside this file has to know the theme changed.

  static const void_ = paper;
  static const sheetTop = card;
  static const sheetBottom = card;
  static const sheetBlur = 0.0;
  static const cyan = lime;
  static const cyanBright = limeDeep;
  static const body = ink;
  static const heading = ink;
  static const prose = ink2;
  static const meta = mut;
  static const faint = mut;
  static const onAccent = ink;
  static const amber = clay;
  static const green = limeDeep;
  static const violet = limeDeep;
  static const dim = grey;
  static const sink = grey;
  static const linkSink = grey;

  /// Context no longer tints anything: the paper build reads health, not
  /// category. Kept so callers compile.
  static Color contextColor(String? context) => ink;

  // --- Colour by decay ------------------------------------------------------

  /// A direct node's core: ink fading to warm grey as the tie decays.
  static Color nodeFill(String? context, double decay) =>
      Color.lerp(ink, grey, (decay * 1.1).clamp(0.0, 1.0))!;

  /// The health arc around a node. Clay once the tie is in trouble.
  static Color nodeRing(String? context, double decay) =>
      decay > 0.55 ? clay : ink;

  /// A link: ink fading to grey, clay once it is clearly going.
  static Color linkColor(double decay) => decay > 0.66
      ? clay
      : Color.lerp(ink, grey, (decay * 1.15).clamp(0.0, 1.0))!;

  /// A link's stroke alpha. Fresh ties are near-solid, dead ones are ghosts.
  static double linkOpacity(double decay) =>
      decay > 0.9 ? 0.45 : (0.3 + (1 - decay) * 0.55).clamp(0.0, 1.0);

  /// Dash pattern for a decayed link: the dash shrinks, the gap grows.
  /// Returns `null` below 0.3 — a healthy link is solid.
  static (double, double)? linkDash(double decay) =>
      decay <= 0.3 ? null : ((7 - decay * 6).clamp(1.2, 7.0), 3 + decay * 11);

  // --- Health language ------------------------------------------------------

  /// Lowercase, human. The paper build never shouts.
  static String healthLabel(double decay) => switch (decay) {
    < 0.25 => 'strong',
    < 0.50 => 'steady',
    < 0.72 => 'drifting',
    _ => 'fading',
  };

  /// The colour that matches [healthLabel].
  static Color healthColor(double decay) => decay > 0.55 ? clay : ink;

  // --- Type -----------------------------------------------------------------
  //
  // Bricolage Grotesque = a person is talking. DM Mono = the app is stating a
  // fact: small, wide-tracked, lowercase.

  static void init() {
    GoogleFonts.config.allowRuntimeFetching = true;
  }

  static TextStyle _sans({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = ink,
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
      return GoogleFonts.bricolageGrotesque(textStyle: fallback);
    } catch (_) {
      return fallback;
    }
  }

  static TextStyle _mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double spacing = 0,
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
      return GoogleFonts.dmMono(textStyle: fallback);
    } catch (_) {
      return fallback;
    }
  }

  // Chrome.
  static TextStyle get statusClock => _mono(size: 11, spacing: 0.11);
  static TextStyle get ownerLine =>
      _mono(size: 10, spacing: 1.0, color: ownerInk);
  static TextStyle get wordmarkMark =>
      _sans(size: 10.5, weight: FontWeight.w600, spacing: -0.32);
  static TextStyle get pillLabel =>
      _mono(size: 9.5, weight: FontWeight.w500, spacing: 0.57);
  static TextStyle get hintLine =>
      _mono(size: 10, spacing: 0.8, color: hintInk);
  static TextStyle get toggleLabel => _sans(size: 13);

  // Sheet.
  static TextStyle get sheetLabel => _mono(size: 10, spacing: 1.2, color: mut);
  static TextStyle get sheetLabelRight =>
      _mono(size: 9.5, spacing: 0.76, color: mut);
  static TextStyle get subjectName =>
      _sans(size: 30, spacing: -1.05, height: 1.06);
  static TextStyle get subjectMeta =>
      _mono(size: 9.5, spacing: 0.57, color: hintInk, height: 1.5);
  static TextStyle get subjectStat =>
      _mono(size: 23, spacing: -1.15, height: 1.0);
  static TextStyle get subjectStatLabel =>
      _mono(size: 9, spacing: 0.72, color: mut);
  static TextStyle get sheetTitle =>
      _sans(size: 29, spacing: -1.02, height: 1.15);
  static TextStyle get sheetRead => _sans(size: 14.5, color: ink2, height: 1.6);
  static TextStyle get chipLabel => _sans(size: 13.5, spacing: -0.14);
  static TextStyle get pickerLabel =>
      _mono(size: 9.5, spacing: 0.95, color: mut);
  static TextStyle get dayWeekday => _mono(size: 9, spacing: 0.54);
  static TextStyle get dayNumber => _sans(size: 19, spacing: -0.57);
  static TextStyle get timeValue => _sans(size: 30, spacing: -1.2);
  static TextStyle get timeHint => _mono(size: 10, color: mut);
  static TextStyle get fieldLabel =>
      _mono(size: 9.5, spacing: 0.95, color: mut);
  static TextStyle get fieldValue => _sans(size: 17, spacing: -0.26);
  static TextStyle get rowLeft =>
      _sans(size: 15.5, spacing: -0.23, height: 1.3);
  static TextStyle get rowSub => _mono(size: 9.5, spacing: 0.48, color: mut);
  static TextStyle get rowRight => _mono(size: 9.5, spacing: 0.57, color: mut);
  static TextStyle get noteText => _sans(size: 12.5, color: ink2, height: 1.6);
  static TextStyle get actionLabel => _sans(size: 14.5, spacing: -0.15);
  static TextStyle get footLine => _mono(size: 10, spacing: 1.0, color: mut);
  static TextStyle get badgeGlyph => _mono(size: 19, color: paper);
  static TextStyle get badgeGlyphSmall => _mono(size: 13, color: paper);

  // Overlays.
  static TextStyle get notifTitle =>
      _sans(size: 17, weight: FontWeight.w500, spacing: -0.34, height: 1.25);
  static TextStyle get notifBody => _sans(size: 13.5, color: ink2, height: 1.5);
  static TextStyle get notifApp =>
      _mono(size: 9.5, spacing: 0.95, color: ownerInk);
  static TextStyle get notifWhen => _mono(size: 9.5, color: mut);
  static TextStyle get renewedEyebrow =>
      _mono(size: 10, spacing: 1.4, color: Color(0xA614170F));
  static TextStyle get renewedLine =>
      _sans(size: 29, spacing: -1.02, height: 1.14);
  static TextStyle get renewedSub =>
      _sans(size: 13, color: Color(0xB814170F), height: 1.55);
  static TextStyle get toastText => _sans(size: 13.5, color: paper);

  // Graph.
  static TextStyle get nodeName => _sans(size: 13, spacing: -0.2);
  static TextStyle get nodeMe => _mono(size: 10, spacing: 0.6, color: ink2);
  static TextStyle get bandLabel => _mono(size: 10, spacing: 0.8, color: mut);
  static TextStyle get clusterLabel => _mono(size: 10.5, spacing: 0.6);
  static TextStyle get edgeTag => _mono(size: 10, color: limeDeep);

  // Legacy names, remapped.
  static TextStyle get wordmark => subjectName;
  static TextStyle get sheetTitleLarge => sheetTitle;
  static TextStyle get sheetProse => sheetRead;
  static TextStyle get personName => rowLeft;
  static TextStyle get personNameLarge => subjectName;
  static TextStyle get input => fieldValue;
  static TextStyle get buttonLabel => actionLabel;
  static TextStyle get statValue => subjectStat;
  static TextStyle get bannerTitle => notifTitle;
  static TextStyle get bannerBody => notifBody;
  static TextStyle get renewedTitle => renewedLine;
  static TextStyle get monoLabel => sheetLabel;
  static TextStyle get monoLabelBright => sheetLabel;
  static TextStyle get monoLabelDim => sheetLabelRight;
  static TextStyle get monoTiny => sheetLabelRight;
  static TextStyle get monoNav => footLine;
  static TextStyle get monoStat => rowRight;
  static TextStyle get nodeLabel => nodeName;

  // --- Geometry -------------------------------------------------------------

  static const radiusSheet = 40.0;
  static const radiusSheetBottom = 56.0;
  static const radiusCard = 24.0;
  static const radiusRow = 24.0;
  static const radiusChip = 999.0;
  static const radiusButton = 999.0;
  static const radiusDay = 22.0;
  static const radiusNotif = 30.0;
  static const radiusRenewed = 40.0;

  static const gapXs = 4.0;
  static const gapS = 9.0;
  static const gapM = 14.0;
  static const gapL = 22.0;
  static const gapXl = 30.0;

  static const sheetPadding = EdgeInsets.fromLTRB(26, 30, 26, 40);
  static const sheetMaxHeightFraction = 0.72;
  static const rowHeight = 54.0;
  static const buttonHeight = 56.0;
  static const navHeight = 62.0;

  static const hairline = 1.0;
  static const borderColor = hairInk09;
  static const borderColorStrong = hairInk18;

  /// Phone-only, 402x874 reference frame — the design's canvas.
  static const referenceSize = Size(402, 874);

  // --- Graph draw geometry (v3) ---------------------------------------------

  static const nodeRadiusBase = 8.0;
  static const nodeRadiusPerCloseness = 2.0;
  static const nodeRadiusMe = 12.0;
  static const nodeRadiusIndirect = 7.0;
  static const nodeRadiusIndirectInPlan = 9.0;

  /// The health arc sits this far outside the core.
  static const ringOffset = 7.0;
  static const ringStroke = 2.2;

  /// A pending attendee's breathing dashed ring.
  static const pendingRingOffset = 14.0;
  static const pendingRingStroke = 1.3;
  static const pendingDashLength = 2.5;
  static const pendingGapLength = 5.0;

  /// Me: a lime core with a soft lime halo.
  static const meHaloOffset = 7.0;
  static const meHaloOpacity = 0.35;
  static const meStroke = 1.3;

  /// The label baseline below a node.
  static const nodeLabelOffset = 20.0;
  static const labelHaloStroke = 3.4;

  static double nodeRadius(int closeness, {bool isMe = false}) =>
      isMe ? nodeRadiusMe : nodeRadiusBase + closeness * nodeRadiusPerCloseness;

  /// Link stroke width before the spoke factor.
  static double linkWidth(double decay) => decay < 0.25 ? 1.6 : 1.15;
  static const linkWidthFresh = 2.4;
  static const linkSpokeFactor = 1.0;
  static const linkBowFactor = 0.62;
  static const linkBowOpacity = 0.5;

  /// A healthy spoke gets a hairline companion rail this far to one side.
  static const railOffset = 3.0;
  static const railWidth = 1.0;
  static const railOpacity = 0.34;
  static const railBelow = 0.24;

  /// Everything that is not in front, in focus and plan modes.
  static const dimmedOpacity = 0.22;

  // --- Plan, pending and renewal visuals ------------------------------------

  /// The lime dot that marks an attendee of the upcoming plan.
  static const planMarkRadius = 6.5;
  static const planMarkStroke = 2.6;
  static const planMarkOffset = 4.0;

  /// The soft ring the planned group gathers inside.
  static const hullPadding = 46.0;
  static const hullStroke = 1.4;
  static const hullFillOpacity = 0.18;
  static const hullDashLength = 4.0;
  static const hullGapLength = 7.0;
  static const hullLabelDrop = 20.0;

  /// The dashed tether between people in a plan.
  static const planLinkDashLength = 3.0;
  static const planLinkGapLength = 6.0;
  static const planLinkWidth = 2.4;
  static const planLinkWidthPending = 1.3;
  static const planDashDrift = 21.0;

  /// The finer tether of an outstanding connection request.
  static const requestDashLength = 1.5;
  static const requestGapLength = 6.0;
  static const requestWidth = 1.6;
  static const requestDashDrift = 16.6;

  /// The pulsing dot on a link that just renewed.
  static const renewPulseRadius = 3.6;
  static const renewPulseWidth = 2.4;
  static const renewedDecay = 0.06;

  /// The two whisper-quiet guide rings in the health view.
  static const haloRings = <double>[120, 224];
  static const haloRingOpacity = 0.05;

  /// The three coarse distance bands in the nearby view.
  static const bandRings = <double>[92, 176, 268];
  static const bandLabels = <String>['nearby', 'same city', 'far away'];
  static const bandRingOpacity = 0.22;
  static const bandDashLength = 1.5;
  static const bandGapLength = 7.0;

  // --- Forces ---------------------------------------------------------------

  static const repulsion = 2600.0;
  static const repulsionClamp = 3.0;
  static const damping = 0.86;
  static const meCentring = 0.09;
  static const globalCentring = 0.0022;

  /// Orbit radius = `base + decay * decayRange`. The design's 108/122 assumes
  /// a graph fitted to its content; this camera is fixed, so the range is
  /// compressed to keep the furthest node *and its name* on a 390pt screen.
  static const orbitRadiusDecay = 78.0;
  static const orbitRadiusBase = 92.0;

  /// DISTANCE view: radial pull to the band radius for that person.
  static const distanceRadiusPerKm = 5.2;
  static const distanceRadiusBase = 90.0;
  static const distanceStrength = 0.03;

  /// The upcoming plan gathers its people into a small foreground ring.
  static const planClusterStrength = 0.034;
  static const planClusterRadius = 64.0;

  /// Coarse distance bands, in km, matching [bandRings].
  static int distanceBand(double km) => km < 2 ? 0 : (km < 30 ? 1 : 2);

  // --- Motion ---------------------------------------------------------------

  static const breathingRate = 0.62;
  static const breathingAmplitude = 0.12;
  static const cameraLerp = 0.09;
  static const dimLerp = 0.09;
  static const selectionLerp = 0.16;

  /// `p8breathe`: opacity .45 to 1 and back.
  static const breatheMin = 0.45;
  static const breathePeriodPending = 2.2;
  static const breathePeriodPulse = 1.8;

  static const sheetDuration = Duration(milliseconds: 550);
  static const sheetCurve = Cubic(0.16, 1, 0.3, 1);
  static const toastDuration = Duration(milliseconds: 2600);
  static const bootDuration = Duration(milliseconds: 1600);

  static const bannerDuration = Duration(milliseconds: 500);
  static const bannerCurve = Cubic(0.16, 1, 0.3, 1);
  static const bannerDwell = Duration(seconds: 7);

  static const renewedDwell = Duration(milliseconds: 4200);
  static const renewAnimation = Duration(milliseconds: 4200);

  // --- Camera ---------------------------------------------------------------

  /// `(zoom, panY)` for every mode. A mode is first of all a camera move.
  static const cameraByMode = <AppMode, (double, double)>{
    AppMode.boot: (0.62, 0.0),
    AppMode.identity: (0.62, 0.0),
    // Home has no sheet, but the caption and the view switcher own the bottom
    // ~170px. Lift the graph so it sits in the space that is actually free.
    AppMode.home: (0.92, 34.0),
    AppMode.focus: (1.15, 190.0),
    AppMode.planTime: (0.80, 210.0),
    AppMode.invitation: (0.80, 210.0),
    AppMode.proposeTime: (0.80, 210.0),
    AppMode.circle: (0.80, 210.0),
    AppMode.planDetail: (0.86, 200.0),
    AppMode.connect: (1.00, 200.0),
    AppMode.confirm: (0.82, 200.0),
    AppMode.log: (0.86, 195.0),
    AppMode.nearby: (0.62, 215.0),
  };

  /// The nearby view throws people out to the 268-unit band, so it needs more
  /// room than the health orbit does. Multiplies whatever the mode asks for.
  static const distanceZoomFactor = 0.72;

  // --- Dim levels by mode ---------------------------------------------------

  static const dimFocus = dimmedOpacity;
  static const dimLog = 0.42;
  static const dimNudge = dimmedOpacity;
  static const dimPropose = dimmedOpacity;
  static const dimPlan = dimmedOpacity;
  static const dimHome = 1.0;

  /// How much non-selected nodes are faded in each mode. Takes `AppMode.name`.
  static double dimFor(String mode) => switch (mode) {
    'focus' => dimFocus,
    'connect' => dimFocus,
    'planTime' => dimPlan,
    'invitation' => dimPlan,
    'proposeTime' => dimPlan,
    'circle' => dimPlan,
    'planDetail' => dimPlan,
    'confirm' => dimPlan,
    'log' => dimLog,
    _ => dimHome,
  };

  // --- Helpers --------------------------------------------------------------

  static double lerp(double a, double b, double t) => lerpDouble(a, b, t)!;

  /// `p8breathe` sampled at [t] seconds for a given period.
  static double breathe(double t, double period) =>
      breatheMin +
      (1 - breatheMin) * (0.5 - 0.5 * math.cos(2 * math.pi * t / period));

  static ThemeData theme() => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: paper,
    colorScheme: const ColorScheme.light(
      surface: paper,
      primary: lime,
      onPrimary: ink,
      secondary: limeDeep,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
