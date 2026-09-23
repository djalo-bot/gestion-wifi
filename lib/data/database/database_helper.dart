import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static const _databaseName = 'gestion_wifi.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<String> get databasePath async {
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, _databaseName);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> get database async {
    final existingDatabase = _database;
    if (existingDatabase != null) return existingDatabase;

    final databasePath = await this.databasePath;
    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
    return _database!;
  }

  Future<void> _onCreate(Database database, int version) async {
    await database.execute('''
      CREATE TABLE packs (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        price INTEGER NOT NULL UNIQUE,
        duration TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE tickets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pack_id INTEGER NOT NULL REFERENCES packs(id),
        code TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'AVAILABLE'
          CHECK (status IN ('AVAILABLE', 'SOLD', 'CANCELLED')),
        created_at TEXT NOT NULL,
        sold_at TEXT NULL,
        sold_price INTEGER NULL
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_tickets_pack_status ON tickets(pack_id, status)',
    );
    await database.execute('CREATE INDEX idx_tickets_sold_at ON tickets(sold_at)');

    final seedPacks = [
      {'name': 'Pass 100F', 'price': 100, 'duration': '24 Heures'},
      {'name': 'Pass 300F', 'price': 300, 'duration': '24 Heures'},
      {'name': 'Pass 500F', 'price': 500, 'duration': '24 Heures'},
      {'name': 'Pass 1000F', 'price': 1000, 'duration': '24 Heures'},
      {'name': 'Pass 3000F', 'price': 3000, 'duration': '24 Heures'},
    ];
    for (final pack in seedPacks) {
      await database.insert('packs', pack);
    }
  }

  static String localTimestamp([DateTime? value]) {
    final date = value ?? DateTime.now();
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${date.year.toString().padLeft(4, '0')}-'
        '${twoDigits(date.month)}-${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}:${twoDigits(date.second)}';
  }
}
