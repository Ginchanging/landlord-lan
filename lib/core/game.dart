import 'dart:math';
import 'cards.dart';
import 'rules.dart';

enum GamePhase { waiting, bidding, playing, finished, aborted }

class GameException implements Exception {
  const GameException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PlayerSeat {
  PlayerSeat(this.id, this.name);
  final String id;
  final String name;
  bool ready = false;
  bool connected = true;
  int score = 0;
  List<int> hand = [];
  int plays = 0;
}

class RoomGame {
  RoomGame({required String hostId, required String hostName, Random? random})
    : _random = random ?? Random.secure(),
      roomId = secureId(4) {
    seats[0] = PlayerSeat(hostId, hostName);
  }
  final Random _random;
  final String roomId;
  final List<PlayerSeat?> seats = List.filled(3, null);
  GamePhase phase = GamePhase.waiting;
  int revision = 0;
  int turn = 0;
  int startingSeat = 0;
  int highBid = 0;
  int? highBidder;
  int bids = 0;
  int? landlord;
  int multiplier = 1;
  int completedRounds = 0;
  List<int> bottom = [];
  List<int>? lastCards;
  int? lastPlayer;
  int passes = 0;
  String message = '等待三位玩家入座';
  DateTime? reconnectDeadline;
  final Map<String, Map<String, Object?>> moves = {};
  Map<String, Object?>? result;
  bool get active => phase == GamePhase.bidding || phase == GamePhase.playing;
  bool get paused => active && seats.any((p) => p == null || !p.connected);
  PlayerSeat player(String id) => seats.whereType<PlayerSeat>().firstWhere(
    (p) => p.id == id,
    orElse: () => throw const GameException('你不在此房间内'),
  );

  void addPlayer(String id, String name) {
    if (active) throw const GameException('牌局已经开始');
    final index = seats.indexOf(null);
    if (index < 0) throw const GameException('房间已满，请选择其他房间');
    seats[index] = PlayerSeat(id, name);
    revision++;
    message = '$name 已入座';
  }

  void removePlayer(String id) {
    final index = seats.indexWhere((p) => p?.id == id);
    if (index <= 0) return;
    if (active) abort('有玩家离开，本局结束，不计分');
    seats[index] = null;
    for (final p in seats.whereType<PlayerSeat>()) {
      p.ready = false;
    }
    revision++;
  }

  void setConnected(String id, bool connected, DateTime now, Duration grace) {
    final p = player(id);
    if (p.connected == connected) return;
    p.connected = connected;
    if (active) {
      if (!connected) {
        reconnectDeadline ??= now.add(grace);
        message = '${p.name} 连接中断，等待重连';
      } else if (!paused) {
        reconnectDeadline = null;
        message = '所有玩家已连接，牌局继续';
      }
    } else if (!connected) {
      p.ready = false;
    }
    revision++;
  }

  void expire(DateTime now) {
    if (active &&
        reconnectDeadline != null &&
        !now.isBefore(reconnectDeadline!)) {
      abort('重连等待超时，本局结束，不计分');
    }
  }

  void abort(String reason) {
    if (!active) return;
    phase = GamePhase.aborted;
    reconnectDeadline = null;
    result = null;
    message = reason;
    for (final p in seats.whereType<PlayerSeat>()) {
      p.ready = false;
    }
    revision++;
  }

  void apply(String id, String action, Map<String, dynamic> data) {
    if (paused) throw const GameException('牌局暂停，等待其他玩家重连');
    final p = player(id);
    if (!p.connected) throw const GameException('请先重新连接');
    if (action == 'ready') {
      if (active) throw const GameException('当前牌局尚未结束');
      if (data['ready'] is! bool) {
        throw const GameException('准备状态无效');
      }
      p.ready = data['ready'] == true;
      if (seats.every((p) => p != null && p.connected && p.ready)) {
        startingSeat = _random.nextInt(3);
        _deal();
      }
    } else {
      if (!active || seats[turn]?.id != id) throw const GameException('还没有轮到你');
      switch (action) {
        case 'bid':
          final score = data['score'];
          if (phase != GamePhase.bidding ||
              score is! int ||
              score < 0 ||
              score > 3 ||
              (score != 0 && score <= highBid)) {
            throw const GameException('叫分无效');
          }
          _bid(score);
        case 'play':
          if (phase != GamePhase.playing ||
              data['cards'] is! List ||
              (data['cards'] as List).any((c) => c is! int)) {
            throw const GameException('出牌格式无效');
          }
          _play((data['cards'] as List).cast<int>());
        case 'pass':
          if (phase != GamePhase.playing ||
              lastCards == null ||
              lastPlayer == turn) {
            throw const GameException('你需要先出牌');
          }
          moves[id] = {'cards': <int>[], 'label': '不出'};
          message = '${p.name} 不出';
          passes++;
          if (passes == 2) {
            turn = lastPlayer!;
            lastCards = null;
            lastPlayer = null;
            passes = 0;
            moves.clear();
            message = '${seats[turn]!.name} 获得出牌权';
          } else {
            turn = (turn + 1) % 3;
          }
        default:
          throw const GameException('未知操作');
      }
    }
    revision++;
  }

