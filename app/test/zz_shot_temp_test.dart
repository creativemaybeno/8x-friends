// TEMPORARY screenshot harness. Delete after running.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:eightx_friends/src/demo/cast.dart';
import 'package:eightx_friends/src/model/models.dart';
import 'package:eightx_friends/src/state/app_state.dart';
import 'package:eightx_friends/src/theme/tokens.dart';
import 'package:eightx_friends/src/ui/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _out =
    '/private/tmp/claude-501/-Users-User-Closed-creativemaybeno-8x-friends/'
    '791f661d-441e-44ba-b28a-3ae8af602c21/scratchpad/shots';

final _key = GlobalKey();

Future<void> _pump(WidgetTester t, AppState s) async {
  await t.pumpWidget(
    MaterialApp(
      theme: Tokens.theme(),
      home: RepaintBoundary(
        key: _key,
        child: AppScope(notifier: s, child: const Shell()),
      ),
    ),
  );
  for (var i = 0; i < 40; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  final boundary =
      _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_out).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shots', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2.0;
    t.view.padding = const FakeViewPadding(top: 94, bottom: 68);
    addTearDown(t.view.reset);

    final s = AppState();
    await s.boot();
    await s.chooseWho(Who.calvin);
    await _pump(t, s);
    await _shot(t, 'a-home');

    s.focusPerson(Ids.yassie);
    await _pump(t, s);
    await _shot(t, 'b-focus');

    s.setMode(AppMode.planTime);
    await _pump(t, s);
    await _shot(t, 'c-plan-time');

    s.goHome();
    s.proposePlan(
      withPersonId: Ids.yassie,
      when: s.now.add(const Duration(days: 2)),
      place: 'Café Janis',
    );
    s.addToPlan(Ids.hannan);
    await _pump(t, s);
    await _shot(t, 'd-pending');

    s.nudgeDirector();
    await _pump(t, s);
    s.setMode(AppMode.planDetail);
    await _pump(t, s);
    await _shot(t, 'e-plan-detail');

    s.goHome();
    s.grantLocation();
    s.setView(GraphView.distance);
    await _pump(t, s);
    await _shot(t, 'f-nearby');

    s.dispose();
  });
}
