import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:lan_doudizhu/core/cards.dart';
import 'package:lan_doudizhu/core/rules.dart';

List<int> cards(List<int> ranks) {
  final used = <int, int>{};
  return ranks.map((rank) {
    final suit = used.update(rank, (v) => v + 1, ifAbsent: () => 0);
    return rank >= 16 ? rank + 36 : (rank - 3) * 4 + suit;
  }).toList();
}

void main() {
  final examples = <HandKind, List<int>>{
    HandKind.single: [3],
    HandKind.pair: [15, 15],
    HandKind.triple: [9, 9, 9],
    HandKind.tripleSingle: [3, 3, 3, 16],
    HandKind.triplePair: [6, 6, 6, 15, 15],
    HandKind.straight: [10, 11, 12, 13, 14],
    HandKind.pairStraight: [3, 3, 4, 4, 5, 5],
    HandKind.airplane: [3, 3, 3, 4, 4, 4],
    HandKind.airplaneSingles: [3, 3, 3, 4, 4, 4, 8, 8],
    HandKind.airplanePairs: [3, 3, 3, 4, 4, 4, 8, 8, 15, 15],
    HandKind.fourSingles: [3, 3, 3, 3, 16, 17],
    HandKind.fourPairs: [3, 3, 3, 3, 4, 4, 5, 5],
    HandKind.bomb: [15, 15, 15, 15],
    HandKind.rocket: [16, 17],
  };
  for (final entry in examples.entries) {
    test('classifies ${entry.key.label} independent of card order', () {
      final ids = cards(entry.value)..shuffle(Random(42));
      expect(classify(ids)?.kind, entry.key);
      expect(classify(ids)?.length, ids.length);
    });
  }
  test('joker labels, sorting and suit colors are correct', () {
    expect(PlayingCard(52).rank, 16);
    expect(PlayingCard(53).isRed, isTrue);
    expect(PlayingCard(1).isRed, isTrue);
    expect(sortedCards([0, 52, 53, 48]), [53, 52, 48, 0]);
  });
  test('rejects duplicate, invalid, broken runs and 2 in sequences', () {
    for (final ids in [
      <int>[],
      [0, 0],
      [-1],
      [54],
      cards([11, 12, 13, 14, 15]),
      cards([3, 4, 5, 6, 8]),
      cards([3, 3, 3, 5, 5, 5]),
      cards([3, 3, 4, 4]),
      cards([3, 3, 3, 3, 4, 4, 4, 4]),
      cards([3, 3, 3, 4, 4, 4, 3, 5]),
    ]) {
      expect(classify(ids), isNull, reason: '$ids');
    }
  });
  test(
    'comparison requires same shape and length, except bombs and rocket',
    () {
      final straight = classify(cards([3, 4, 5, 6, 7]))!;
      expect(classify(cards([4, 5, 6, 7, 8]))!.beats(straight), isTrue);
      expect(classify(cards([4, 5, 6, 7, 8, 9]))!.beats(straight), isFalse);
      expect(classify(cards([15, 15]))!.beats(straight), isFalse);
      final bomb = classify(cards([3, 3, 3, 3]))!;
      final rocket = classify([52, 53])!;
      expect(bomb.beats(straight), isTrue);
      expect(straight.beats(bomb), isFalse);
      expect(rocket.beats(bomb), isTrue);
      expect(bomb.beats(rocket), isFalse);
      expect(rocket.beats(rocket), isFalse);
      expect(bomb.beats(bomb), isFalse);
    },
  );
  test('hints cover every supported hand shape', () {
    for (final entry in examples.entries) {
      final ids = cards(entry.value);
      final suggestions = suggestPlays(ids, null);
      expect(
        suggestions.any((s) => classify(s)!.kind == entry.key),
        isTrue,
        reason: entry.key.name,
      );
    }
  });
  test('generated hints are legal, owned, unique, and can beat the table', () {
    for (var seed = 0; seed < 50; seed++) {
      final deck = List.generate(54, (i) => i)..shuffle(Random(seed));
      final hand = deck.take(20).toList();
      final previous = seed.isEven ? classify([0]) : null;
      final hints = suggestPlays(hand, previous);
      for (final hint in hints) {
        expect(hint.every(hand.contains), isTrue);
        expect(hint.toSet().length, hint.length);
        expect(classify(hint)!.beats(previous), isTrue);
      }
    }
  });
}
