import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:lan_doudizhu/core/game.dart';
import 'package:lan_doudizhu/core/rules.dart';

RoomGame newGame([int seed = 1]) {
  final game = RoomGame(hostId: 'a', hostName: '甲', random: Random(seed));
  game.addPlayer('b', '乙');
  game.addPlayer('c', '丙');
  return game;
}

void readyAll(RoomGame game) {
  for (final p in game.seats) {
    game.apply(p!.id, 'ready', {'ready': true});
  }
}

void main() {
  test(
    'requires exactly three connected ready players, with unique 54-card deal',
    () {
      final game = newGame();
      game.apply('a', 'ready', {'ready': true});
      game.apply('b', 'ready', {'ready': true});
      expect(game.phase, GamePhase.waiting);
      game.apply('c', 'ready', {'ready': true});
      expect(game.phase, GamePhase.bidding);
      expect(game.seats.map((p) => p!.hand.length), [17, 17, 17]);
      expect(
        <dynamic>{...game.seats.expand((p) => p!.hand), ...game.bottom}.length,
        54,
      );
      expect(() => game.addPlayer('d', '丁'), throwsA(isA<GameException>()));
    },
  );
  test(
    'all-pass bidding redeals and highest bidder receives exactly three bottom cards',
    () {
      final game = newGame();
      readyAll(game);
      final oldTurn = game.turn;
      for (var i = 0; i < 3; i++) {
        game.apply(game.seats[game.turn]!.id, 'bid', {'score': 0});
      }
      expect(game.phase, GamePhase.bidding);
      expect(game.turn, (oldTurn + 1) % 3);
      final landlord = game.turn;
      game.apply(game.seats[landlord]!.id, 'bid', {'score': 2});
      expect(
        () => game.apply(game.seats[game.turn]!.id, 'bid', {'score': 1}),
        throwsA(isA<GameException>()),
      );
      game.apply(game.seats[game.turn]!.id, 'bid', {'score': 0});
      game.apply(game.seats[game.turn]!.id, 'bid', {'score': 0});
      expect(game.landlord, landlord);
      expect(game.seats[landlord]!.hand.length, 20);
      expect(game.bottom.every(game.seats[landlord]!.hand.contains), isTrue);
    },
  );
  test(
    'rejects unowned cards, wrong turns, duplicate cards, and passing as leader without mutation',
    () {
      final game = newGame();
      readyAll(game);
      game.apply(game.seats[game.turn]!.id, 'bid', {'score': 3});
      final p = game.seats[game.turn]!;
      final original = jsonEncode(game.viewFor(p.id));
      expect(() => game.apply(p.id, 'pass', {}), throwsA(isA<GameException>()));
      expect(
        () => game.apply(p.id, 'play', {
          'cards': [p.hand.first, p.hand.first],
        }),
        throwsA(isA<GameException>()),
      );
      final foreign = game.seats[(game.turn + 1) % 3]!.hand.first;
      expect(
        () => game.apply(p.id, 'play', {
          'cards': [foreign],
        }),
        throwsA(isA<GameException>()),
      );
      expect(
        () => game.apply(game.seats[(game.turn + 1) % 3]!.id, 'play', {
          'cards': [foreign],
        }),
        throwsA(isA<GameException>()),
      );
      expect(jsonEncode(game.viewFor(p.id)), original);
    },
  );
  test('two passes clear trick and return lead to the last player', () {
    final game = newGame();
    readyAll(game);
    game.apply(game.seats[game.turn]!.id, 'bid', {'score': 3});
    final leader = game.turn;
    game.apply(game.seats[leader]!.id, 'play', {
      'cards': [game.seats[leader]!.hand.first],
    });
    for (var i = 0; i < 2; i++) {
      game.apply(game.seats[game.turn]!.id, 'pass', {});
    }
    expect(game.turn, leader);
    expect(game.lastCards, isNull);
  });
  test(
    'only own hand is in a view; bottom cards remain hidden during bidding',
    () {
      final game = newGame();
      readyAll(game);
      final view = game.viewFor('b');
      expect(view['hand'], game.player('b').hand);
      expect(view['bottom'], isEmpty);
      for (final p in view['players'] as List) {
        expect((p as Map).containsKey('hand'), isFalse);
      }
      expect(view.keys, isNot(contains('deck')));
    },
  );
  test(
    'first disconnect fixes deadline; a second disconnect cannot extend it',
    () {
      final game = newGame();
      readyAll(game);
      final now = DateTime.utc(2026);
      const grace = Duration(seconds: 60);
      game.setConnected('b', false, now, grace);
      game.setConnected(
        'c',
        false,
        now.add(const Duration(seconds: 40)),
        grace,
      );
      expect(game.reconnectDeadline, now.add(grace));
      expect(
        () => game.apply('a', 'bid', {'score': 3}),
        throwsA(isA<GameException>()),
      );
      game.setConnected('b', true, now.add(const Duration(seconds: 45)), grace);
      expect(game.paused, isTrue);
      game.setConnected('c', true, now.add(const Duration(seconds: 50)), grace);
      expect(game.paused, isFalse);
      expect(game.reconnectDeadline, isNull);
      game.setConnected('a', false, now.add(const Duration(minutes: 1)), grace);
      game.expire(now.add(const Duration(minutes: 2)));
      expect(game.phase, GamePhase.aborted);
      expect(game.seats.every((p) => p!.score == 0), isTrue);
    },
  );
  test('bomb and landlord spring multiply a zero-sum score', () {
    final game = newGame();
    readyAll(game);
    game.apply(game.seats[game.turn]!.id, 'bid', {'score': 3});
    final landlord = game.seats[game.landlord!]!;
    landlord.hand = [0, 1, 2, 3];
    game.apply(landlord.id, 'play', {
      'cards': [0, 1, 2, 3],
    });
    expect(game.multiplier, 4);
    expect(landlord.score, 24);
    expect(game.seats.where((p) => p != landlord).map((p) => p!.score), [
      -12,
      -12,
    ]);
    expect(game.result!['spring'], isTrue);
  });
  test('farmer victory after one landlord play gives reverse spring', () {
    final game = newGame();
    readyAll(game);
    game.apply(game.seats[game.turn]!.id, 'bid', {'score': 3});
    final landlord = game.seats[game.landlord!]!;
    final farmer = game.seats[(game.landlord! + 1) % 3]!;
    landlord.hand = [0, 4];
    farmer.hand = [8];
    game.apply(landlord.id, 'play', {
      'cards': [0],
    });
    game.apply(farmer.id, 'play', {
      'cards': [8],
    });
    expect(game.phase, GamePhase.finished);
    expect(landlord.score, -12);
    expect(farmer.score, 6);
    expect(game.result!['spring'], isTrue);
  });
  test(
    '100 seeded complete games terminate, preserve zero-sum scoring, and restart',
    () {
      for (var seed = 0; seed < 100; seed++) {
        final game = newGame(seed);
        readyAll(game);
        game.apply(game.seats[game.turn]!.id, 'bid', {'score': 3});
        var turns = 0;
        while (game.phase == GamePhase.playing && turns++ < 600) {
          final p = game.seats[game.turn]!;
          final hints = suggestPlays(
            p.hand,
            game.lastCards == null ? null : classify(game.lastCards!),
          );
          if (hints.isEmpty) {
            game.apply(p.id, 'pass', {});
          } else {
            game.apply(p.id, 'play', {'cards': hints.first});
          }
        }
        expect(game.phase, GamePhase.finished, reason: 'seed $seed');
        expect(game.seats.fold<int>(0, (sum, p) => sum + p!.score), 0);
        expect(game.seats.where((p) => p!.hand.isEmpty).length, 1);
        readyAll(game);
        expect(game.phase, GamePhase.bidding);
      }
    },
  );
}
