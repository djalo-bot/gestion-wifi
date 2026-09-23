import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/pack.dart';
import '../models/report.dart';
import '../models/ticket.dart';

class TicketRepository {
  TicketRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<List<Pack>> getPacksWithStock() async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery('''
      SELECT p.id, p.name, p.price, p.duration,
             COUNT(CASE WHEN t.status = 'AVAILABLE' THEN t.id END)
               AS available_stock
      FROM packs p
      LEFT JOIN tickets t ON t.pack_id = p.id
      GROUP BY p.id, p.name, p.price, p.duration
      ORDER BY p.price
    ''');
    return rows.map(Pack.fromMap).toList();
  }

  Future<Ticket?> sellNextTicket(int packId) async {
    final database = await _databaseHelper.database;
    return database.transaction((transaction) async {
      final available = await transaction.query(
        'tickets',
        where: 'pack_id = ? AND status = ?',
        whereArgs: [packId, 'AVAILABLE'],
        orderBy: 'id ASC',
        limit: 1,
      );
      if (available.isEmpty) return null;

      final source = available.first;
      final ticketId = source['id'] as int;
      final packRows = await transaction.query(
        'packs',
        columns: ['price'],
        where: 'id = ?',
        whereArgs: [packId],
        limit: 1,
      );
      if (packRows.isEmpty) return null;

      final soldAt = DatabaseHelper.localTimestamp();
      final soldPrice = packRows.first['price'] as int;
      final updatedRows = await transaction.update(
        'tickets',
        {'status': 'SOLD', 'sold_at': soldAt, 'sold_price': soldPrice},
        where: "id = ? AND status = 'AVAILABLE'",
        whereArgs: [ticketId],
      );
      if (updatedRows != 1) return null;

      return Ticket.fromMap({
        ...source,
        'status': 'SOLD',
        'sold_at': soldAt,
        'sold_price': soldPrice,
      });
    });
  }

  Future<bool> cancelSale(int ticketId) async {
    final database = await _databaseHelper.database;
    final updatedRows = await database.update(
      'tickets',
      {'status': 'CANCELLED'},
      where: "id = ? AND status = 'SOLD'",
      whereArgs: [ticketId],
    );
    return updatedRows == 1;
  }

  Future<Map<String, int>> insertCodes(int packId, List<String> codes) async {
    final database = await _databaseHelper.database;
    var inserted = 0;
    var consideredCodes = 0;
    final createdAt = DatabaseHelper.localTimestamp();

    await database.transaction((transaction) async {
      for (final rawCode in codes) {
        final code = rawCode.trim();
        if (code.isEmpty) continue;
        consideredCodes++;
        final rowId = await transaction.rawInsert('''
          INSERT OR IGNORE INTO tickets
            (pack_id, code, status, created_at)
          VALUES (?, ?, 'AVAILABLE', ?)
        ''', [packId, code, createdAt]);
        if (rowId != 0) inserted++;
      }
    });

    return {'insérés': inserted, 'doublons': consideredCodes - inserted};
  }

  Future<List<Ticket>> getLastSales(int limit) async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery('''
      SELECT t.*, p.name AS pack_name
      FROM tickets t
      INNER JOIN packs p ON p.id = t.pack_id
      WHERE t.status = 'SOLD'
      ORDER BY t.sold_at DESC, t.id DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(Ticket.fromMap).toList();
  }

  Future<SalesReport> getReport(String from, String to) async {
    final database = await _databaseHelper.database;
    final sales = await database.rawQuery('''
      SELECT COUNT(*) AS sales_count,
             COALESCE(SUM(sold_price), 0) AS total_amount
      FROM tickets
      WHERE status = 'SOLD' AND sold_at >= ? AND sold_at <= ?
    ''', [from, to]);
    final cancelled = await database.rawQuery('''
      SELECT COUNT(*) AS cancelled_count
      FROM tickets
      WHERE status = 'CANCELLED' AND sold_at >= ? AND sold_at <= ?
    ''', [from, to]);
    final byPack = await database.rawQuery('''
      SELECT p.name AS pack_name, COUNT(*) AS quantity,
             t.sold_price AS unit_price,
             SUM(t.sold_price) AS total
      FROM tickets t
      INNER JOIN packs p ON p.id = t.pack_id
      WHERE t.status = 'SOLD' AND t.sold_at >= ? AND t.sold_at <= ?
      GROUP BY t.pack_id, p.name, t.sold_price
      ORDER BY t.sold_price
    ''', [from, to]);

    return SalesReport(
      salesCount: sales.first['sales_count'] as int,
      totalAmount: sales.first['total_amount'] as int,
      cancelledCount: cancelled.first['cancelled_count'] as int,
      byPack: byPack
          .map(
            (row) => PackSales(
              packName: row['pack_name'] as String,
              quantity: row['quantity'] as int,
              unitPrice: row['unit_price'] as int,
              total: row['total'] as int,
            ),
          )
          .toList(),
    );
  }

  Future<List<PackStock>> getStockByPack() async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery('''
      SELECT p.id AS pack_id, p.name AS pack_name, p.price,
             COUNT(CASE WHEN t.status = 'AVAILABLE' THEN t.id END)
               AS available_stock
      FROM packs p
      LEFT JOIN tickets t ON t.pack_id = p.id
      GROUP BY p.id, p.name, p.price
      ORDER BY p.price
    ''');
    return rows
        .map(
          (row) => PackStock(
            packId: row['pack_id'] as int,
            packName: row['pack_name'] as String,
            price: row['price'] as int,
            availableStock: row['available_stock'] as int,
          ),
        )
        .toList();
  }
}
