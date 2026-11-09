import 'dart:math';

/// Cards 0..51: clubs, diamonds, spades, hearts for ranks 3..2.
/// Cards 52 and 53 are the small and big jokers.
class PlayingCard {
  const PlayingCard(this.id) : assert(id >= 0 && id < 54);
  final int id;
  int get rank => id < 52 ? id ~/ 4 + 3 : id - 36;
  String get label => switch (rank) {
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    14 => 'A',
    15 => '2',
    16 => '小王',
    17 => '大王',
    _ => '$rank',
  };
  String get suit => id >= 52 ? '★' : ['♣', '♦', '♠', '♥'][id % 4];
  bool get isRed => id == 53 || (id < 52 && (id % 4 == 1 || id % 4 == 3));
}

List<int> sortedCards(Iterable<int> cards) => cards.toList()
  ..sort((a, b) {
    final rank = PlayingCard(b).rank.compareTo(PlayingCard(a).rank);
    return rank != 0 ? rank : b.compareTo(a);
  });

String secureId([int bytes = 18]) {
  final random = Random.secure();
  return List.generate(
    bytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
