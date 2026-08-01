/// The graph. Fills the one Stack; everything else floats above it.
library;

import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter/scheduler.dart';

import '../model/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'painter.dart';
import 'simulation.dart';

const double _hitSlop = 14.0;
const double _zoomMin = 0.4;
const double _zoomMax = 3.0;
const double _maxFrame = 0.05;

const _selectionModes = {
  AppMode.log,
  AppMode.add,
  AppMode.group,
  AppMode.propose,
};

class GraphView extends StatefulWidget {
  const GraphView({super.key});

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView>
    with SingleTickerProviderStateMixin {
  final Simulation _sim = Simulation();
  late final Ticker _ticker;

  Offset _camera = Offset.zero;
  double _zoom = 1;
  double _dim = Tokens.dimHome;

  Offset? _lastCameraTarget;
  double? _lastZoomTarget;
  String? _lastFocusedId;
  bool _userCamera = false;

  SimNode? _dragging;
  Offset _gestureStart = Offset.zero;
  Offset _cameraStart = Offset.zero;
  double _zoomStart = 1;

  Size _size = Tokens.referenceSize;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? _maxFrame
        : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, _maxFrame);
    _lastTick = elapsed;
    _sim.tick(dt);
    setState(() {});
  }

  // --- world <-> screen ------------------------------------------------------

  Offset _toWorld(Offset local) =>
      (local - Offset(_size.width / 2, _size.height / 2)) / _zoom + _camera;

  /// Slop is a screen distance, so it has to shrink as the world grows —
  /// otherwise nothing is tappable when zoomed out.
  double get _worldSlop => _hitSlop / _zoom.clamp(_zoomMin, _zoomMax);

  // --- gestures --------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails d) {
    _gestureStart = d.localFocalPoint;
    _cameraStart = _camera;
    _zoomStart = _zoom;
    _dragging?.pinned = false;
    _dragging = null;
    if (d.pointerCount == 1) {
      _dragging = _sim.hitTest(_toWorld(d.localFocalPoint), slop: _worldSlop);
      _dragging?.pinned = true;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      _dragging?.pinned = false;
      _dragging = null;
      final anchor = _toWorld(d.localFocalPoint);
      _zoom = (_zoomStart * d.scale).clamp(_zoomMin, _zoomMax);
      _camera =
          anchor -
          (d.localFocalPoint - Offset(_size.width / 2, _size.height / 2)) /
              _zoom;
      _userCamera = true;
      return;
    }
    final node = _dragging;
    if (node != null) {
      node.pos = _toWorld(d.localFocalPoint);
      node.vel = Offset.zero;
      return;
    }
    _camera = _cameraStart - (d.localFocalPoint - _gestureStart) / _zoom;
    _userCamera = true;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _dragging?.pinned = false;
    _dragging = null;
  }

  void _onTapUp(TapUpDetails d, AppState state) {
    _dragging?.pinned = false;
    _dragging = null;
    final hit = _sim.hitTest(_toWorld(d.localPosition), slop: _worldSlop);
    if (hit == null) {
      state.goHome();
      return;
    }
    if (_selectionModes.contains(state.mode)) {
      state.toggleSelected(hit.id);
    } else {
      state.focusPerson(hit.id);
      state.setMode(AppMode.focus);
    }
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    _sim.layout = state.layout;
    _sim.sync(state.people, state.relationships, state.ghosts, state.decay);

    if (state.cameraTarget != _lastCameraTarget ||
        state.cameraZoom != _lastZoomTarget ||
        state.focusedPersonId != _lastFocusedId) {
      _lastCameraTarget = state.cameraTarget;
      _lastZoomTarget = state.cameraZoom;
      _lastFocusedId = state.focusedPersonId;
      _userCamera = false;
    }
    if (!_userCamera) {
      _camera = Offset.lerp(
        _camera,
        _cameraTargetFor(state),
        Tokens.cameraLerp,
      )!;
      _zoom = Tokens.lerp(_zoom, state.cameraZoom, Tokens.cameraLerp);
    }
    if (!_camera.dx.isFinite || !_camera.dy.isFinite) _camera = Offset.zero;
    if (!_zoom.isFinite) _zoom = 1;
    _dim = Tokens.lerp(_dim, Tokens.dimFor(state.mode.name), Tokens.dimLerp);

    final highlighted = _highlighted(state);
    final invited = _invited(state);

    return LayoutBuilder(
      builder: (context, constraints) {
        final biggest = constraints.biggest;
        _size = biggest.isFinite ? biggest : Tokens.referenceSize;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          onTapUp: (d) => _onTapUp(d, state),
          child: CustomPaint(
            size: _size,
            painter: GraphPainter(
              sim: _sim,
              decay: state.decay,
              camera: _camera,
              zoom: _zoom,
              highlighted: highlighted,
              dimOthers: _dim,
              focusedId: state.focusedPersonId,
              t: _sim.time,
              invitedIds: invited,
              ghostOpacity: _ghostOpacity(state.mode),
            ),
          ),
        );
      },
    );
  }

  /// `AppState.cameraTarget` is a per-mode pan only — on its own it leaves the
  /// focused node wherever it happened to be, often behind the sheet or off
  /// screen. In focus mode the pan is applied *relative to that node*.
  Offset _cameraTargetFor(AppState state) {
    final base = state.cameraTarget;
    if (state.mode != AppMode.focus) return base;
    final id = state.focusedPersonId;
    if (id == null) return base;
    final n = _sim.nodeById(id);
    if (n == null || !n.pos.dx.isFinite || !n.pos.dy.isFinite) return base;
    return n.pos + base;
  }

  Set<String> _highlighted(AppState state) {
    if (state.selectedPersonIds.isNotEmpty) {
      return state.selectedPersonIds;
    }
    if (state.mode == AppMode.nudge) {
      return {for (final n in state.nudges) n.person.id};
    }
    if (state.mode == AppMode.group) {
      return {for (final p in state.group) p.id};
    }
    final focused = state.focusedPersonId;
    if (focused == null) return const {};
    return {
      focused,
      ?state.me?.id,
      for (final r in state.relationships)
        if (r.touches(focused)) ?r.other(focused),
    };
  }

  Set<String> _invited(AppState state) {
    if (state.invitations.isEmpty) return const {};
    final profiles = <String>{
      for (final i in state.invitations)
        if (i.isPending) ...[i.senderProfileId, ...i.recipientProfileIds],
    };
    return {
      for (final p in state.people)
        if (p.linkedProfileId != null && profiles.contains(p.linkedProfileId))
          p.id,
    };
  }

  double _ghostOpacity(AppMode mode) => switch (mode) {
    AppMode.reach => Tokens.ghostOpacityReach,
    AppMode.focus => Tokens.ghostOpacityFocus,
    _ => Tokens.ghostOpacity,
  };
}
