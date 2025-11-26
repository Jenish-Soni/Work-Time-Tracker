import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DailyLog {
  final int? id;
  final String date;
  final int punchIn;
  final int punchOut;
  final int duration;

  DailyLog({
    this.id,
    required this.date,
    required this.punchIn,
    required this.punchOut,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'punchIn': punchIn,
      'punchOut': punchOut,
      'duration': duration,
    };
  }

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      id: map['id'],
      date: map['date'],
      punchIn: map['punchIn'],
      punchOut: map['punchOut'],
      duration: map['duration'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('time_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE logs ( 
  id $idType, 
  date $textType,
  punchIn $integerType,
  punchOut $integerType,
  duration $integerType
  )
''');
  }

  Future<DailyLog> create(DailyLog log) async {
    final db = await instance.database;
    final id = await db.insert('logs', log.toMap());
    return DailyLog(
      id: id,
      date: log.date,
      punchIn: log.punchIn,
      punchOut: log.punchOut,
      duration: log.duration,
    );
  }

  Future<List<DailyLog>> readAllLogs() async {
    final db = await instance.database;
    final orderBy = 'date DESC, punchIn DESC';
    final result = await db.query('logs', orderBy: orderBy);

    return result.map((json) => DailyLog.fromMap(json)).toList();
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
