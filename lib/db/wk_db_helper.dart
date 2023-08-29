import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../wkim.dart';

class WKDBHelper {
  WKDBHelper._privateConstructor();
  static final WKDBHelper _instance = WKDBHelper._privateConstructor();
  static WKDBHelper get shared => _instance;
  final dbVersion = 1;
  Database? _database;
  Future<bool> init() async {
    var databasesPath = await getDatabasesPath();
    String path = p.join(databasesPath, 'wk_${WKIM.shared.options.uid}.db');
    _database = await openDatabase(
      path,
      version: dbVersion,
      onCreate: (Database db, int version) async {
        // onUpgrade(db);
      },
      // onUpgrade: (db, oldVersion, newVersion) => {
      //   onUpgrade(db)},
    );
    bool result = await onUpgrade(_database!);
    return _database != null && result;
  }

  Future<bool> onUpgrade(Database db) async {
    String path = await rootBundle
        .loadString('packages/wukongimfluttersdk/assets/sql.txt');
    List<String> names = path.split(';');
    SharedPreferences preferences = await SharedPreferences.getInstance();
    String wkUid = WKIM.shared.options.uid!;
    int maxVersion = preferences.getInt('wk_max_sql_version_$wkUid') ?? 0;
    int saveVersion = 0;
    for (int i = 0; i < names.length; i++) {
      if (names[i] == '') {
        continue;
      }
      int version = int.parse(names[i]);
      if (version > maxVersion) {
        String sqlStr = await rootBundle
            .loadString('packages/wukongimfluttersdk/assets/$version.sql');
        var sqlList = sqlStr.split(';');
        for (String sql in sqlList) {
          String exeSql = sql.replaceAll('\n', '');
          if (exeSql != '') {
            db.execute(exeSql);
          }
        }
        if (version > saveVersion) {
          saveVersion = version;
        }
      }
    }
    if (saveVersion > 0) {
      preferences.setInt('wk_max_sql_version_$wkUid', saveVersion);
    }
    return true;
  }

  Database getDB() {
    return _database!;
  }

  close() {
    if (_database != null) {
      _database!.close();
      _database = null;
    }
  }
}
