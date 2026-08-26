import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

class DiscoveryResult {
  final String url;
  final String hostname;
  const DiscoveryResult(this.url, this.hostname);
}

class DiscoveryService {
  final MDnsClient _client = MDnsClient();

  Future<List<DiscoveryResult>> discover({Duration timeout = const Duration(seconds: 4)}) async {
    final results = <DiscoveryResult>[];
    try {
      await _client.start();

      final stream = _client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer("_cocinap._tcp.local."),
      );

      await for (final p in stream.timeout(timeout)) {
        try {
          final srv = await _client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(p.domainName),
          ).first.timeout(timeout);

          final ip = await _client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          ).first.timeout(timeout);

          results.add(DiscoveryResult(
            "http://${ip.address.address}:${srv.port}",
            srv.target.replaceAll(".local.", ""),
          ));
        } catch (_) {
          // skip entries we cannot resolve
        }
        if (results.length >= 5) break;
      }
    } catch (_) {
    } finally {
      _client.stop();
    }
    return results;
  }

  void dispose() {
    _client.stop();
  }
}