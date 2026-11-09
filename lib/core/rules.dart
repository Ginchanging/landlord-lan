import 'cards.dart';

enum HandKind {
  single('单张'),
  pair('对子'),
  triple('三张'),
  tripleSingle('三带一'),
  triplePair('三带一对'),
  straight('顺子'),
  pairStraight('连对'),
  airplane('飞机'),
  airplaneSingles('飞机带单'),
  airplanePairs('飞机带对'),
  fourSingles('四带二'),
  fourPairs('四带两对'),
  bomb('炸弹'),
  rocket('王炸');

  const HandKind(this.label);
  final String label;
}

class Combination {
  const Combination(this.kind, this.rank, this.length);
  final HandKind kind;
  final int rank;
  final int length;
  bool get isBomb => kind == HandKind.bomb || kind == HandKind.rocket;

  bool beats(Combination? previous) {
    if (previous == null) return true;
    if (previous.kind == HandKind.rocket) return false;
    if (kind == HandKind.rocket) return true;
    if (kind == HandKind.bomb && previous.kind != HandKind.bomb) return true;
    return kind == previous.kind &&
        length == previous.length &&
        rank > previous.rank;
  }
}

Map<int, List<int>> groupCards(Iterable<int> cards) {
  final groups = <int, List<int>>{};
  for (final card in cards) {
    groups.putIfAbsent(PlayingCard(card).rank, () => []).add(card);
  }
  return groups;
}

bool _consecutive(List<int> ranks) {
  if (ranks.isEmpty || ranks.last > 14) return false;
  for (var i = 1; i < ranks.length; i++) {
    if (ranks[i] != ranks[i - 1] + 1) return false;
  }
  return true;
}

Combination? classify(List<int> cards) {
  if (cards.isEmpty ||
      cards.toSet().length != cards.length ||
      cards.any((id) => id < 0 || id > 53)) {
    return null;
  }
  final groups = groupCards(cards);
  final ranks = groups.keys.toList()..sort();
  final counts = groups.map((rank, value) => MapEntry(rank, value.length));
  final n = cards.length;
  Combination hand(HandKind kind, int rank) => Combination(kind, rank, n);
  if (n == 1) return hand(HandKind.single, ranks.single);
  if (n == 2 && ranks.length == 2 && ranks.first == 16 && ranks.last == 17) {
    return hand(HandKind.rocket, 17);
  }
  if (ranks.length == 1) {
    return switch (n) {
      2 => hand(HandKind.pair, ranks.single),
      3 => hand(HandKind.triple, ranks.single),
      4 => hand(HandKind.bomb, ranks.single),
      _ => null,
    };
  }
  final triples = ranks.where((r) => counts[r] == 3).toList();
  final fours = ranks.where((r) => counts[r] == 4).toList();
  if (n == 4 && triples.length == 1) {
    return hand(HandKind.tripleSingle, triples.single);
  }
  if (n == 5 && triples.length == 1 && counts.values.contains(2)) {
    return hand(HandKind.triplePair, triples.single);
  }
  if (n >= 5 && ranks.length == n && _consecutive(ranks)) {
    return hand(HandKind.straight, ranks.last);
  }
  if (n >= 6 && counts.values.every((c) => c == 2) && _consecutive(ranks)) {
    return hand(HandKind.pairStraight, ranks.last);
  }
  if (n >= 6 && counts.values.every((c) => c == 3) && _consecutive(ranks)) {
    return hand(HandKind.airplane, ranks.last);
  }
  // Body ranks contain exactly three cards. Wings cannot reuse a body rank.
  // Single wings may be a pair; pair wings must be distinct pairs.
  for (final wingSize in [1, 2]) {
    final width = 3 + wingSize;
    if (n % width != 0) continue;
    final bodyLength = n ~/ width;
    if (bodyLength < 2) continue;
    for (var i = 0; i + bodyLength <= triples.length; i++) {
      final body = triples.sublist(i, i + bodyLength);
      if (!_consecutive(body)) continue;
      final rest = ranks.where((r) => !body.contains(r)).toList();
      final valid = wingSize == 1
          ? rest.every((r) => counts[r]! <= 2)
          : rest.length == bodyLength && rest.every((r) => counts[r] == 2);
      if (valid) {
        return hand(
          wingSize == 1 ? HandKind.airplaneSingles : HandKind.airplanePairs,
          body.last,
        );
      }
    }
  }
  if (fours.length == 1 && n == 6) {
    return hand(HandKind.fourSingles, fours.single);
  }
  if (fours.length == 1 &&
      n == 8 &&
      ranks.length == 3 &&
      ranks.where((r) => r != fours.single).every((r) => counts[r] == 2)) {
    return hand(HandKind.fourPairs, fours.single);
  }
  return null;
}

