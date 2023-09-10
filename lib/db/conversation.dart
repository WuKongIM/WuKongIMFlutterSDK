import 'dart:collection';
import 'dart:convert';

import 'package:wukongimfluttersdk/db/const.dart';

import '../entity/conversation.dart';
import 'wk_db_helper.dart';

class ConversationDB {
  ConversationDB._privateConstructor();
  static final ConversationDB _instance = ConversationDB._privateConstructor();
  static ConversationDB get shared => _instance;
  final String extraCols =
      "IFNULL(${WKDBConst.tableConversationExtra}.browse_to,0) AS browse_to,IFNULL(${WKDBConst.tableConversationExtra}.keep_message_seq,0) AS keep_message_seq,IFNULL(${WKDBConst.tableConversationExtra}.keep_offset_y,0) AS keep_offset_y,IFNULL(${WKDBConst.tableConversationExtra}.draft,'') AS draft,IFNULL(${WKDBConst.tableConversationExtra}.draft_updated_at,0) AS draft_updated_at,IFNULL(${WKDBConst.tableConversationExtra}.version,0) AS extra_version";
  final String channelCols =
      "${WKDBConst.tableChannel}.channel_remark,${WKDBConst.tableChannel}.channel_name,${WKDBConst.tableChannel}.top,${WKDBConst.tableChannel}.mute,${WKDBConst.tableChannel}.save,${WKDBConst.tableChannel}.status as channel_status,${WKDBConst.tableChannel}.forbidden,${WKDBConst.tableChannel}.invite,${WKDBConst.tableChannel}.follow,${WKDBConst.tableChannel}.is_deleted as channel_is_deleted,${WKDBConst.tableChannel}.show_nick,${WKDBConst.tableChannel}.avatar,${WKDBConst.tableChannel}.avatar_cache_key,${WKDBConst.tableChannel}.online,${WKDBConst.tableChannel}.last_offline,${WKDBConst.tableChannel}.category,${WKDBConst.tableChannel}.receipt,${WKDBConst.tableChannel}.robot,${WKDBConst.tableChannel}.parent_channel_id AS c_parent_channel_id,${WKDBConst.tableChannel}.parent_channel_type AS c_parent_channel_type,${WKDBConst.tableChannel}.version AS channel_version,${WKDBConst.tableChannel}.remote_extra AS channel_remote_extra,${WKDBConst.tableChannel}.extra AS channel_extra";

