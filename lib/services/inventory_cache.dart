import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class InventorySnapshot {
  final DateTime syncedAt;
  final List<InventoryItem> items;
  final List<String> salesWarehouses;

  InventorySnapshot({
    required this.syncedAt,
    required this.items,
    this.salesWarehouses = const [],
  });

  bool get isEmpty => items.isEmpty;
}

class InventoryCache {
  static const _fileName = 'inventory_cache.json';
  static const _schemaVersion = 5;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<InventorySnapshot?> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      if (raw.isEmpty) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['schemaVersion'] != _schemaVersion) return null;
      final syncedAt =
          DateTime.tryParse(j['syncedAt']?.toString() ?? '') ?? DateTime.now();
      final items =
          (j['items'] as List<dynamic>?)
              ?.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <InventoryItem>[];
      final salesWarehouses =
          (j['salesWarehouses'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      return InventorySnapshot(
        syncedAt: syncedAt,
        items: items,
        salesWarehouses: salesWarehouses,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(InventorySnapshot snap) async {
    final f = await _file();
    final payload = jsonEncode({
      'schemaVersion': _schemaVersion,
      'syncedAt': snap.syncedAt.toIso8601String(),
      'salesWarehouses': snap.salesWarehouses,
      'items': snap.items.map((e) => e.toJson()).toList(),
    });
    await f.writeAsString(payload, flush: true);
  }

  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}
