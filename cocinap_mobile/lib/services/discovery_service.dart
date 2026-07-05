import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

class DiscoveryService {
  final MDnsClient _client = MDnsClient();
  String? _foundIp;
  int? _foundPort;

  Future<String?> discover({Duration timeout = const Duration(seconds: 5)}) async {
    _foundIp = null;
    _foundPort = null;

    try {
      await _client.start();

      final stream = _client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer("_cocinap._tcp.local."),
      );

      await for (final p in stream) {
        final srv = await _client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(p.domainName),
        ).first;

        final ip = await _client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        ).first;

        _foundIp = ip.address.address;
        _foundPort = srv.port;
        break;
      }
    } catch (_) {
    } finally {
      _client.stop();
    }

    if (_foundIp != null && _foundPort != null) {
      return "http://$_foundIp:$_foundPort";
    }
    return null;
  }

  void dispose() {
    _client.stop();
  }
}
