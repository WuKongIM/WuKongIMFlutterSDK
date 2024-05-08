import 'dart:collection';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/conversation.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../entity/conversation.dart';
import '../entity/reminder.dart';

class ReminderDB {
  ReminderDB._privateConstructor();
  static final ReminderDB _instance = ReminderDB._privateConstructor();
  static ReminderDB get shared => _instance;

  Future<int> getMaxVersion() async {
    String sql =
        "select * from ${WKDBConst.tableReminders} order by version desc limit 1";
    int version = 0;

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      if (data != null) {
        version = WKDBConst.readInt(data, 'version');
      }
    }
    return version;
  }

  Future<List<WKReminder>> queryWithChannel(
      String channelID, int channelType, int done) async {
    List<WKReminder> list = [];
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableReminders,
        where: "channel_id=? and channel_type=? and done=?",
        whereArgs: [channelID, channelType, done],
        orderBy: "message_seq desc");
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeReminder(data));
      }
    }
    return list;
  }

  Future<List<WKReminder>> saveReminders(List<WKReminder> list) async {
    List<int> ids = [];
    List<String> channelIds = [];
    for (int i = 0, size = list.length; i < size; i++) {
      bool isAdd = true;
      for (String channelId in channelIds) {
        if (list[i].channelID == list[i].channelID &&
            channelId == list[i].channelID) {
          isAdd = false;
          break;
        }
      }
      if (isAdd) {
        channelIds.add(list[i].channelID);
      }
      ids.add(list[i].reminderID);
    }
    List<Map<String, dynamic>> addList = [];
    List<Map<String, dynamic>> updateList = [];
    List<WKReminder> allList = await queryWithIds(ids);
    for (int i = 0, size = list.length; i < size; i++) {
      bool isAdd = true;
      for (WKReminder reminder in allList) {
        if (reminder.reminderID == list[i].reminderID) {
          updateList.add(getMap(reminder));
          isAdd = false;
          break;
        }
      }
      if (isAdd) {
        addList.add(getMap(list[i]));
      }
    }

    if (addList.isNotEmpty || updateList.isNotEmpty) {
      WKDBHelper.shared.getDB().transaction((txn) async {
        if (addList.isNotEmpty) {
          for (Map<String, dynamic> value in addList) {
            txn.insert(WKDBConst.tableReminders, value,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        if (updateList.isNotEmpty) {
          for (Map<String, dynamic> value in updateList) {
            txn.update(WKDBConst.tableReminders, value,
                where: "reminder_id=${value['reminder_id']}");
          }
        }
      });
    }

    List<WKReminder> reminderList = await queryWithChannelIds(channelIds);
    HashMap<String, List<WKReminder>?> maps = listToMap(reminderList);
    List<WKUIConversationMsg> uiMsgList = [];
    List<WKConversationMsg> msgs =
        await ConversationDB.shared.queryWithChannelIds(channelIds);
    for (int i = 0; i < msgs.length; i++) {
      uiMsgList.add(ConversationDB.shared.getUIMsg(msgs[i]));
    }
    for (int i = 0, size = uiMsgList.length; i < size; i++) {
      String key = "${uiMsgList[i].channelID}_${uiMsgList[i].channelType}";
      if (maps.containsKey(key) && maps[key] != null) {
        uiMsgList[i].setReminderList(maps[key]!);
      }
    }
    WKIM.shared.conversationManager.setRefreshUIMsgs(uiMsgList);
    return reminderList;
  }

  Future<List<WKReminder>> queryWithChannelIds(List<String> channelIds) async {
    List<WKReminder> list = [];
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableReminders,
        where:
            "channel_id in (${WKDBConst.getPlaceholders(channelIds.length)})",
        whereArgs: channelIds);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeReminder(data));
      }
    }
    return list;
  }

  Future<List<WKReminder>> queryWithIds(List<int> ids) async {
    List<WKReminder> list = [];
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableReminders,
        where: "reminder_id in (${WKDBConst.getPlaceholders(ids.length)})",
        whereArgs: ids);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeReminder(data));
      }
    }
    return list;
  }

  HashMap<String, List<WKReminder>?> listToMap(List<WKReminder> list) {
    HashMap<String, List<WKReminder>?> map = HashMap();
    if (list.isEmpty) {
      return map;
    }
    for (WKReminder reminder in list) {
      String key = "${reminder.channelID}_${reminder.channelType}";
      List<WKReminder>? tempList = [];
      if (map.containsKey(key)) {
        tempList = map[key];
      }
      tempList ??= [];
      tempList.add(reminder);
      map[key] = tempList;
    }
    return map;
  }

  dynamic getMap(WKReminder reminder) {
    var map = <String, Object>{};
    map['channel_id'] = reminder.channelID;
    map['channel_type'] = reminder.channelType;
    map['reminder_id'] = reminder.reminderID;
    map['message_id'] = reminder.messageID;
    map['message_seq'] = reminder.messageSeq;
    map['uid'] = reminder.uid;
    map['type'] = reminder.type;
    map['is_locate'] = reminder.isLocate;
    map['text'] = reminder.text;
    map['version'] = reminder.version;
    map['done'] = reminder.done;
    map['need_upload'] = reminder.needUpload;
    map['publisher'] = reminder.publisher;
    if (reminder.data != null) {
      map['data'] = jsonEncode(reminder.data);
    } else {
      map['data'] = '';
    }

    return map;
  }
}