/// Generates representative legal plays without enumerating 2^20 subsets.
/// Every supported shape/body is considered; wings use the lowest ranks.
List<List<int>> suggestPlays(List<int> cards, Combination? previous) {
  final groups = groupCards(cards);
  final ranks = groups.keys.toList()..sort();
  final candidates = <List<int>>[];
  final seen = <String>{};
  void add(Iterable<int> values) {
    final ids = values.toList()..sort();
    final hand = classify(ids);
    if (hand != null && hand.beats(previous) && seen.add(ids.join(','))) {
      candidates.add(ids);
    }
  }

  for (final r in ranks) {
    final g = groups[r]!;
    for (var count = 1; count <= g.length; count++) {
      add(g.take(count));
    }
    if (g.length >= 3) {
      for (final other in ranks.where((v) => v != r)) {
        add([...g.take(3), groups[other]!.first]);
        if (groups[other]!.length >= 2) {
          add([...g.take(3), ...groups[other]!.take(2)]);
        }
      }
    }
    if (g.length == 4) {
      final others = ranks.where((v) => v != r).toList();
      final singles = others.expand((v) => groups[v]!.take(2)).toList();
      if (singles.length >= 2) add([...g, ...singles.take(2)]);
      final pairs = others
          .where((v) => groups[v]!.length >= 2)
          .take(2)
          .toList();
      if (pairs.length == 2) {
        add([...g, ...pairs.expand((v) => groups[v]!.take(2))]);
      }
    }
  }
  if (groups.containsKey(16) && groups.containsKey(17)) add([52, 53]);
  for (final copies in [1, 2, 3]) {
    final minLength = copies == 1
        ? 5
        : copies == 2
        ? 3
        : 2;
    for (var start = 3; start <= 14; start++) {
      final bodyRanks = <int>[];
      for (var end = start; end <= 14; end++) {
        if ((groups[end]?.length ?? 0) < copies) break;
        bodyRanks.add(end);
        if (bodyRanks.length < minLength) continue;
        final body = bodyRanks.expand((v) => groups[v]!.take(copies)).toList();
        add(body);
        if (copies == 3) {
          final others = ranks.where((v) => !bodyRanks.contains(v)).toList();
          final singles = others.expand((v) => groups[v]!.take(2)).toList();
          if (singles.length >= bodyRanks.length) {
            add([...body, ...singles.take(bodyRanks.length)]);
          }
          final pairs = others
              .where((v) => groups[v]!.length >= 2)
              .take(bodyRanks.length)
              .toList();
          if (pairs.length == bodyRanks.length) {
            add([...body, ...pairs.expand((v) => groups[v]!.take(2))]);
          }
        }
      }
    }
  }
  candidates.sort((a, b) {
    final x = classify(a)!;
    final y = classify(b)!;
    final bomb = (x.isBomb ? 1 : 0).compareTo(y.isBomb ? 1 : 0);
    if (bomb != 0) return bomb;
    if (previous == null && a.length != b.length) {
      return b.length.compareTo(a.length);
    }
    return x.rank.compareTo(y.rank);
  });
  return candidates;
}
