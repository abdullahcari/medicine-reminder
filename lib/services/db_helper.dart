import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/pill_model.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  static const String tablePills = 'pills';
  static const String tableHistory = 'history_logs';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'medicine_reminder_v3.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 1. Ana İlaç Planları Tablosu (Çoklu Öğün, Ortak Grup & Günün Vakitleri Destekli)
        await db.execute('''
          CREATE TABLE $tablePills (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            groupId TEXT,
            profileId TEXT DEFAULT 'p1',
            name TEXT NOT NULL,
            type TEXT DEFAULT 'tablet',
            dosage TEXT NOT NULL,
            time TEXT NOT NULL,
            timeOfDay TEXT DEFAULT 'morning',
            freq INTEGER DEFAULT 1,
            stock INTEGER DEFAULT 30,
            nextDueDate TEXT NOT NULL,
            lastTakenDate TEXT DEFAULT '',
            isTaken INTEGER DEFAULT 0
          )
        ''');

        // 2. Geçmiş Alım Günlüğü Tablosu (Dün, Önceki Gün Ne Alındı?)
        await db.execute('''
          CREATE TABLE $tableHistory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            profileId TEXT DEFAULT 'p1',
            pillId INTEGER,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            dosage TEXT NOT NULL,
            timeTaken TEXT NOT NULL,
            timeOfDay TEXT DEFAULT 'morning',
            dateYMD TEXT NOT NULL,
            dateLabel TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // --- İLAÇ İŞLEMLERİ ---
  Future<int> insertPill(Pill pill) async {
    final db = await database;
    return await db.insert(tablePills, pill.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Pill>> getAllPills() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tablePills, orderBy: 'time ASC');
    return List.generate(maps.length, (i) => Pill.fromMap(maps[i]));
  }

  Future<List<Pill>> getTodayPills(String todayYMD) async {
    final db = await database;
    await checkAndResetDailyPills(todayYMD);
    final List<Map<String, dynamic>> maps = await db.query(
      tablePills,
      where: 'nextDueDate <= ?',
      whereArgs: [todayYMD],
      orderBy: 'time ASC',
    );
    return List.generate(maps.length, (i) => Pill.fromMap(maps[i]));
  }

  // Ertesi Gün Otomatik Sıfırlama (Her Gün Alınacak İlaçların Yeni Günde Beklemede Olması)
  Future<void> checkAndResetDailyPills(String todayYMD) async {
    final db = await database;
    // Her gün alınacak ilaçlar: lastTakenDate bugünden küçükse ve isTaken == 1 ise 0 yap
    await db.rawUpdate('''
      UPDATE $tablePills 
      SET isTaken = 0 
      WHERE freq = 1 AND isTaken = 1 AND lastTakenDate != '' AND lastTakenDate < ?
    ''', [todayYMD]);

    // X günde bir alınacak ilaçlar: nextDueDate bugüne eşit veya geçmişse ve bugün henüz alınmadıysa 0 yap
    await db.rawUpdate('''
      UPDATE $tablePills 
      SET isTaken = 0 
      WHERE freq > 1 AND isTaken = 1 AND nextDueDate <= ? AND lastTakenDate != ?
    ''', [todayYMD, todayYMD]);
  }

  // İlacı "Alındı" Yapma + Ortak Stok Azaltma + Geçmiş Günlüğe Ekleme
  Future<void> togglePillStatus(Pill pill) async {
    final db = await database;
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final todayYMD = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (pill.isTaken == 0) {
      // 1. İlaç alındı işaretlenir & stok 1 düşer
      final newStock = pill.stock > 0 ? pill.stock - 1 : 0;
      final nextDate = pill.freq > 1 ? now.add(Duration(days: pill.freq)) : now;
      final nextYMD = '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';

      // Ortak stok güncelleme (Eğer aynı ilaca ait sabah/öğle/akşam dozları varsa hepsi aynı kutudan düşer)
      if (pill.groupId != null && pill.groupId!.isNotEmpty) {
        await db.update(
          tablePills,
          {'stock': newStock},
          where: 'groupId = ?',
          whereArgs: [pill.groupId],
        );
      } else {
        await db.update(
          tablePills,
          {'stock': newStock},
          where: 'name = ? AND profileId = ?',
          whereArgs: [pill.name, pill.profileId],
        );
      }

      await db.update(
        tablePills,
        {
          'isTaken': 1,
          'lastTakenDate': todayYMD,
          'nextDueDate': nextYMD,
        },
        where: 'id = ?',
        whereArgs: [pill.id],
      );

      // 2. Geçmiş günlüğe eklenir
      await db.insert(tableHistory, {
        'profileId': pill.profileId,
        'pillId': pill.id,
        'name': pill.name,
        'type': pill.type,
        'dosage': pill.dosage,
        'timeTaken': '$hh:$mm',
        'timeOfDay': pill.timeOfDay,
        'dateYMD': todayYMD,
        'dateLabel': 'Bugün',
      });
    } else {
      // Geri alma (Bekliyor yapma)
      final newStock = pill.stock + 1;
      if (pill.groupId != null && pill.groupId!.isNotEmpty) {
        await db.update(
          tablePills,
          {'stock': newStock},
          where: 'groupId = ?',
          whereArgs: [pill.groupId],
        );
      } else {
        await db.update(
          tablePills,
          {'stock': newStock},
          where: 'name = ? AND profileId = ?',
          whereArgs: [pill.name, pill.profileId],
        );
      }

      await db.update(
        tablePills,
        {
          'isTaken': 0,
          'lastTakenDate': '',
          'nextDueDate': todayYMD,
        },
        where: 'id = ?',
        whereArgs: [pill.id],
      );
    }
  }

  // Profil Silme ve İlişkili İlaçları Temizleme (Cascade Delete)
  Future<void> deleteProfile(String profileId) async {
    final db = await database;
    await db.delete(tablePills, where: 'profileId = ?', whereArgs: [profileId]);
    await db.delete(tableHistory, where: 'profileId = ?', whereArgs: [profileId]);
  }

  // İlaç Güncelleme (Düzenleme Modu & Ortak Stok Senkronizasyonu)
  Future<int> updatePill(Pill pill) async {
    final db = await database;
    if (pill.id == null) return 0;
    if (pill.groupId != null && pill.groupId!.isNotEmpty) {
      await db.update(
        tablePills,
        {
          'stock': pill.stock,
          'freq': pill.freq,
        },
        where: 'groupId = ?',
        whereArgs: [pill.groupId],
      );
    }
    return await db.update(
      tablePills,
      pill.toMap(),
      where: 'id = ?',
      whereArgs: [pill.id],
    );
  }

  Future<void> deletePill(int id) async {
    final db = await database;
    await db.delete(tablePills, where: 'id = ?', whereArgs: [id]);
  }

  // --- GEÇMİŞ GÜNLÜK İŞLEMLERİ ---
  Future<List<Map<String, dynamic>>> getHistoryLogs({String? profileId}) async {
    final db = await database;
    if (profileId != null && profileId != 'all') {
      return await db.query(
        tableHistory,
        where: 'profileId = ?',
        whereArgs: [profileId],
        orderBy: 'dateYMD DESC, timeTaken DESC',
      );
    }
    return await db.query(tableHistory, orderBy: 'dateYMD DESC, timeTaken DESC');
  }
}