  Future<List<WKUIConversationMsg>> queryAll() async {
    String sql =
        "SELECT ${WKDBConst.tableConversation}.*,$channelCols,$extraCols FROM ${WKDBConst.tableConversation} LEFT JOIN ${WKDBConst.tableChannel} ON ${WKDBConst.tableConversation}.channel_id = ${WKDBConst.tableChannel}.channel_id AND ${WKDBConst.tableConversation}.channel_type = ${WKDBConst.tableChannel}.channel_type LEFT JOIN ${WKDBConst.tableConversationExtra} ON ${WKDBConst.tableConversation}.channel_id=${WKDBConst.tableConversationExtra}.channel_id AND ${WKDBConst.tableConversation}.channel_type=${WKDBConst.tableConversationExtra}.channel_type where ${WKDBConst.tableConversation}.is_deleted=0 order by last_msg_timestamp desc";
    List<WKUIConversationMsg> list = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        WKConversationMsg msg = WKDBConst.serializeCoversation(data);
        list.add(getUIMsg(msg));
      }
    }
    return list;
  }

  Future<bool> delete(String channelID, int channelType) async {
    Map<String, dynamic> data = HashMap<String, Object>();
    data['is_deleted'] = 1;
    int row = await WKDBHelper.shared.getDB().update(
        WKDBConst.tableConversation, data,
        where: "channel_id='$channelID' and channel_type=$channelType");
    return row > 0;
  }

  Future<WKUIConversationMsg?> insertOrUpdateWithConvMsg(
      WKConversationMsg conversationMsg) async {
    int row;
    WKConversationMsg? lastMsg = await queryMsgByMsgChannelId(
        conversationMsg.channelID, conversationMsg.channelType);

    if (lastMsg == null || lastMsg.channelID.isEmpty) {
      row = await WKDBHelper.shared
          .getDB()
          .insert(WKDBConst.tableConversation, getMap(conversationMsg, false));
    } else {
      conversationMsg.unreadCount =
          lastMsg.unreadCount + conversationMsg.unreadCount;
      row = await WKDBHelper.shared.getDB().update(
          WKDBConst.tableConversation, getMap(conversationMsg, false),
          where:
              "channel_id='${conversationMsg.channelID}' and channel_type=${conversationMsg.channelType}");
    }
    if (row > 0) {
      return getUIMsg(conversationMsg);
    }
    return null;
  }

  Future<WKConversationMsg?> queryMsgByMsgChannelId(
      String channelId, int channelType) async {
    WKConversationMsg? msg;
    String sql =
        "select * from ${WKDBConst.tableConversation} where channel_id='$channelId' and channel_type=$channelType";

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      msg = WKDBConst.serializeCoversation(list[0]);
    }
    return msg;
  }

  Future<int> getMaxVersion() async {
    int maxVersion = 0;
    String sql =
        "select max(version) version from ${WKDBConst.tableConversation} limit 0, 1";

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      maxVersion = WKDBConst.readInt(data, 'version');
    }
    return maxVersion;
  }

  Future<String> getLastMsgSeqs() async {
    String lastMsgSeqs = "";
    String sql =
        "select GROUP_CONCAT(channel_id||':'||channel_type||':'|| last_seq,'|') synckey from (select *,(select max(message_seq) from ${WKDBConst.tableMessage} where ${WKDBConst.tableMessage}.channel_id=${WKDBConst.tableConversation}.channel_id and ${WKDBConst.tableMessage}.channel_type=${WKDBConst.tableConversation}.channel_type limit 1) last_seq from ${WKDBConst.tableConversation}) cn where channel_id<>'' AND is_deleted=0";

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      lastMsgSeqs = WKDBConst.readString(data, 'synckey');
    }
    return lastMsgSeqs;
  }

  Future<List<WKConversationMsg>> queryWithChannelIds(
      List<String> channelIds) async {
    StringBuffer sb = StringBuffer();
    for (var i = 0; i < channelIds.length; i++) {
      if (i != 0) {
        sb.write(",");
      }
      sb.write("'");
      sb.write(channelIds[i]);
      sb.write("'");
    }
    String sql =
        "select * from '${WKDBConst.tableConversation}' where channel_id in(${sb.toString()})";
    List<WKConversationMsg> list = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeCoversation(data));
      }
    }
    return list;
  }

  insertMsgList(List<WKConversationMsg> list) async {
    List<String> channelIds = [];
    for (var i = 0; i < list.length; i++) {
      if (list[i].channelID != '') {
        channelIds.add(list[i].channelID);
      }
    }
    List<WKConversationMsg> existList = await queryWithChannelIds(channelIds);
    List<Map<String, dynamic>> insertList = [];
    List<Map<String, dynamic>> updateList = [];

    for (WKConversationMsg msg in list) {
      if (existList.isNotEmpty) {
        for (var i = 0; i < existList.length; i++) {
          bool isAdd = true;
          if (existList[i].channelID == msg.channelID &&
              existList[i].channelType == msg.channelType) {
            updateList.add(getMap(msg, true));
            isAdd = false;
            break;
          }
          if (isAdd) {
            insertList.add(getMap(msg, true));
          }
        }
      } else {
        insertList.add(getMap(msg, true));
      }
    }
    if (insertList.isNotEmpty || updateList.isNotEmpty) {
      WKDBHelper.shared.getDB().transaction((txn) async {
        if (insertList.isNotEmpty) {
          for (int i = 0; i < insertList.length; i++) {
            txn.insert(WKDBConst.tableConversation, insertList[i]);
          }
        }
        if (updateList.isNotEmpty) {
          for (Map<String, dynamic> value in updateList) {
            txn.update(WKDBConst.tableConversation, value,
                where:
                    "channel_id='${value['channel_id']}' and channel_type=${value['channel_type']}");
          }
        }
      });
    }
  }

  WKUIConversationMsg getUIMsg(WKConversationMsg conversationMsg) {
    WKUIConversationMsg msg = WKUIConversationMsg();
    msg.lastMsgSeq = conversationMsg.lastMsgSeq;
    msg.clientMsgNo = conversationMsg.lastClientMsgNO;
    msg.unreadCount = conversationMsg.unreadCount;
    msg.lastMsgTimestamp = conversationMsg.lastMsgTimestamp;
    msg.channelID = conversationMsg.channelID;
    msg.channelType = conversationMsg.channelType;
    msg.isDeleted = conversationMsg.isDeleted;
    msg.parentChannelID = conversationMsg.parentChannelID;
    msg.parentChannelType = conversationMsg.parentChannelType;
    msg.setRemoteMsgExtra(conversationMsg.msgExtra);
    return msg;
  }

  Map<String, dynamic> getMap(WKConversationMsg msg, bool isSync) {
    Map<String, dynamic> data = HashMap<String, Object>();
    data['channel_id'] = msg.channelID;
    data['channel_type'] = msg.channelType;
    data['last_client_msg_no'] = msg.lastClientMsgNO;
    data['last_msg_timestamp'] = msg.lastMsgTimestamp;
    data['last_msg_seq'] = msg.lastMsgSeq;
    data['unread_count'] = msg.unreadCount;
    data['parent_channel_id'] = msg.parentChannelID;
    data['parent_channel_type'] = msg.parentChannelType;
    data['is_deleted'] = msg.isDeleted;
    if (msg.localExtraMap == null) {
      data['extra'] = '';
    } else {
      data['extra'] = jsonEncode(msg.localExtraMap);
    }
    if (isSync) {
      data['version'] = msg.version;
    }
    return data;
  }
}
