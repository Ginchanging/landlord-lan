import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/cards.dart';
import '../core/rules.dart';
import '../network/discovery.dart';

const gold = Color(0xFFE5BC70);
const cream = Color(0xFFF9F5E9);
const muted = Color(0xFFAAC4B6);
const panel = Color(0xFF133F34);

ThemeData tableTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: 'NotoSansSC',
  scaffoldBackgroundColor: const Color(0xFF082A24),
  colorScheme: ColorScheme.fromSeed(
    seedColor: gold,
    brightness: Brightness.dark,
    primary: gold,
    onPrimary: const Color(0xFF223C2E),
    surface: panel,
    onSurface: cream,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF0A3028),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF3B5C4F)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF3B5C4F)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(82, 43),
      textStyle: const TextStyle(
        fontSize: 14,
        fontFamily: 'NotoSansSC',
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(75, 43),
      foregroundColor: cream,
      side: const BorderSide(color: Color(0xFF577567)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: cream,
    contentTextStyle: TextStyle(
      color: Color(0xFF193A2E),
      fontFamily: 'NotoSansSC',
    ),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  ),
);

class TableBackground extends StatelessWidget {
  const TableBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -.2),
        radius: 1.1,
        colors: [Color(0xFF1E5946), Color(0xFF0D372D), Color(0xFF07261F)],
      ),
    ),
    child: CustomPaint(painter: _FeltPainter(), child: child),
  );
}

