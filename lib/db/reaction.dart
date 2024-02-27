import 'package:sqflite/sqflite.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import 'const.dart';
import 'wk_db_helper.dart';

class ReactionDB {
  ReactionDB._privateConstructor();
  static final ReactionDB _instance = ReactionDB._privateConstructor();
  static ReactionDB get shared => _instance;

  Future<int> queryMaxSeqWithChannel(String channelID, int channelType) async {
    String sql =
        "select max(seq) seq from ${WKDBConst.tableMessageReaction} where channel_id=? and channel_type=? limit 0, 1";
    int version = 0;

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql, [channelID, channelType]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      if (data != null) {
        version = WKDBConst.readInt(data, 'seq');
      }
    }
    return version;
  }

  Future<List<WKMsgReaction>> queryWithMessageId(String messageId) async {
    List<WKMsgReaction> list = [];
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableMessageReaction,
        where: "message_id=? and is_deleted=0",
        whereArgs: [messageId],
        orderBy: "created_at desc");
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeMsgReation(data));
      }
    }
    return list;
  }

  Future<List<WKMsgReaction>> queryWithMessageIds(
      List<String> messageIds) async {
    List<WKMsgReaction> list = [];
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableMessageReaction,
        where:
            "message_id in (${WKDBConst.getPlaceholders(messageIds.length)}) and is_deleted=0",
        whereArgs: messageIds,
        orderBy: "created_at desc");
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeMsgReation(data));
      }
    }
    return list;
  }

  Future<bool> insertOrUpdateReactionList(List<WKMsgReaction> list) async {
    if (list.isEmpty) return true;
    bool isSuccess = true;
    for (int i = 0, size = list.length; i < size; i++) {
      // insertOrUpdateReaction(list[i]);
      int row = await insertReaction(list[i]);
      if (isSuccess) {
        isSuccess = row > 0;
      }
    }
    return isSuccess;
  }

  // insertOrUpdateReaction(WKMsgReaction reaction) async {
  //   bool isExist = await isExistReaction(reaction.uid, reaction.messageID);
  //   if (isExist) {
  //     updateReaction(reaction);
  //   } else {
  //     insertReaction(reaction);
  //   }
  // }

  // updateReaction(WKMsgReaction reaction) {
  //   var map = <String, Object>{};
  //   map['is_deleted'] = reaction.isDeleted;
  //   map['seq'] = reaction.seq;
  //   map['emoji'] = reaction.emoji;
  //   WKDBHelper.shared.getDB().update(WKDBConst.tableMessageReaction, map,
  //       where: "message_id=? and uid=?",
  //       whereArgs: [reaction.messageID, reaction.uid]);
  // }

  insertReaction(WKMsgReaction reaction) {
    WKDBHelper.shared.getDB().insert(
        WKDBConst.tableMessageReaction, getReactionMap(reaction),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isExistReaction(String uid, String messageID) async {
    bool isExist = false;
    List<Map<String, Object?>> list = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableMessageReaction,
        where: "message_id=? and uid=?",
        whereArgs: [messageID, uid]);
    if (list.isNotEmpty) {
      isExist = true;
    }
    return isExist;
  }

  dynamic getReactionMap(WKMsgReaction reaction) {
    var map = <String, Object>{};
    map['channel_id'] = reaction.channelID;
    map['channel_id'] = reaction.channelID;
    map['channel_type'] = reaction.channelType;
    map['message_id'] = reaction.messageID;
    map['uid'] = reaction.uid;
    map['name'] = reaction.name;
    map['is_deleted'] = reaction.isDeleted;
    map['seq'] = reaction.seq;
    map['emoji'] = reaction.emoji;
    map['created_at'] = reaction.createdAt;
  }
}
