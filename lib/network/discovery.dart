import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'room_client.dart';

const roomServiceType = '_doudizhu._tcp';

class NearbyRoom {
  const NearbyRoom(this.name, this.address, this.port);
  final String name;
  final String address;
  final int port;
  Uri get uri => Uri(scheme: 'ws', host: address, port: port, path: '/play');
}

class RoomDiscovery extends ChangeNotifier {
  nsd.Discovery? _discovery;
  nsd.Registration? _registration;
  bool scanning = false;
  bool _disposed = false;
  String? error;
  List<NearbyRoom> rooms = [];

  Future<void> scan() async {
    if (scanning || _disposed) return;
    scanning = true;
    error = null;
    notifyListeners();
    try {
      final old = _discovery;
      _discovery = null;
      if (old != null) {
        old.removeListener(_update);
        await nsd.stopDiscovery(old);
      }
      final discovery = await nsd.startDiscovery(
        roomServiceType,
        ipLookupType: nsd.IpLookupType.v4,
      );
      if (_disposed) {
        await nsd.stopDiscovery(discovery);
        return;
      }
      _discovery = discovery;
      discovery.addListener(_update);
      _update();
    } catch (_) {
      error = '自动发现暂不可用。请允许本地网络访问，或输入房主的 IP 和端口。';
    } finally {
      scanning = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _update() {
    if (_disposed) return;
    rooms = (_discovery?.services ?? [])
        .where((s) => s.port != null && s.addresses?.isNotEmpty == true)
        .expand((service) {
          final addresses = service.addresses!.where(
            (address) => isLanAddress(address.address),
          );
          final text = service.txt?['name'];
          final name = text == null
              ? (service.name ?? '附近牌桌')
              : utf8.decode(text, allowMalformed: true);
          return addresses
              .take(1)
              .map((a) => NearbyRoom(name, a.address, service.port!));
        })
        .toList();
    notifyListeners();
  }

  Future<void> advertise(String roomId, String name, int port) async {
    await stopAdvertising();
    _registration = await nsd.register(
      nsd.Service(
        name: 'DDZ-$roomId',
        type: roomServiceType,
        port: port,
        txt: {
          'name': Uint8List.fromList(utf8.encode('$name 的牌桌')),
          'v': Uint8List.fromList(utf8.encode('1')),
        },
      ),
    );
  }

  Future<void> stopAdvertising() async {
    final old = _registration;
    _registration = null;
    if (old != null) {
      try {
        await nsd.unregister(old);
      } catch (_) {
        /* service is already gone */
      }
    }
  }

  Future<void> shutdown() async {
    _disposed = true;
    await stopAdvertising();
    final old = _discovery;
    _discovery = null;
    if (old != null) {
      old.removeListener(_update);
      try {
        await nsd.stopDiscovery(old);
      } catch (_) {
        /* platform already stopped */
      }
    }
  }
}

Future<List<String>> localAddresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: true,
  );
  final addresses = interfaces
      .expand((i) => i.addresses)
      .map((a) => a.address)
      .where(isLanAddress)
      .toSet()
      .toList();
  addresses.sort(
    (a, b) => (a.startsWith('192.168.') ? 0 : 1).compareTo(
      b.startsWith('192.168.') ? 0 : 1,
    ),
  );
  return addresses;
}
