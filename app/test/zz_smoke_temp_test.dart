// TEMPORARY verification harness. Delete after running.
import 'package:eightx_friends/src/demo/cast.dart';
import 'package:eightx_friends/src/model/models.dart';
import 'package:eightx_friends/src/state/app_state.dart';
import 'package:eightx_friends/src/theme/tokens.dart';
import 'package:eightx_friends/src/ui/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Size _screen = const Size(390, 844);

Future<void> _pump(WidgetTester t, AppState s) async {
  await t.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: _screen,
        padding: const EdgeInsets.only(top: 47, bottom: 34),
      ),
      child: MaterialApp(
        theme: Tokens.theme(),
        home: AppScope(notifier: s, child: const Shell()),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 120));
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('every mode renders for Calvin', (t) async {
    final s = AppState();
    await s.boot();
    await _pump(t, s);

    await s.chooseWho(Who.calvin);
    await _pump(t, s);

    // Home graph.
    expect(s.circleCount, 9, reason: 'Calvin should have nine ties');
    expect(s.driftingCount, 2, reason: 'Yassie and Iker should be drifting');

    // Focus a fading friend, then every sheet that hangs off it.
    s.focusPerson(Ids.yassie);
    await _pump(t, s);
    s.setMode(AppMode.planTime);
    await _pump(t, s);
    s.setMode(AppMode.log);
    await _pump(t, s);
    s.setMode(AppMode.nearby);
    await _pump(t, s);

    // Hannan: indirect, then the consent sheet.
    s.focusPerson(Ids.hannan);
    await _pump(t, s);
    s.setMode(AppMode.connect);
    await _pump(t, s);

    // Self focus.
    s.focusPerson(Ids.calvin);
    await _pump(t, s);

    // The nearby view.
    s.goHome();
    s.grantLocation();
    s.setView(GraphView.distance);
    await _pump(t, s);
    s.setView(GraphView.health);
    await _pump(t, s);

    // The whole plan life cycle.
    s.proposePlan(
      withPersonId: Ids.yassie,
      when: s.now.add(const Duration(days: 2)),
      place: 'Café Janis',
    );
    await _pump(t, s);
    s.setMode(AppMode.planDetail);
    await _pump(t, s);
    s.setMode(AppMode.circle);
    await _pump(t, s);
    s.addToPlan(Ids.hannan);
    await _pump(t, s);
    s.nudgeDirector(); // Hannan accepts
    await _pump(t, s);

    s.toggleDemoPanel();
    await _pump(t, s);
    s.advanceToMorningAfter();
    await _pump(t, s);
    s.setMode(AppMode.confirm);
    await _pump(t, s);
    s.confirmMeetupHappened();
    await _pump(t, s);
    await t.pump(const Duration(seconds: 2));

    // Act 5 — Hannan must still be reachable after the plan renews.
    expect(
      s.spotlightIds.contains(Ids.hannan),
      isTrue,
      reason: 'Hannan must stay on the graph so Calvin can ask to connect',
    );
    s.focusPerson(Ids.hannan);
    await _pump(t, s);
    s.requestConnection(Ids.hannan);
    await _pump(t, s);
    s.nudgeDirector();
    await _pump(t, s);
    expect(s.isDirectlyConnected(Ids.hannan), isTrue);
    s.focusPerson(Ids.hannan);
    await _pump(t, s);

    s.resetDemo();
    await _pump(t, s);
    s.dispose();
  });

  testWidgets('every mode renders for Yassie', (t) async {
    final s = AppState();
    await s.boot();
    await s.chooseWho(Who.yassie);
    await _pump(t, s);

    expect(s.circleCount, 8);
    expect(s.driftingCount, 1);

    s.focusPerson(Ids.calvin);
    await _pump(t, s);
    s.setMode(AppMode.planTime);
    await _pump(t, s);
    s.proposePlan(
      withPersonId: Ids.calvin,
      when: s.now.add(const Duration(days: 2)),
      place: 'Café Janis',
    );
    await _pump(t, s);
    s.setMode(AppMode.invitation);
    await _pump(t, s);
    s.setMode(AppMode.proposeTime);
    await _pump(t, s);
    s.setMode(AppMode.circle);
    await _pump(t, s);
    s.dispose();
  });

  testWidgets('small screen: every sheet still fits', (t) async {
    _screen = const Size(375, 667);
    addTearDown(() => _screen = const Size(390, 844));
    final s = AppState();
    await s.boot();
    await s.chooseWho(Who.calvin);
    await _pump(t, s);
    for (final m in AppMode.values) {
      if (m == AppMode.boot) continue;
      if (m == AppMode.focus) s.focusPerson(Ids.yassie);
      if (m == AppMode.connect) s.focusPerson(Ids.hannan);
      if (m == AppMode.planTime) s.focusPerson(Ids.yassie);
      if (m == AppMode.invitation ||
          m == AppMode.proposeTime ||
          m == AppMode.circle ||
          m == AppMode.planDetail ||
          m == AppMode.confirm) {
        if (s.plan == null) {
          s.proposePlan(
            withPersonId: Ids.yassie,
            when: s.now.add(const Duration(days: 2)),
            place: 'Café Janis',
          );
          s.addToPlan(Ids.hannan);
        }
      }
      s.setMode(m);
      await _pump(t, s);
    }
    s.toggleDemoPanel();
    await _pump(t, s);
    s.dispose();
  });
}
