/// The graph. Fills the one Stack; everything else floats above it.
library;

import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter/scheduler.dart';

import '../model/models.dart' hide GraphView;
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'painter.dart';
import 'simulation.dart';

const double _hitSlop = 14.0;
const double _zoomMin = 0.4;
const double _zoomMax = 3.0;
const double _maxFrame = 0.05;

/// Modes that are about the plan rather than one person. In these the camera
/// frames the cluster and every attendee stays lit.
const _planModes = {
  AppMode.planTime,
  AppMode.invitation,
  AppMode.proposeTime,
  AppMode.circle,
  AppMode.planDetail,
  AppMode.confirm,
};

/// Modes whose camera follows the focused node.
const _nodeCameraModes = {AppMode.focus, AppMode.connect};

/// Modes whose camera frames the planned cluster.
const _clusterCameraModes = {AppMode.circle, AppMode.planDetail};

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
  AppMode? _lastMode;
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
    final world = _toWorld(d.localPosition);
    if (_planIconAt(world, state) != null) {
      state.setMode(AppMode.planDetail);
      return;
    }
    final hit = _sim.hitTest(world, slop: _worldSlop);
    if (hit == null) {
      state.goHome();
      return;
    }
    state.focusPerson(hit.id);
  }

  /// The plan badge sits above the node, so it needs its own hit test — the
  /// node's own circle is too far away to catch it.
  SimNode? _planIconAt(Offset world, AppState state) {
    if (state.planIds.isEmpty) return null;
    if (!world.dx.isFinite || !world.dy.isFinite) return null;
    final threshold = Tokens.planIconRadius + _worldSlop;
    SimNode? best;
    var bestD = double.infinity;
    for (final n in _sim.nodes) {
      if (!state.planIds.contains(n.id)) continue;
      if (state.pendingIds.contains(n.id)) continue;
      final centre = GraphPainter.planIconCentre(n);
      if (!centre.dx.isFinite || !centre.dy.isFinite) continue;
      final dist = (centre - world).distance;
      if (dist <= threshold && dist < bestD) {
        best = n;
        bestD = dist;
      }
    }
    return best;
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final planLinkKeys = _planLinkKeys(state);

    _sim.view = state.view;
    _sim.planIds = state.planIds;
    _sim.pendingIds = state.pendingIds;
    _sim.planLinkKeys = planLinkKeys;
    _sim.sync(state.people, state.relationships, state.decay, state.meId);

    if (state.cameraTarget != _lastCameraTarget ||
        state.cameraZoom != _lastZoomTarget ||
        state.focusedPersonId != _lastFocusedId ||
        state.mode != _lastMode) {
      _lastCameraTarget = state.cameraTarget;
      _lastZoomTarget = state.cameraZoom;
      _lastFocusedId = state.focusedPersonId;
      _lastMode = state.mode;
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
              planIds: state.planIds,
              pendingIds: state.pendingIds,
              planLinkKeys: planLinkKeys,
              renewingKeys: state.renewingKeys,
              names: {for (final p in state.people) p.id: p.name},
              view: state.view,
            ),
          ),
        );
      },
    );
  }

  /// Every unordered pair of attendees. These are drawn dashed whether or not
  /// a real relationship exists underneath.
  Set<String> _planLinkKeys(AppState state) {
    final ids = state.planIds.toList(growable: false);
    if (ids.length < 2) return const {};
    return {
      for (var i = 0; i < ids.length; i++)
        for (var j = i + 1; j < ids.length; j++)
          Relationship.keyFor(ids[i], ids[j]),
    };
  }

  /// `AppState.cameraTarget` is a per-mode pan only — on its own it leaves the
  /// subject wherever it happened to be, often behind the sheet or off screen.
  /// The pan is therefore applied *relative to* whatever the mode is about.
  Offset _cameraTargetFor(AppState state) {
    final base = state.cameraTarget;
    if (state.plan != null && _clusterCameraModes.contains(state.mode)) {
      final centre = _sim.planCentroid;
      if (!centre.dx.isFinite || !centre.dy.isFinite) return base;
      return centre + base;
    }
    if (!_nodeCameraModes.contains(state.mode)) return base;
    final id = state.focusedPersonId;
    if (id == null) return base;
    final n = _sim.nodeById(id);
    if (n == null || !n.pos.dx.isFinite || !n.pos.dy.isFinite) return base;
    return n.pos + base;
  }

  Set<String> _highlighted(AppState state) {
    if (state.plan != null && _planModes.contains(state.mode)) {
      final ids = state.planIds;
      if (ids.isNotEmpty) return ids;
    }
    final focused = state.focusedPersonId;
    if (focused == null) return const {};
    final meId = state.meId;
    return {
      focused,
      if (meId.isNotEmpty) meId,
      for (final r in state.relationships)
        if (r.touches(focused)) ?r.other(focused),
    };
  }
}
