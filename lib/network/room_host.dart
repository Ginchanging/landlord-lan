import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/cards.dart';
import '../core/game.dart';

/// Authoritative, entirely on-device server. Tokens are never part of a view.
class RoomHost {
  RoomHost._(this.game, this._server, this.hostId, this.hostToken, this.grace) {
    _tokens[hostToken] = hostId;
    _server.listen(_upgrade);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }
  static Future<RoomHost> start(
    String name, {
    Duration grace = const Duration(seconds: 60),
  }) async {
    validateName(name);
    final id = secureId(8);
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    return RoomHost._(
      RoomGame(hostId: id, hostName: name.trim()),
      server,
      id,
      secureId(32),
      grace,
    );
  }

  final RoomGame game;
  final HttpServer _server;
  final String hostId;
  final String hostToken;
  final Duration grace;
  final Map<String, String> _tokens = {};
  final Map<String, WebSocket> _sockets = {};
  final Map<String, DateTime> _seen = {};
  final Map<String, DateTime> _lostAt = {};
  final Map<String, Set<String>> _processed = {};
  final Set<WebSocket> _allSockets = {};
  late final Timer _timer;
  bool closed = false;
  bool _backgrounded = false;
  int get port => _server.port;

  static void validateName(String name) {
    if (name.trim().isEmpty ||
        name.trim().runes.length > 12 ||
        name.runes.any((r) => r < 32)) {
      throw const GameException('昵称需要 1～12 个字符');
    }
  }

