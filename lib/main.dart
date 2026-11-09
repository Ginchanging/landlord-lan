import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/game.dart';
import 'core/rules.dart';
import 'network/discovery.dart';
import 'network/room_client.dart';
import 'network/room_host.dart';
import 'ui/screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const DoudizhuApp());
}

class DoudizhuApp extends StatelessWidget {
  const DoudizhuApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: Platform.isWindows ? 'Landlord LAN' : '局域网斗地主',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: tableTheme(),
    home: const GameApp(),
  );
}

class GameApp extends StatefulWidget {
  const GameApp({super.key});
  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> with WidgetsBindingObserver {
  final _name = TextEditingController(text: '牌友');
  final _address = TextEditingController();
  final _discovery = RoomDiscovery();
  RoomHost? _host;
  RoomClient? _client;
  List<String> _addresses = [];
  final Set<int> _selected = {};
  bool _busy = false;
  int _hint = 0;
  int? _lastRevision;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _discovery.addListener(_update);
    unawaited(_discovery.scan());
  }

  void _update() {
    if (mounted) setState(() {});
  }

  void _receive() {
    final state = _client?.state;
    if (state != null && state['revision'] != _lastRevision) {
      _selected.removeWhere((id) => !(state['hand'] as List).contains(id));
      if (state['turn'] != _client?.playerId) _selected.clear();
      _lastRevision = state['revision'] as int;
      _hint = 0;
    }
    _update();
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  String _error(Object error) =>
      error is GameException ? error.message : '连接失败，请检查 Wi-Fi、本地网络权限和房间地址';

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    RoomHost? host;
    try {
      host = await RoomHost.start(_name.text);
      _addresses = await localAddresses();
      final client = await RoomClient.connect(
        Uri(scheme: 'ws', host: '127.0.0.1', port: host.port, path: '/play'),
        _name.text,
        token: host.hostToken,
      );
      if (!mounted) {
        await client.leave();
        client.dispose();
        await host.close();
        return;
      }
      _host = host;
      _client = client..addListener(_receive);
      setState(() {});
      try {
        await _discovery.advertise(
          host.game.roomId,
          _name.text.trim(),
          host.port,
        );
      } catch (_) {
        _notice('自动广播暂不可用，请点右上角「连接」分享 IP 地址');
      }
    } catch (error) {
      await host?.close();
      _notice(_error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join([NearbyRoom? room]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final uri =
          room?.uri ?? Uri.tryParse('ws://${_address.text.trim()}/play');
      if (uri == null || !uri.hasPort || uri.userInfo.isNotEmpty) {
        throw const GameException('请输入房主显示的 IP:端口');
      }
      final client = await RoomClient.connect(uri, _name.text);
      if (!mounted) {
        await client.leave();
        client.dispose();
        return;
      }
      _host = null;
      _client = client..addListener(_receive);
      _addresses = [];
    } catch (error) {
      _notice(_error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(
    String action, [
    Map<String, Object?> data = const {},
  ]) async {
    if (_busy || _client == null) return;
    setState(() => _busy = true);
    try {
      await _client!.action(action, data);
      if (action == 'play') _selected.clear();
    } catch (error) {
      _notice(_error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _suggest() {
    final state = _client?.state;
    if (state == null || !_client!.canAct) return;
    final hand = (state['hand'] as List).cast<int>();
    final last = (state['lastCards'] as List?)?.cast<int>();
    final suggestions = suggestPlays(
      hand,
      last == null ? null : classify(last),
    );
    if (suggestions.isEmpty) {
      _notice('没有可以压过的牌，可以选择「不出」');
      return;
    }
    setState(() {
      _selected
        ..clear()
        ..addAll(suggestions[_hint % suggestions.length]);
      _hint++;
    });
  }

  Future<void> _exit({bool confirm = true}) async {
    if (confirm && _client?.state != null) {
      final active = ['playing', 'bidding'].contains(_client!.state!['phase']);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('离开牌桌？'),
          content: Text(
            _host != null
                ? '你是房主，离开会关闭房间。${active ? '本局不计分。' : ''}'
                : active
                ? '离开会结束本局，不计分。'
                : '你可以随时加入新的房间。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续玩'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('离开'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    final client = _client;
    _client = null;
    client?.removeListener(_receive);
    await client?.leave();
    client?.dispose();
    await _host?.close();
    _host = null;
    await _discovery.stopAdvertising();
    _selected.clear();
    _lastRevision = null;
    _busy = false;
    _update();
  }

  Future<void> _showConnection() async {
    final host = _host;
    if (host != null) _addresses = await localAddresses();
    if (!mounted) return;
    final entries = host != null
        ? _addresses.map((ip) => '$ip:${host.port}').toList()
        : ['${_client!.uri.host}:${_client!.uri.port}'];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('邀请朋友入座'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('三部手机连接同一个 Wi-Fi 或热点，在首页搜索牌桌，也可以手动输入下方地址。'),
                const SizedBox(height: 16),
                if (entries.isEmpty) const Text('未找到局域网地址，请检查 Wi-Fi 或热点连接。'),
                for (final address in entries)
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          address,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '复制地址',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: address));
                          _notice('地址已复制');
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  Platform.isWindows
                      ? '若连接失败：请在 Windows 防火墙中允许 Landlord LAN 访问专用网络，并检查路由器的访客隔离。'
                      : '若搜索不到：允许 App 访问本地网络，并检查路由器是否开启了访客隔离。',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _host?.suspend();
      _client?.suspend();
    } else if (state == AppLifecycleState.resumed) {
      _host?.resume();
      _client?.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _discovery.removeListener(_update);
    unawaited(_discovery.shutdown().then((_) => _discovery.dispose()));
    _client?.removeListener(_receive);
    _client?.dispose();
    unawaited(_host?.close());
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    return PopScope(
      canPop: client == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && client != null) unawaited(_exit());
      },
      child: Scaffold(
        body: TableBackground(
          child: SafeArea(
            child: client?.state == null
                ? HomeScreen(
                    name: _name,
                    address: _address,
                    discovery: _discovery,
                    busy: _busy,
                    onCreate: _create,
                    onJoin: _join,
                  )
                : TableScreen(
                    state: client!.state!,
                    connected: client.connected,
                    fatalError: client.terminalError,
                    secondsLeft: client.secondsLeft,
                    busy: _busy,
                    selected: _selected,
                    onSelect: (id) => setState(() {
                      if (!_selected.add(id)) _selected.remove(id);
                    }),
                    onAction: _action,
                    onHint: _suggest,
                    onClear: () => setState(_selected.clear),
                    onExit: () => _exit(),
                    onHome: () => _exit(confirm: false),
                    onConnection: _showConnection,
                  ),
          ),
        ),
      ),
    );
  }
}
