import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lan_doudizhu/core/game.dart';
import 'package:lan_doudizhu/core/rules.dart';
import 'package:lan_doudizhu/network/room_client.dart';
import 'package:lan_doudizhu/network/room_host.dart';

Future<void> waitUntil(
  bool Function() condition, {
  int milliseconds = 6000,
}) async {
  final end = DateTime.now().add(Duration(milliseconds: milliseconds));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for network state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

void main() {
  late RoomHost host;
  final clients = <RoomClient>[];
  Uri uri() =>
      Uri(scheme: 'ws', host: '127.0.0.1', port: host.port, path: '/play');
  setUp(() async {
    host = await RoomHost.start('房主');
  });
  tearDown(() async {
    for (final client in clients.reversed) {
      await client.leave();
      client.dispose();
    }
    clients.clear();
    await host.close();
  });
  Future<RoomClient> join(String name, {String? token}) async {
    final client = await RoomClient.connect(uri(), name, token: token);
    clients.add(client);
    return client;
  }

  Future<void> three() async {
    await join('房主', token: host.hostToken);
    await join('小林');
    await join('阿青');
    await waitUntil(
      () => clients.every((c) => (c.state!['players'] as List).length == 3),
    );
  }

  Future<void> ready() async {
    for (final c in clients) {
      await waitUntil(() => c.state!['revision'] == host.game.revision);
      await c.action('ready', {'ready': true});
    }
    await waitUntil(() => clients.every((c) => c.state!['phase'] == 'bidding'));
  }

  test('only local addresses accepted', () {
    for (final address in [
      '127.0.0.1',
      '192.168.1.3',
      '10.0.1.2',
      '172.16.0.1',
      '169.254.2.3',
      'fd00::1',
    ]) {
      expect(isLanAddress(address), isTrue, reason: address);
    }
    for (final address in ['8.8.8.8', 'example.com', '172.32.0.1', '0.0.0.0']) {
      expect(isLanAddress(address), isFalse, reason: address);
    }
  });

  test(
    'reconnect countdown uses relative time instead of another device clock',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      WebSocket? peer;
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        peer = socket;
        socket.listen((dynamic raw) {
          final value = jsonDecode(raw as String) as Map;
          if (value['type'] == 'join') {
            socket.add(
              jsonEncode({
                'type': 'welcome',
                'playerId': 'clock-test',
                'token': 'test-only',
              }),
            );
            socket.add(
              jsonEncode({
                'type': 'state',
                'state': {
                  'revision': 1,
                  'paused': true,
                  'deadline': '2099-01-01T00:00:00.000Z',
                  'remainingMs': 2000,
                },
              }),
            );
          }
        });
      });
      final client = await RoomClient.connect(
        Uri(scheme: 'ws', host: '127.0.0.1', port: server.port, path: '/play'),
        '测试',
      );
      expect(client.secondsLeft, inInclusiveRange(1, 2));
      await client.leave();
      client.dispose();
      await peer?.close();
      await server.close(force: true);
    },
  );
  test(
    'three real sockets complete a game and expose only individual hands',
    () async {
      await three();
      await expectLater(
        RoomClient.connect(uri(), '第四位'),
        throwsA(isA<GameException>()),
      );
      await ready();
      final deal = clients
          .expand((c) => (c.state!['hand'] as List).cast<int>())
          .toSet();
      expect(deal.length, 51);
      expect(
        clients.every((c) => (c.state!['bottom'] as List).isEmpty),
        isTrue,
      );
      final bidder = clients.firstWhere(
        (c) => c.playerId == host.game.seats[host.game.turn]!.id,
      );
      await bidder.action('bid', {'score': 3});
      var actions = 0;
      while (host.game.phase == GamePhase.playing && actions++ < 600) {
        final actor = clients.firstWhere(
          (c) => c.playerId == host.game.seats[host.game.turn]!.id,
        );
        await waitUntil(() => actor.state!['revision'] == host.game.revision);
        final hand = (actor.state!['hand'] as List).cast<int>();
        final last = (actor.state!['lastCards'] as List?)?.cast<int>();
        final hints = suggestPlays(hand, last == null ? null : classify(last));
        await actor.action(
          hints.isEmpty ? 'pass' : 'play',
          hints.isEmpty ? {} : {'cards': hints.first},
        );
      }
      await waitUntil(
        () => clients.every((c) => c.state!['phase'] == 'finished'),
      );
      expect(host.game.phase, GamePhase.finished);
      expect(clients.map((c) => c.state!['revision']).toSet().length, 1);
      expect(host.game.seats.fold<int>(0, (sum, p) => sum + p!.score), 0);
    },
  );
  test(
    'stale, duplicate and malformed commands cannot advance a game twice',
    () async {
      final raw = await WebSocket.connect(uri().toString());
      final messages = <Map<String, dynamic>>[];
      final subscription = raw.listen((dynamic r) {
        final m = jsonDecode(r as String) as Map<String, dynamic>;
        messages.add(m);
        if (m['type'] == 'ping') raw.add(jsonEncode({'type': 'pong'}));
      });
      raw.add(jsonEncode({'type': 'join', 'protocol': 1, 'name': '测试'}));
      await waitUntil(() => messages.any((m) => m['type'] == 'state'));
      final welcome = messages.firstWhere((m) => m['type'] == 'welcome');
      final id = welcome['playerId'] as String;
      final command = {
        'type': 'action',
        'id': 'request-1',
        'revision': host.game.revision,
        'action': 'ready',
        'data': {'ready': true},
      };
      raw.add(jsonEncode(command));
      await waitUntil(() => messages.any((m) => m['type'] == 'ack'));
      final revision = host.game.revision;
      raw.add(jsonEncode(command));
      await waitUntil(
        () => messages.where((m) => m['type'] == 'ack').length == 2,
      );
      expect(host.game.revision, revision);
      expect(host.game.player(id).ready, isTrue);
      raw.add(jsonEncode({...command, 'id': 'request-2', 'revision': -1}));
      raw.add('this is not json');
      await waitUntil(
        () => messages.where((m) => m['type'] == 'error').length >= 2,
      );
      expect(host.game.revision, revision);
      await raw.close();
      await subscription.cancel();
    },
  );
  test(
    'client suspension pauses all players and token reconnect keeps cards and turn',
    () async {
      await three();
      await ready();
      final client = clients[1];
      final id = client.playerId;
      final hand = List<int>.from(client.state!['hand'] as List);
      final turn = host.game.turn;
      client.suspend();
      await waitUntil(
        () => host.game.paused && clients[0].state!['paused'] == true,
      );
      client.resume();
      await waitUntil(
        () =>
            client.connected &&
            !host.game.paused &&
            clients.every((c) => c.state!['paused'] == false),
      );
      expect(client.playerId, id);
      expect(client.state!['hand'], hand);
      expect(host.game.turn, turn);
    },
  );
  test('host backgrounding and resuming preserves room within grace', () async {
    await three();
    await ready();
    host.suspend();
    clients[0].suspend();
    await waitUntil(() => clients[1].state!['paused'] == true);
    host.resume();
    clients[0].resume();
    await waitUntil(
      () => clients.every((c) => c.connected && c.state!['paused'] == false),
    );
    expect(host.closed, isFalse);
  });
  test(
    'timeout aborts without points; explicit guest leave ends the current round',
    () async {
      await three();
      await ready();
      clients[1].suspend();
      await waitUntil(() => host.game.paused);
      host.game.expire(DateTime.now().add(const Duration(seconds: 61)));
      expect(host.game.phase, GamePhase.aborted);
      expect(host.game.seats.every((p) => p!.score == 0), isTrue);
      clients[1].resume();
      await waitUntil(() => clients[1].connected);
      await ready();
      await clients[2].leave();
      await waitUntil(() => host.game.phase == GamePhase.aborted);
    },
  );
  test(
    'host exit closes guest clients and rejects incompatible protocol',
    () async {
      await three();
      final bad = await WebSocket.connect(uri().toString());
      final first = bad.first;
      bad.add(jsonEncode({'type': 'join', 'protocol': 99, 'name': '旧版'}));
      final message = jsonDecode(await first as String) as Map;
      expect(message['fatal'], isTrue);
      await bad.close();
      await host.close();
      await waitUntil(() => clients.every((c) => c.terminalError != null));
    },
  );

  test(
    'host resume enforces elapsed grace even before the heartbeat timer fires',
    () async {
      await host.close();
      host = await RoomHost.start(
        '房主',
        grace: const Duration(milliseconds: 150),
      );
      await three();
      await ready();
      host.suspend();
      clients[0].suspend();
      await Future<void>.delayed(const Duration(milliseconds: 210));
      host.resume();
      expect(host.closed, isTrue);
      expect(host.game.phase, GamePhase.aborted);
      expect(host.game.seats.every((p) => p!.score == 0), isTrue);
      await waitUntil(() => clients[1].terminalError != null);
    },
  );
}
