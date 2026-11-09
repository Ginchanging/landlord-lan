import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/cards.dart';
import '../core/game.dart';

bool isLanAddress(String host) {
  final address = InternetAddress.tryParse(host);
  if (address == null) return false;
  if (address.isLoopback || address.isLinkLocal) return true;
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }
  return bytes[0] & 0xfe == 0xfc;
}

class RoomClient extends ChangeNotifier {
  RoomClient._(this.uri, this.name, this.token);
  static Future<RoomClient> connect(
    Uri uri,
    String name, {
    String? token,
  }) async {
    if (!isLanAddress(uri.host) ||
        uri.scheme != 'ws' ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const GameException('请输入局域网 IP 和端口，例如 192.168.1.8:39001');
    }
    RoomHostName.validate(name);
    final client = RoomClient._(uri, name, token);
    try {
      await client._connect();
      client._timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => client._tick(),
      );
      return client;
    } catch (_) {
      await client.leave();
      client.dispose();
      rethrow;
    }
  }

  final Uri uri;
  final String name;
  String? token;
  String? playerId;
  Map<String, dynamic>? state;
  bool connected = false;
  bool _connecting = false;
  bool _stopped = false;
  bool _disposed = false;
  bool _suspended = false;
  String? terminalError;
  DateTime? _localDeadline;
  DateTime? _stateDeadline;
  DateTime _lastSeen = DateTime.now();
  WebSocket? _socket;
  Timer? _timer;
  int _sequence = 0;
  final String _prefix = secureId(6);
  final Map<String, Completer<void>> _pending = {};
  // Use relative server time so different device clocks/time zones cannot
  // prematurely expire a reconnect window.
  DateTime? get deadline => _stateDeadline ?? _localDeadline;
  int get secondsLeft =>
      ((deadline?.difference(DateTime.now()).inMilliseconds ?? 0) / 1000)
          .ceil()
          .clamp(0, 60);
  bool get canAct =>
      connected &&
      terminalError == null &&
      state?['paused'] != true &&
      state?['turn'] == playerId;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _connect() async {
    if (_connecting || _stopped) return;
    _connecting = true;
    final ready = Completer<void>();
    WebSocket? socket;
    final httpClient = HttpClient()..findProxy = (_) => 'DIRECT';
    try {
      // Explicit direct HttpClient: LAN sockets must not use a device's HTTP proxy.
      socket = await WebSocket.connect(
        uri.toString(),
        customClient: httpClient,
      ).timeout(const Duration(seconds: 5));
      if (_stopped || _suspended) {
        await socket.close();
        return;
      }
      _socket = socket;
      final current = socket;
      current.listen(
        (dynamic raw) {
          if (!identical(_socket, current) || _stopped) return;
          _lastSeen = DateTime.now();
          try {
            final value = jsonDecode(raw as String) as Map<String, dynamic>;
            switch (value['type']) {
              case 'welcome':
                token = value['token'] as String;
                playerId = value['playerId'] as String;
              case 'state':
                state = value['state'] as Map<String, dynamic>;
                final remaining = state!['remainingMs'];
                _stateDeadline = remaining is int
                    ? DateTime.now().add(
                        Duration(milliseconds: remaining.clamp(0, 60000)),
                      )
                    : null;
                connected = true;
                _localDeadline = null;
                if (!ready.isCompleted) ready.complete();
                _notify();
              case 'ping':
                current.add(jsonEncode({'type': 'pong'}));
              case 'ack':
                _pending.remove(value['id'])?.complete();
              case 'error':
                final error = GameException(value['message'] as String);
                final pending = _pending.remove(value['id']);
                if (pending != null && !pending.isCompleted) {
                  pending.completeError(error);
                }
                if (value['fatal'] == true) {
                  if (!ready.isCompleted) ready.completeError(error);
                  _end(error.message);
                }
              case 'closed':
                final reason = value['message'] as String;
                if (!ready.isCompleted) {
                  ready.completeError(GameException(reason));
                }
                _end(reason);
            }
          } catch (_) {
            if (!ready.isCompleted) {
              ready.completeError(const GameException('无法解析房间消息'));
            }
          }
        },
        onDone: () {
          if (!ready.isCompleted) {
            ready.completeError(const GameException('未能加入房间'));
          }
          _lost(current);
        },
        onError: (Object _) {
          if (!ready.isCompleted) {
            ready.completeError(const GameException('房间连接失败'));
          }
          _lost(current);
        },
        cancelOnError: true,
      );
      current.add(
        jsonEncode({
          'type': 'join',
          'protocol': 1,
          'name': name,
          'token': token,
        }),
      );
      await ready.future.timeout(const Duration(seconds: 6));
    } catch (error) {
      if (socket != null) unawaited(socket.close());
      rethrow;
    } finally {
      httpClient.close();
      _connecting = false;
    }
  }

  void _lost(WebSocket socket) {
    if (!identical(socket, _socket) || _stopped) return;
    _socket = null;
    connected = false;
    _localDeadline ??= DateTime.now().add(const Duration(seconds: 60));
    _failPending('连接中断，请重连后查看牌局状态');
    _notify();
  }

  void _failPending(String reason) {
    final values = _pending.values.toList();
    _pending.clear();
    for (final p in values) {
      if (!p.isCompleted) p.completeError(GameException(reason));
    }
  }

  void _end(String reason) {
    _stopped = true;
    connected = false;
    terminalError = reason;
    _timer?.cancel();
    _failPending(reason);
    unawaited(_socket?.close());
    _notify();
  }

  void _tick() {
    if (_stopped) return;
    if (!connected && deadline != null && !DateTime.now().isBefore(deadline!)) {
      _end('重连等待超时，本局结束，不计分');
      return;
    }
    if (connected &&
        DateTime.now().difference(_lastSeen) > const Duration(seconds: 8)) {
      final socket = _socket;
      if (socket != null) {
        _lost(socket);
        unawaited(socket.close());
      }
    }
    if (!connected && !_connecting && !_suspended) unawaited(_retry());
    if (deadline != null) _notify();
  }

  Future<void> _retry() async {
    try {
      await _connect();
    } catch (_) {
      /* Retry until the original deadline. */
    }
  }

  Future<void> action(
    String action, [
    Map<String, Object?> data = const {},
  ]) async {
    if (!connected || _socket == null || _stopped) {
      throw const GameException('正在重连，请稍候');
    }
    final id = '$_prefix-${_sequence++}';
    final completion = Completer<void>();
    _pending[id] = completion;
    _socket!.add(
      jsonEncode({
        'type': 'action',
        'id': id,
        'revision': state!['revision'],
        'action': action,
        'data': data,
      }),
    );
    try {
      await completion.future.timeout(const Duration(seconds: 6));
    } on TimeoutException {
      throw const GameException('未收到操作确认，请查看最新牌局状态');
    } finally {
      _pending.remove(id);
    }
  }

  void suspend() {
    _suspended = true;
    final socket = _socket;
    if (socket != null) {
      if (socket.readyState == WebSocket.open) {
        socket.add(jsonEncode({'type': 'suspend'}));
      }
      _lost(socket);
      unawaited(socket.close());
    }
  }

  void resume() {
    _suspended = false;
    _tick();
  }

  Future<void> leave() async {
    _stopped = true;
    _timer?.cancel();
    final socket = _socket;
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(jsonEncode({'type': 'leave'}));
      await socket.close();
    }
    _socket = null;
    connected = false;
    _failPending('你已离开房间');
  }

  @override
  void dispose() {
    _disposed = true;
    _stopped = true;
    _timer?.cancel();
    unawaited(_socket?.close());
    super.dispose();
  }
}

class RoomHostName {
  static void validate(String name) {
    if (name.trim().isEmpty ||
        name.trim().runes.length > 12 ||
        name.runes.any((r) => r < 32)) {
      throw const GameException('昵称需要 1～12 个字符');
    }
  }
}