  Future<void> _upgrade(HttpRequest request) async {
    if (request.uri.path != '/play' ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    WebSocket socket;
    try {
      socket = await WebSocketTransformer.upgrade(request);
    } catch (_) {
      return;
    }
    if (closed) {
      await socket.close();
      return;
    }
    _allSockets.add(socket);
    String? playerId;
    final handshake = Timer(const Duration(seconds: 5), () {
      if (playerId == null) unawaited(socket.close(1008, 'Join timeout'));
    });
    socket.listen(
      (dynamic raw) {
        if (closed) return;
        String? requestId;
        try {
          if (raw is! String || raw.length > 8192) {
            throw const GameException('消息格式无效或过长');
          }
          final json = jsonDecode(raw);
          if (json is! Map<String, dynamic>) {
            throw const GameException('消息格式无效');
          }
          requestId = json['id'] is String ? json['id'] as String : null;
          if (playerId == null) {
            if (json['type'] != 'join' || json['protocol'] != 1) {
              throw const GameException('版本不兼容，请安装同一版本');
            }
            game.expire(DateTime.now());
            final token = json['token'];
            String id;
            String sessionToken;
            if (token != null) {
              if (token is! String || !_tokens.containsKey(token)) {
                throw const GameException('座位已失效，请重新加入');
              }
              id = _tokens[token]!;
              sessionToken = token;
              if (id == hostId && _backgrounded) {
                throw const GameException('房主正在后台');
              }
            } else {
              final name = json['name'];
              if (name is! String) throw const GameException('请填写昵称');
              validateName(name);
              id = secureId(8);
              sessionToken = secureId(32);
              game.addPlayer(id, name.trim());
              _tokens[sessionToken] = id;
            }
            final previous = _sockets[id];
            playerId = id;
            _sockets[id] = socket;
            if (previous != null) {
              unawaited(previous.close(1000, 'Reconnected'));
            }
            _seen[id] = DateTime.now();
            _lostAt.remove(id);
            game.setConnected(id, true, DateTime.now(), grace);
            handshake.cancel();
            _send(socket, {
              'type': 'welcome',
              'playerId': id,
              'token': sessionToken,
              'protocol': 1,
            });
            _publish();
            return;
          }
          final id = playerId!;
          if (!identical(_sockets[id], socket)) return;
          _seen[id] = DateTime.now();
          switch (json['type']) {
            case 'pong':
              return;
            case 'suspend':
              _detach(id, socket);
              unawaited(socket.close());
              return;
            case 'leave':
              if (id == hostId) {
                unawaited(close());
              } else {
                _sockets.remove(id);
                _lostAt.remove(id);
                _tokens.removeWhere((_, v) => v == id);
                _processed.remove(id);
                game.removePlayer(id);
                unawaited(socket.close());
                _publish();
              }
              return;
            case 'action':
              if (requestId == null ||
                  requestId.length > 80 ||
                  json['action'] is! String ||
                  json['data'] is! Map<String, dynamic>) {
                throw const GameException('操作格式无效');
              }
              game.expire(DateTime.now());
              final history = _processed.putIfAbsent(id, () => <String>{});
              if (!history.contains(requestId)) {
                if (json['revision'] != game.revision) {
                  throw const GameException('牌局已更新，请查看最新状态后重试');
                }
                game.apply(
                  id,
                  json['action'] as String,
                  json['data'] as Map<String, dynamic>,
                );
                history.add(requestId);
                if (history.length > 256) history.remove(history.first);
              }
              _publish();
              _send(socket, {'type': 'ack', 'id': requestId});
            default:
              throw const GameException('未知消息');
          }
        } on GameException catch (error) {
          _send(socket, {
            'type': 'error',
            'id': requestId,
            'message': error.message,
            'fatal': playerId == null,
          });
          if (playerId == null) {
            unawaited(socket.close(1008, 'Join rejected'));
          } else {
            _publish();
          }
        } catch (_) {
          _send(socket, {
            'type': 'error',
            'id': requestId,
            'message': '消息格式无效',
            'fatal': playerId == null,
          });
          if (playerId == null) {
            unawaited(socket.close(1008, 'Invalid message'));
          }
        }
      },
      onDone: () {
        handshake.cancel();
        _allSockets.remove(socket);
        if (playerId != null) _detach(playerId!, socket);
      },
      onError: (Object _) {
        if (playerId != null) _detach(playerId!, socket);
      },
      cancelOnError: true,
    );
  }

  void _detach(String id, WebSocket socket) {
    if (closed || !identical(_sockets[id], socket)) return;
    _sockets.remove(id);
    _seen.remove(id);
    _lostAt.putIfAbsent(id, DateTime.now);
    game.setConnected(id, false, DateTime.now(), grace);
    _publish();
  }

  void _tick() {
    if (closed) return;
    final now = DateTime.now();
    final oldRevision = game.revision;
    game.expire(now);
    for (final entry in _sockets.entries.toList()) {
      if (now.difference(_seen[entry.key] ?? now) >
          const Duration(seconds: 8)) {
        _detach(entry.key, entry.value);
        unawaited(entry.value.close());
      } else {
        _send(entry.value, {'type': 'ping'});
      }
    }
    for (final entry in _lostAt.entries.toList()) {
      if (now.difference(entry.value) < grace) continue;
      if (entry.key == hostId) {
        unawaited(close(reason: '房主离线超时，房间已关闭'));
        return;
      }
      if (game.active) game.abort('重连等待超时，本局结束，不计分');
      game.removePlayer(entry.key);
      _lostAt.remove(entry.key);
      _tokens.removeWhere((_, id) => id == entry.key);
      _processed.remove(entry.key);
    }
    if (game.revision != oldRevision) _publish();
  }

  void suspend() {
    if (closed) return;
    _backgrounded = true;
    final socket = _sockets[hostId];
    if (socket != null) {
      _detach(hostId, socket);
      unawaited(socket.close());
    }
  }

  void resume() {
    if (closed) return;
    _backgrounded = false;
    _tick(); // Enforces deadlines even if the OS suspended all Dart timers.
  }

  void _send(WebSocket socket, Map<String, Object?> value) {
    if (socket.readyState != WebSocket.open) return;
    try {
      socket.add(jsonEncode(value));
    } catch (_) {
      /* onDone handles loss */
    }
  }

  void _publish() {
    for (final entry in _sockets.entries) {
      _send(entry.value, {'type': 'state', 'state': game.viewFor(entry.key)});
    }
  }

  Future<void> close({String reason = '房主已退出，房间已关闭'}) async {
    if (closed) return;
    closed = true;
    _timer.cancel();
    for (final socket in _allSockets.toList()) {
      _send(socket, {'type': 'closed', 'message': reason});
      unawaited(socket.close(1000, 'Room closed'));
    }
    _sockets.clear();
    await _server.close(force: true);
  }
}