class _FeltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .015)
      ..strokeWidth = .7;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      const Radius.circular(26),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = gold.withValues(alpha: .09)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.icon, this.color = muted});
  final String text;
  final IconData? icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: .15)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.name,
    required this.address,
    required this.discovery,
    required this.busy,
    required this.onCreate,
    required this.onJoin,
  });
  final TextEditingController name;
  final TextEditingController address;
  final RoomDiscovery discovery;
  final bool busy;
  final VoidCallback onCreate;
  final void Function([NearbyRoom?]) onJoin;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 370;
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 24 : 36,
          vertical: compact ? 12 : 16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.style_rounded, color: gold, size: 25),
                const SizedBox(width: 9),
                const Text(
                  '同桌',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '局域网斗地主',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
                const Spacer(),
                const Pill('无需互联网', icon: Icons.wifi_rounded, color: gold),
              ],
            ),
            SizedBox(height: compact ? 12 : 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 9,
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '好牌，和朋友一起打。',
                                style: TextStyle(
                                  color: gold,
                                  fontSize: 12,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '一张牌桌，\n三个朋友。',
                                style: TextStyle(
                                  fontSize: compact ? 30 : 38,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '连上同一个 Wi-Fi 或热点\n把熟悉的快乐，带到身边。',
                                style: TextStyle(
                                  color: muted,
                                  height: 1.8,
                                  fontSize: 12,
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(height: 14),
                                const _FanCards(),
                              ],
                              const SizedBox(height: 15),
                              const Wrap(
                                spacing: 12,
                                runSpacing: 5,
                                children: [
                                  Pill('三人真人对局', icon: Icons.groups_outlined),
                                  Pill(
                                    'iOS × Android',
                                    icon: Icons.phone_iphone_rounded,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: constraints.maxWidth < 700 ? 20 : 40),
                  Expanded(
                    flex: 11,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: panel.withValues(alpha: .87),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: gold.withValues(alpha: .18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .15),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '准备入座',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                if (busy)
                                  const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: name,
                                    enabled: !busy,
                                    maxLength: 12,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      labelText: '你的昵称',
                                      counterText: '',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.icon(
                                  onPressed: busy ? null : onCreate,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('创建牌桌'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 17),
                            Row(
                              children: [
                                const Text(
                                  '附近的牌桌',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: busy ? null : discovery.scan,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.refresh_rounded,
                                          size: 15,
                                          color: gold,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          discovery.scanning ? '搜索中' : '刷新',
                                          style: const TextStyle(
                                            color: gold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (discovery.rooms.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text(
                                  discovery.error ?? '还没有发现牌桌，让一位朋友先创建吧。',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                    height: 1.7,
                                  ),
                                ),
                              ),
                            for (final room in discovery.rooms)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.wifi_tethering_rounded,
                                  color: gold,
                                  size: 21,
                                ),
                                title: Text(
                                  room.name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: busy ? null : () => onJoin(room),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: address,
                                    enabled: !busy,
                                    keyboardType: TextInputType.url,
                                    autocorrect: false,
                                    onSubmitted: (_) {
                                      if (!busy) onJoin();
                                    },
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      labelText: '手动输入 IP:端口',
                                      hintText: '192.168.1.8:39001',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: busy ? null : () => onJoin(),
                                  child: const Text('加入'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '连接后，三人准备即可开局。',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _FanCards extends StatelessWidget {
  const _FanCards();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    height: 110,
    child: Stack(
      children: [
        Positioned(
          left: 8,
          top: 12,
          child: Transform.rotate(
            angle: -.2,
            child: const CardFace(id: 46, width: 65, height: 87),
          ),
        ),
        const Positioned(
          left: 62,
          top: 3,
          child: CardFace(id: 47, width: 65, height: 87),
        ),
        Positioned(
          left: 114,
          top: 13,
          child: Transform.rotate(
            angle: .2,
            child: const CardFace(id: 53, width: 65, height: 87),
          ),
        ),
      ],
    ),
  );
}

class CardFace extends StatelessWidget {
  const CardFace({
    super.key,
    required this.id,
    required this.width,
    required this.height,
    this.selected = false,
    this.back = false,
  });
  final int id;
  final double width;
  final double height;
  final bool selected;
  final bool back;
  @override
  Widget build(BuildContext context) {
    final card = PlayingCard(id);
    final red = card.isRed ? const Color(0xFFB9433E) : const Color(0xFF223C39);
    final small = height < 70;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: back ? const Color(0xFFCCB581) : cream,
        borderRadius: BorderRadius.circular(small ? 5 : 8),
        border: Border.all(
          color: selected ? gold : const Color(0xFFD9D8C7),
          width: selected ? 2.5 : .7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .2),
            blurRadius: 5,
            offset: const Offset(1, 3),
          ),
        ],
      ),
      child: back
          ? Center(
              child: Icon(
                Icons.style_rounded,
                size: height * .38,
                color: const Color(0xFF355E49),
              ),
            )
          : Stack(
              children: [
                Positioned(
                  top: small ? 2 : 4,
                  left: small ? 3 : 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.label,
                        style: TextStyle(
                          fontFamily: 'NotoSansSC',
                          color: red,
                          fontWeight: FontWeight.w800,
                          fontSize: card.rank >= 16
                              ? (small ? 9 : 13)
                              : (small ? 14 : 23),
                          height: 1.05,
                        ),
                      ),
                      Text(
                        card.suit,
                        style: TextStyle(
                          color: red,
                          fontSize: small ? 12 : 18,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!small)
                  Positioned(
                    bottom: 8,
                    right: 7,
                    child: Text(
                      card.suit,
                      style: TextStyle(
                        color: red.withValues(alpha: .8),
                        fontSize: height * .32,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class HandCards extends StatelessWidget {
  const HandCards({
    super.key,
    required this.cards,
    required this.selected,
    required this.onSelect,
    this.enabled = true,
  });
  final List<int> cards;
  final Set<int> selected;
  final ValueChanged<int> onSelect;
  final bool enabled;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final height = math.min(110.0, box.maxHeight - 15);
      final width = height * .64;
      final step = cards.length < 2
          ? 0.0
          : math.min(44.0, (box.maxWidth - width) / (cards.length - 1));
      final total = step * (cards.length - 1) + width;
      final left = (box.maxWidth - total) / 2;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < cards.length; i++)
            AnimatedPositioned(
              key: ValueKey(cards[i]),
              duration: const Duration(milliseconds: 110),
              left: left + i * step,
              top: selected.contains(cards[i]) ? 0 : 14,
              child: Semantics(
                button: true,
                selected: selected.contains(cards[i]),
                label:
                    '${PlayingCard(cards[i]).suit}${PlayingCard(cards[i]).label}',
                child: GestureDetector(
                  onTap: enabled ? () => onSelect(cards[i]) : null,
                  child: CardFace(
                    id: cards[i],
                    width: width,
                    height: height,
                    selected: selected.contains(cards[i]),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class TableScreen extends StatelessWidget {
  const TableScreen({
    super.key,
    required this.state,
    required this.connected,
    required this.fatalError,
    required this.secondsLeft,
    required this.busy,
    required this.selected,
    required this.onSelect,
    required this.onAction,
    required this.onHint,
    required this.onClear,
    required this.onExit,
    required this.onHome,
    required this.onConnection,
  });
  final Map<String, dynamic> state;
  final bool connected;
  final String? fatalError;
  final int secondsLeft;
  final bool busy;
  final Set<int> selected;
  final ValueChanged<int> onSelect;
  final void Function(String, [Map<String, Object?>]) onAction;
  final VoidCallback onHint, onClear, onExit, onHome, onConnection;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxHeight < 370;
      final players = (state['players'] as List).cast<Map<String, dynamic>>();
      final me = players.firstWhere((p) => p['id'] == state['myId']);
      final others = players.where((p) => p['id'] != state['myId']).toList();
      final phase = state['phase'];
      final active = phase == 'bidding' || phase == 'playing';
      final paused = state['paused'] == true || !connected;
      final canAct =
          connected && !paused && !busy && state['turn'] == state['myId'];
      final hand = (state['hand'] as List).cast<int>();
      final combo = classify(selected.toList());
      final previous = (state['lastCards'] as List?)?.cast<int>();
      final valid =
          combo != null &&
          combo.beats(previous == null ? null : classify(previous));
      return Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, compact ? 8 : 14, 20, 8),
            child: Column(
              children: [
                SizedBox(
                  height: compact ? 33 : 40,
                  child: Row(
                    children: [
                      const Icon(Icons.style_rounded, size: 22, color: gold),
                      const SizedBox(width: 7),
                      const Text(
                        '同桌',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '牌桌 ${(state['roomId'] as String).toUpperCase()}',
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                      const Spacer(),
                      if (active || phase == 'finished') ...[
                        Pill(
                          '底分 ${state['highBid']}  ·  ×${state['multiplier']}',
                          color: gold,
                        ),
                        const SizedBox(width: 12),
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: CardFace(
                              id: (state['bottom'] as List).isEmpty
                                  ? 0
                                  : (state['bottom'] as List)[i] as int,
                              back: (state['bottom'] as List).isEmpty,
                              width: 23,
                              height: 31,
                            ),
                          ),
                        const SizedBox(width: 10),
                      ],
                      TextButton.icon(
                        onPressed: onConnection,
                        icon: const Icon(Icons.wifi_rounded, size: 15),
                        label: const Text('连接', style: TextStyle(fontSize: 11)),
                      ),
                      IconButton(
                        onPressed: onExit,
                        tooltip: '离开牌桌',
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 19,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 5,
                        child: PlayerPanel(
                          player: others.isEmpty ? null : others[0],
                          state: state,
                          compact: compact,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 5,
                        child: PlayerPanel(
                          player: others.length < 2 ? null : others[1],
                          state: state,
                          compact: compact,
                        ),
                      ),
                      Positioned.fill(
                        left: compact ? 116 : 145,
                        right: compact ? 116 : 145,
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (phase == 'waiting') ...[
                                  const Icon(
                                    Icons.groups_outlined,
                                    color: gold,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '牌桌已备好，等朋友入座',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${players.length} / 3 位牌友 · 三人准备后自动开局',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ] else if (phase == 'finished' ||
                                    phase == 'aborted') ...[
                                  Text(
                                    state['message'] as String,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: gold,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (state['result'] != null)
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 18,
                                      runSpacing: 4,
                                      children: players.map((p) {
                                        final delta =
                                            (state['result']['deltas'][p['id']]
                                                as num?) ??
                                            0;
                                        return Text(
                                          '${p['name']}  ${delta >= 0 ? '+' : ''}$delta',
                                          style: TextStyle(
                                            color: delta >= 0 ? gold : muted,
                                            fontSize: 12,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    '准备好，再来一局。',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ] else if (phase == 'bidding') ...[
                                  const Text(
                                    '叫地主',
                                    style: TextStyle(
                                      color: gold,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    state['turn'] == me['id']
                                        ? '轮到你叫分了'
                                        : '等待 ${players.firstWhere((p) => p['id'] == state['turn'])['name']} 叫分',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ] else ...[
                                  if (previous != null) ...[
                                    Text(
                                      '${players.firstWhere((p) => p['id'] == state['lastPlayerId'], orElse: () => me)['name']}  ·  ${classify(previous)!.kind.label}',
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PlayedCards(cards: previous),
                                  ] else ...[
                                    Text(
                                      state['turn'] == me['id']
                                          ? '轮到你出牌'
                                          : '等待出牌',
                                      style: const TextStyle(
                                        color: gold,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      '先出一手好牌',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 7),
                                  Text(
                                    state['message'] as String,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: compact ? 42 : 49,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!active) ...[
                        Text(
                          '${me['name']} · 积分 ${me['score']}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                        const SizedBox(width: 18),
                        FilledButton.icon(
                          onPressed: busy || !connected
                              ? null
                              : () => onAction('ready', {
                                  'ready': me['ready'] != true,
                                }),
                          icon: Icon(
                            me['ready'] == true
                                ? Icons.check_rounded
                                : Icons.sports_esports_rounded,
                            size: 17,
                          ),
                          label: Text(
                            me['ready'] == true
                                ? '已准备 · 取消'
                                : phase == 'waiting'
                                ? '准备'
                                : '准备下一局',
                          ),
                        ),
                      ] else if (phase == 'bidding') ...[
                        OutlinedButton(
                          onPressed: canAct
                              ? () => onAction('bid', {'score': 0})
                              : null,
                          child: const Text('不叫'),
                        ),
                        for (var score = 1; score <= 3; score++) ...[
                          const SizedBox(width: 9),
                          FilledButton(
                            onPressed:
                                canAct && score > (state['highBid'] as int)
                                ? () => onAction('bid', {'score': score})
                                : null,
                            child: Text('$score 分'),
                          ),
                        ],
                      ] else ...[
                        if (canAct) ...[
                          OutlinedButton(
                            onPressed: previous == null
                                ? null
                                : () => onAction('pass'),
                            child: const Text('不出'),
                          ),
                          const SizedBox(width: 9),
                          OutlinedButton(
                            onPressed: onHint,
                            child: const Text('提示'),
                          ),
                          const SizedBox(width: 9),
                          TextButton(
                            onPressed: selected.isEmpty ? null : onClear,
                            child: const Text('重选'),
                          ),
                          const SizedBox(width: 9),
                          FilledButton(
                            onPressed: valid
                                ? () => onAction('play', {
                                    'cards': selected.toList(),
                                  })
                                : null,
                            child: Text(
                              combo == null ? '出牌' : '出牌 · ${combo.kind.label}',
                            ),
                          ),
                        ] else
                          Text(
                            paused ? '等待连接恢复' : '等待其他玩家出牌',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                      ],
                    ],
                  ),
                ),
                if (hand.isNotEmpty && active)
                  SizedBox(
                    height: compact ? 100 : 125,
                    child: HandCards(
                      cards: hand,
                      selected: selected,
                      onSelect: onSelect,
                      enabled: connected && !paused && !busy,
                    ),
                  ),
                if (active)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Text(
                          '${me['name']}  ·  ${state['landlord'] == me['id']
                              ? '地主'
                              : state['landlord'] == null
                              ? '等待叫分'
                              : '农民'}',
                          style: const TextStyle(color: gold, fontSize: 10),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '积分 ${me['score']}',
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                        const Spacer(),
                        Text(
                          '${hand.length} 张手牌',
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (fatalError != null || paused)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xD908241E),
                child: Center(
                  child: Container(
                    width: 420,
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: gold.withValues(alpha: .3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          fatalError == null
                              ? Icons.wifi_find_rounded
                              : Icons.meeting_room_outlined,
                          color: gold,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fatalError ?? (connected ? '牌局暂停，等朋友回来' : '正在重新连接牌桌'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          fatalError == null
                              ? '座位与手牌已保留 · 剩余 $secondsLeft 秒\n请保持同一 Wi-Fi，回到 App 后将自动重连。'
                              : '你可以回到首页创建或加入新的牌桌。',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        fatalError != null
                            ? FilledButton(
                                onPressed: onHome,
                                child: const Text('返回首页'),
                              )
                            : OutlinedButton(
                                onPressed: onExit,
                                child: const Text('离开牌桌'),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    super.key,
    required this.player,
    required this.state,
    required this.compact,
  });
  final Map<String, dynamic>? player;
  final Map<String, dynamic> state;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final p = player;
    final current =
        p != null &&
        state['turn'] == p['id'] &&
        ['playing', 'bidding'].contains(state['phase']);
    final landlord = p != null && state['landlord'] == p['id'];
    final move = p == null ? null : (state['moves'] as Map)[p['id']];
    return SizedBox(
      width: compact ? 108 : 132,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 9 : 12),
            decoration: BoxDecoration(
              color: panel.withValues(alpha: .75),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: current ? gold : Colors.white.withValues(alpha: .1),
                width: current ? 1.5 : .7,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      p == null
                          ? Icons.person_add_alt_1_outlined
                          : landlord
                          ? Icons.workspace_premium_rounded
                          : Icons.person_rounded,
                      color: landlord ? gold : muted,
                      size: 20,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        p?['name'] as String? ?? '等待入座',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p == null ? muted : cream,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (p != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        landlord
                            ? '地主'
                            : state['landlord'] != null
                            ? '农民'
                            : p['host'] == true
                            ? '房主'
                            : '牌友',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                      if (['playing', 'bidding'].contains(state['phase']))
                        Row(
                          children: [
                            const Icon(
                              Icons.style_rounded,
                              color: gold,
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${p['remaining']}',
                              style: const TextStyle(
                                color: gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          p['connected'] != true
                              ? '离线'
                              : p['ready'] == true
                              ? '已准备'
                              : '未准备',
                          style: TextStyle(
                            color: p['ready'] == true ? gold : muted,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  )
                else
                  const Text(
                    '邀请一位朋友',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                if (p != null && !compact)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '积分 ${p['score']}',
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          if (move != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                move['label'] as String,
                style: const TextStyle(color: gold, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class PlayedCards extends StatelessWidget {
  const PlayedCards({super.key, required this.cards});
  final List<int> cards;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final maxWidth = math.min(box.maxWidth, 300.0);
      final step = cards.length < 2
          ? 0.0
          : math.min(30.0, (maxWidth - 37) / (cards.length - 1));
      final width = step * (cards.length - 1) + 37;
      return SizedBox(
        width: width,
        height: 53,
        child: Stack(
          children: [
            for (var i = 0; i < cards.length; i++)
              Positioned(
                left: i * step,
                child: CardFace(id: cards[i], width: 37, height: 51),
              ),
          ],
        ),
      );
    },
  );
}