  void _deal() {
    phase = GamePhase.bidding;
    result = null;
    landlord = null;
    highBid = 0;
    highBidder = null;
    bids = 0;
    multiplier = 1;
    passes = 0;
    lastCards = null;
    lastPlayer = null;
    reconnectDeadline = null;
    moves.clear();
    final deck = List.generate(54, (i) => i)..shuffle(_random);
    for (var i = 0; i < 3; i++) {
      final p = seats[i]!;
      p.hand = sortedCards(deck.sublist(i * 17, i * 17 + 17));
      p.ready = false;
      p.plays = 0;
    }
    bottom = deck.sublist(51);
    turn = startingSeat;
    message = '发牌完成，请 ${seats[turn]!.name} 叫分';
  }

  void _bid(int score) {
    bids++;
    moves[seats[turn]!.id] = {
      'cards': <int>[],
      'label': score == 0 ? '不叫' : '$score 分',
    };
    if (score > 0) {
      highBid = score;
      highBidder = turn;
    }
    if (score == 3 || bids == 3) {
      if (highBidder == null) {
        startingSeat = (startingSeat + 1) % 3;
        _deal();
        message = '全员不叫，已重新发牌';
        return;
      }
      landlord = highBidder;
      turn = landlord!;
      seats[turn]!.hand = sortedCards([...seats[turn]!.hand, ...bottom]);
      phase = GamePhase.playing;
      moves.clear();
      message = '${seats[turn]!.name} 成为地主，先出牌';
    } else {
      turn = (turn + 1) % 3;
    }
  }

  void _play(List<int> cards) {
    final p = seats[turn]!;
    if (cards.any((c) => !p.hand.contains(c))) {
      throw const GameException('手牌中没有这些牌');
    }
    final hand = classify(cards);
    if (hand == null) throw const GameException('请选择有效的牌型');
    if (!hand.beats(lastCards == null ? null : classify(lastCards!))) {
      throw const GameException('所选牌不能压过上一手');
    }
    p.hand.removeWhere(cards.contains);
    p.plays++;
    lastCards = sortedCards(cards);
    lastPlayer = turn;
    passes = 0;
    moves[p.id] = {'cards': lastCards, 'label': hand.kind.label};
    if (hand.isBomb) multiplier *= 2;
    message = '${p.name} 出了${hand.kind.label}';
    if (p.hand.isEmpty) {
      _finish(turn);
    } else {
      turn = (turn + 1) % 3;
    }
  }

  void _finish(int winner) {
    final landlordWon = winner == landlord;
    final spring = landlordWon
        ? seats
              .asMap()
              .entries
              .where((e) => e.key != landlord)
              .every((e) => e.value!.plays == 0)
        : seats[landlord!]!.plays <= 1;
    if (spring) multiplier *= 2;
    final unit = highBid * multiplier;
    final deltas = <String, int>{};
    for (var i = 0; i < 3; i++) {
      final delta = i == landlord
          ? (landlordWon ? 2 * unit : -2 * unit)
          : (landlordWon ? -unit : unit);
      seats[i]!.score += delta;
      deltas[seats[i]!.id] = delta;
    }
    completedRounds++;
    phase = GamePhase.finished;
    result = {'landlordWon': landlordWon, 'spring': spring, 'deltas': deltas};
    message =
        '${landlordWon ? '地主' : '农民'}获胜${spring ? ' · ${landlordWon ? '春天' : '反春天'}' : ''}';
  }

  Map<String, Object?> viewFor(String id) => {
    'protocol': 1,
    'roomId': roomId,
    'revision': revision,
    'phase': phase.name,
    'myId': id,
    'turn': seats[turn]?.id,
    'landlord': landlord == null ? null : seats[landlord!]?.id,
    'highBid': highBid,
    'multiplier': multiplier,
    'round': completedRounds + (active ? 1 : 0),
    'paused': paused,
    'deadline': reconnectDeadline?.toUtc().toIso8601String(),
    'remainingMs': reconnectDeadline
        ?.difference(DateTime.now())
        .inMilliseconds
        .clamp(0, 60000),
    'bottom': landlord == null ? <int>[] : List<int>.of(bottom),
    'hand': List<int>.of(player(id).hand),
    'players': seats
        .whereType<PlayerSeat>()
        .map(
          (p) => {
            'id': p.id,
            'name': p.name,
            'ready': p.ready,
            'connected': p.connected,
            'score': p.score,
            'remaining': p.hand.length,
            'host': identical(p, seats[0]),
          },
        )
        .toList(),
    'lastCards': lastCards == null ? null : List<int>.of(lastCards!),
    'lastPlayer': lastPlayer,
    'lastPlayerId': lastPlayer == null ? null : seats[lastPlayer!]?.id,
    'moves': Map<String, Map<String, Object?>>.of(moves),
    'message': message,
    'result': result,
  };
}
