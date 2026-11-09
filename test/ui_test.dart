import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lan_doudizhu/core/game.dart';
import 'package:lan_doudizhu/network/discovery.dart';
import 'package:lan_doudizhu/ui/screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundaryKey = GlobalKey();
  setUpAll(() async {
    final loader = FontLoader('NotoSansSC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansSC.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Future<void> show(WidgetTester tester, Widget child, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tableTheme(),
          home: Scaffold(body: TableBackground(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_SCREENSHOTS')) return;
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('docs/screenshots')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Map<String, dynamic> gameState() {
    final game = RoomGame(hostId: 'a', hostName: '小满', random: Random(6));
    game.addPlayer('b', '阿林');
    game.addPlayer('c', '小夏');
    for (final p in game.seats) {
      game.apply(p!.id, 'ready', {'ready': true});
    }
    game.turn = 0;
    game.apply('a', 'bid', {'score': 3});
    return Map<String, dynamic>.from(game.viewFor('a'));
  }

  testWidgets(
    'home fits phone landscape and exposes create, join, and room search',
    (tester) async {
      final name = TextEditingController(text: '小满');
      final address = TextEditingController();
      final discovery = RoomDiscovery();
      var created = false;
      for (final size in [const Size(844, 390), const Size(568, 320)]) {
        await show(
          tester,
          HomeScreen(
            name: name,
            address: address,
            discovery: discovery,
            busy: false,
            onCreate: () => created = true,
            onJoin: ([room]) {},
          ),
          size,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('无需互联网'), findsOneWidget);
      }
      await tester.tap(find.text('创建牌桌'));
      expect(created, isTrue);
      await show(
        tester,
        HomeScreen(
          name: name,
          address: address,
          discovery: discovery,
          busy: false,
          onCreate: () {},
          onJoin: ([room]) {},
        ),
        const Size(844, 390),
      );
      await capture(tester, 'home');
      await tester.pumpWidget(const SizedBox());
      name.dispose();
      address.dispose();
      discovery.dispose();
    },
  );
  testWidgets(
    '20-card table fits small phones; card selection and hint are interactive',
    (tester) async {
      final state = gameState();
      final hand = (state['hand'] as List).cast<int>();
      int? clicked;
      var hinted = false;
      final selected = <int>{};
      Widget table() => TableScreen(
        state: state,
        connected: true,
        fatalError: null,
        secondsLeft: 0,
        busy: false,
        selected: selected,
        onSelect: (id) => clicked = id,
        onAction: (action, [data = const {}]) {},
        onHint: () => hinted = true,
        onClear: () {},
        onExit: () {},
        onHome: () {},
        onConnection: () {},
      );
      for (final size in [const Size(568, 320), const Size(844, 390)]) {
        await show(tester, table(), size);
        expect(tester.takeException(), isNull);
        expect(find.byType(CardFace), findsNWidgets(23));
      }
      final position = tester.getTopLeft(find.byKey(ValueKey(hand.first)));
      await tester.tapAt(position + const Offset(8, 32));
      expect(clicked, hand.first);
      await tester.tap(find.text('提示'));
      expect(hinted, isTrue);
      selected.addAll(hand.take(2));
      await show(tester, table(), const Size(844, 390));
      await capture(tester, 'table');
    },
  );
  testWidgets('pause blocks game actions and displays reconnection countdown', (
    tester,
  ) async {
    final state = gameState()..['paused'] = true;
    await show(
      tester,
      TableScreen(
        state: state,
        connected: true,
        fatalError: null,
        secondsLeft: 48,
        busy: false,
        selected: {},
        onSelect: (_) {},
        onAction: (action, [data = const {}]) {},
        onHint: () {},
        onClear: () {},
        onExit: () {},
        onHome: () {},
        onConnection: () {},
      ),
      const Size(844, 390),
    );
    expect(find.textContaining('剩余 48 秒'), findsOneWidget);
    expect(find.text('牌局暂停，等朋友回来'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'reconnect');
  });

  testWidgets(
    'Windows home supports resizing, keyboard entry, and mouse clicks',
    (tester) async {
      final name = TextEditingController(text: '电脑牌友');
      final address = TextEditingController();
      final discovery = RoomDiscovery();
      var created = false;
      NearbyRoom? joined;
      discovery.rooms = [const NearbyRoom('朋友的牌桌', '192.168.1.8', 39001)];
      Widget home() => HomeScreen(
        name: name,
        address: address,
        discovery: discovery,
        busy: false,
        onCreate: () => created = true,
        onJoin: ([room]) => joined = room,
      );
      for (final size in [
        const Size(640, 360),
        const Size(1100, 680),
        const Size(1440, 900),
      ]) {
        await show(tester, home(), size);
        expect(tester.takeException(), isNull);
      }
      await tester.enterText(find.byType(TextField).first, 'Windows牌友');
      expect(name.text, 'Windows牌友');
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(find.text('创建牌桌')));
      await mouse.down(tester.getCenter(find.text('创建牌桌')));
      await mouse.up();
      expect(created, isTrue);
      await mouse.down(tester.getCenter(find.text('朋友的牌桌')));
      await mouse.up();
      expect(joined?.address, '192.168.1.8');
      await mouse.removePointer();
      await show(tester, home(), const Size(1100, 680));
      await capture(tester, 'windows-home');
      await tester.pumpWidget(const SizedBox());
      name.dispose();
      address.dispose();
      discovery.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'Windows 20-card table supports a mouse-selected legal play',
    (tester) async {
      final state = gameState();
      final hand = (state['hand'] as List).cast<int>();
      final selected = <int>{};
      String? sentAction;
      Map<String, Object?>? sentData;
      Widget table() => StatefulBuilder(
        builder: (context, update) => TableScreen(
          state: state,
          connected: true,
          fatalError: null,
          secondsLeft: 0,
          busy: false,
          selected: selected,
          onSelect: (id) => update(() {
            if (!selected.add(id)) selected.remove(id);
          }),
          onAction: (action, [data = const {}]) {
            sentAction = action;
            sentData = data;
          },
          onHint: () {},
          onClear: () {},
          onExit: () {},
          onHome: () {},
          onConnection: () {},
        ),
      );
      for (final size in [
        const Size(640, 360),
        const Size(1100, 680),
        const Size(1440, 900),
      ]) {
        await show(tester, table(), size);
        expect(tester.takeException(), isNull);
      }
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer();
      final card = tester.getTopLeft(find.byKey(ValueKey(hand.first)));
      await mouse.down(card + const Offset(8, 32));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(selected, {hand.first});
      final button = find.text('出牌 · 单张');
      await mouse.down(tester.getCenter(button));
      await mouse.up();
      expect(sentAction, 'play');
      expect(sentData?['cards'], [hand.first]);
      await mouse.removePointer();
      await show(tester, table(), const Size(1100, 680));
      await capture(tester, 'windows-table');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
