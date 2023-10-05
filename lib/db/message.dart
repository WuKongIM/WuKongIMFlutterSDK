import 'dart:convert';

import 'package:wukongimfluttersdk/db/channel.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../entity/channel.dart';
import '../entity/channel_member.dart';
import 'channel_member.dart';
import 'wk_db_helper.dart';

class MessageDB {
  MessageDB._privateConstructor();
  static final MessageDB _instance = MessageDB._privateConstructor();
  static MessageDB get shared => _instance;
  final String extraCols =
      "IFNULL(${WKDBConst.tableMessageExtra}.readed,0) as readed,IFNULL(${WKDBConst.tableMessageExtra}.readed_count,0) as readed_count,IFNULL(${WKDBConst.tableMessageExtra}.unread_count,0) as unread_count,IFNULL(${WKDBConst.tableMessageExtra}.revoke,0) as revoke,IFNULL(${WKDBConst.tableMessageExtra}.revoker,'') as revoker,IFNULL(${WKDBConst.tableMessageExtra}.extra_version,0) as extra_version,IFNULL(${WKDBConst.tableMessageExtra}.is_mutual_deleted,0) as is_mutual_deleted,IFNULL(${WKDBConst.tableMessageExtra}.need_upload,0) as need_upload,IFNULL(${WKDBConst.tableMessageExtra}.content_edit,'') as content_edit,IFNULL(${WKDBConst.tableMessageExtra}.edited_at,0) as edited_at";
  final String messageCols =
      "${WKDBConst.tableMessage}.client_seq,${WKDBConst.tableMessage}.message_id,${WKDBConst.tableMessage}.message_seq,${WKDBConst.tableMessage}.channel_id,${WKDBConst.tableMessage}.channel_type,${WKDBConst.tableMessage}.timestamp,${WKDBConst.tableMessage}.topic_id,${WKDBConst.tableMessage}.from_uid,${WKDBConst.tableMessage}.type,${WKDBConst.tableMessage}.content,${WKDBConst.tableMessage}.status,${WKDBConst.tableMessage}.voice_status,${WKDBConst.tableMessage}.created_at,${WKDBConst.tableMessage}.updated_at,${WKDBConst.tableMessage}.searchable_word,${WKDBConst.tableMessage}.client_msg_no,${WKDBConst.tableMessage}.setting,${WKDBConst.tableMessage}.order_seq,${WKDBConst.tableMessage}.extra,${WKDBConst.tableMessage}.is_deleted,${WKDBConst.tableMessage}.flame,${WKDBConst.tableMessage}.flame_second,${WKDBConst.tableMessage}.viewed,${WKDBConst.tableMessage}.viewed_at";

  Future<int> insert(WKMsg msg) async {
    if (msg.clientSeq != 0) {
      updateMsg(msg);
      return msg.clientSeq;
    }
    if (msg.clientMsgNO != '') {
      WKMsg? temp = await queryWithClientMsgNo(msg.clientMsgNO);
      if (temp != null && temp.clientSeq != 0) {
        msg.isDeleted = 1;
        msg.clientMsgNO = WKIM.shared.messageManager.generateClientMsgNo();
      }
    }
    return await WKDBHelper.shared
        .getDB()
        .insert(WKDBConst.tableMessage, getMap(msg));
  }

  Future<int> updateMsg(WKMsg msg) async {
    return await WKDBHelper.shared.getDB().update(
        WKDBConst.tableMessage, getMap(msg),
        where: "client_seq=${msg.clientSeq}");
  }

  Future<int> updateMsgWithField(dynamic map, int clientSeq) async {
    return await WKDBHelper.shared
        .getDB()
        .update(WKDBConst.tableMessage, map, where: "client_seq=$clientSeq");
  }

  Future<int> updateMsgWithFieldAndClientMsgNo(
      dynamic map, String clientMsgNO) async {
    return await WKDBHelper.shared.getDB().update(WKDBConst.tableMessage, map,
        where: "client_msg_no='$clientMsgNO'");
  }

  Future<WKMsg?> queryWithClientMsgNo(String clientMsgNo) async {
    WKMsg? wkMsg;
    String sql =
        "select $messageCols,$extraCols from ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} ON ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.client_msg_no='$clientMsgNo'";

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      wkMsg = WKDBConst.serializeWKMsg(list[0]);
    }
    if (wkMsg != null) {
      wkMsg.reactionList = await queryReactions(wkMsg.messageID);
    }
    return wkMsg;
  }

  Future<WKMsg?> queryWithClientSeq(int clientSeq) async {
    WKMsg? wkMsg;
    String sql =
        "select $messageCols,$extraCols from ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} ON ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.client_seq=$clientSeq";

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      wkMsg = WKDBConst.serializeWKMsg(list[0]);
    }
    if (wkMsg != null) {
      wkMsg.reactionList = await queryReactions(wkMsg.messageID);
    }
    return wkMsg;
  }

  Future<List<WKMsg>> queryWithMessageIds(List<String> messageIds) async {
    StringBuffer sb = StringBuffer();
    for (int i = 0, size = messageIds.length; i < size; i++) {
      if (i != 0) {
        sb.write(",");
      }
      sb.write("'");
      sb.write(messageIds[i]);
      sb.write("'");
    }

    String sql =
        "select $messageCols,$extraCols from ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} ON ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.message_id in (${sb.toString()})";
    List<WKMsg> list = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeWKMsg(data));
      }
    }
    return list;
  }

  Future<List<WKMsgReaction>> queryReactions(String messageID) async {
    String sql =
        "select * from  ${WKDBConst.tableMessageReaction} where message_id='$messageID' and is_deleted=0 ORDER BY created_at desc";
    List<WKMsgReaction> list = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeMsgReation(data));
      }
    }
    return list;
  }

  Future<int> queryMaxOrderSeq(String channelID, int channelType) async {
    int maxOrderSeq = 0;
    String sql =
        "select max(order_seq) order_seq from ${WKDBConst.tableMessage} where channel_id ='$channelID' and channel_type=$channelType and type<>99 and type<>0 and is_deleted=0";
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      maxOrderSeq = WKDBConst.readInt(data, 'order_seq');
    }
    return maxOrderSeq;
  }

  Future<int> getMaxMessageSeq(String channelID, int channelType) async {
    String sql =
        "SELECT max(message_seq) message_seq FROM ${WKDBConst.tableMessage} WHERE channel_id='$channelID' AND channel_type=$channelType";
    int messageSeq = 0;
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      messageSeq = WKDBConst.readInt(data, 'message_seq');
    }
    return messageSeq;
  }

  Future<int> getOrderSeq(
      String channelID, int channelType, int maxOrderSeq, int limit) async {
    int minOrderSeq = 0;
    String sql =
        "select order_seq from ${WKDBConst.tableMessage} where channel_id='$channelID' and channel_type='$channelType' and type<>99 and order_seq <= $maxOrderSeq order by order_seq desc limit $limit";
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      minOrderSeq = WKDBConst.readInt(data, 'order_seq');
    }
    return minOrderSeq;
  }

  Future<List<WKMsg>> getMessages(String channelId, int channelType,
      int oldestOrderSeq, bool contain, int pullMode, int limit) async {
    List<WKMsg> msgList = [];
    String sql;

    if (oldestOrderSeq <= 0) {
      sql =
          "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id='$channelId' and ${WKDBConst.tableMessage}.channel_type=$channelType and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,$limit";
    } else {
      if (pullMode == 0) {
        if (contain) {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id='$channelId' and ${WKDBConst.tableMessage}.channel_type=$channelType and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq<=$oldestOrderSeq) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,$limit";
        } else {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id='$channelId' and ${WKDBConst.tableMessage}.channel_type=$channelType and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq<$oldestOrderSeq) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,$limit";
        }
      } else {
        if (contain) {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id='$channelId' and ${WKDBConst.tableMessage}.channel_type=$channelType and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq>=$oldestOrderSeq) where is_deleted=0 and is_mutual_deleted=0 order by order_seq asc limit 0,$limit";
        } else {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id='$channelId' and ${WKDBConst.tableMessage}.channel_type=$channelType and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq>$oldestOrderSeq) where is_deleted=0 and is_mutual_deleted=0 order by order_seq asc limit 0,$limit";
        }
      }
    }
    List<String> messageIds = [];
    // List<String> replyMsgIds = [];
    List<String> fromUIDs = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql);

    if (results.isNotEmpty) {
      WKChannel? wkChannel =
          await ChannelDB.shared.query(channelId, channelType);
      for (Map<String, Object?> data in results) {
        WKMsg wkMsg = WKDBConst.serializeWKMsg(data);
        wkMsg.setChannelInfo(wkChannel);
        if (wkMsg.messageID != '') {
          messageIds.add(wkMsg.messageID);
        }

        // if (wkMsg.messageContent != null && wkMsg.messageContent.reply != null && !TextUtils.isEmpty(wkMsg.messageContent.reply.message_id)) {
        //             replyMsgIds.add(wkMsg.messageContent.reply.message_id);
        //         }
        if (wkMsg.fromUID != '') {
          bool isAdd = true;
          for (int i = 0; i < fromUIDs.length; i++) {
            if (fromUIDs[i] == wkMsg.fromUID) {
              isAdd = false;
              break;
            }
          }
          if (isAdd) {
            fromUIDs.add(wkMsg.fromUID);
          }
        }
        if (pullMode == 0) {
          msgList.insert(0, wkMsg);
        } else {
          msgList.add(wkMsg);
        }
      }
    }
    //扩展消息
    List<WKMsgReaction> list = await queryMsgReactionWithMessageIds(messageIds);
    if (list.isNotEmpty) {
      for (int i = 0, size = msgList.length; i < size; i++) {
        for (int j = 0, len = list.length; j < len; j++) {
          if (list[j].messageID == msgList[i].messageID) {
            if (msgList[i].reactionList == null) {
              msgList[i].reactionList = [];
            }
            msgList[i].reactionList!.add(list[j]);
          }
        }
      }
    }
    // 发送者成员信息
    if (channelType == WKChannelType.group) {
      List<WKChannelMember> memberList = await ChannelMemberDB.shared
          .queryMemberWithUIDs(channelId, channelType, fromUIDs);
      if (memberList.isNotEmpty) {
        for (WKChannelMember member in memberList) {
          for (int i = 0, size = msgList.length; i < size; i++) {
            if (msgList[i].fromUID != '' &&
                msgList[i].fromUID == member.memberUID) {
              msgList[i].setMemberOfFrom(member);
            }
          }
        }
      }
    }
    //消息发送者信息
    List<WKChannel> wkChannels = await ChannelDB.shared
        .queryWithChannelIdsAndChannelType(fromUIDs, WKChannelType.personal);
    if (wkChannels.isNotEmpty) {
      for (WKChannel wkChannel in wkChannels) {
        for (int i = 0, size = msgList.length; i < size; i++) {
          if (msgList[i].fromUID != '' &&
              msgList[i].fromUID == wkChannel.channelID) {
            msgList[i].setFrom(wkChannel);
          }
        }
      }
    }
    // 查询编辑内容
    return msgList;
  }

  var requestCount = 0;
  void getOrSyncHistoryMessages(
      String channelId,
      int channelType,
      int oldestOrderSeq,
      bool contain,
      int pullMode,
      int limit,
      final Function(List<WKMsg>) iGetOrSyncHistoryMsgBack,
      final Function() syncBack) async {
    //获取原始数据
    List<WKMsg> list = await getMessages(
        channelId, channelType, oldestOrderSeq, contain, pullMode, limit);
    //业务判断数据
    List<WKMsg> tempList = [];
    for (int i = 0, size = list.length; i < size; i++) {
      tempList.add(list[i]);
    }

    //先通过message_seq排序
    if (tempList.isNotEmpty) {
      tempList.sort((a, b) => a.messageSeq.compareTo(b.messageSeq));
    }
    //获取最大和最小messageSeq
    int minMessageSeq = 0;
    int maxMessageSeq = 0;
    for (int i = 0, size = tempList.length; i < size; i++) {
      if (tempList[i].messageSeq != 0) {
        if (minMessageSeq == 0) minMessageSeq = tempList[i].messageSeq;
        if (tempList[i].messageSeq > maxMessageSeq) {
          maxMessageSeq = tempList[i].messageSeq;
        }

        if (tempList[i].messageSeq < minMessageSeq) {
          minMessageSeq = tempList[i].messageSeq;
        }
      }
    }
    //是否同步消息
    bool isSyncMsg = false;
    int startMsgSeq = 0;
    int endMsgSeq = 0;
    //判断页与页之间是否连续
    int oldestMsgSeq;

    //如果获取到的messageSeq为0说明oldestOrderSeq这条消息是本地消息则获取他上一条或下一条消息的messageSeq做为判断
    if (oldestOrderSeq % 1000 != 0) {
      oldestMsgSeq =
          await getMsgSeq(channelId, channelType, oldestOrderSeq, pullMode);
    } else {
      oldestMsgSeq = oldestOrderSeq ~/ 1000;
    }
    if (pullMode == 0) {
      //下拉获取消息
      if (maxMessageSeq != 0 &&
          oldestMsgSeq != 0 &&
          oldestMsgSeq - maxMessageSeq > 1) {
        isSyncMsg = true;
        startMsgSeq = oldestMsgSeq;
        endMsgSeq = maxMessageSeq;
      }
    } else {
      //上拉获取消息
      if (minMessageSeq != 0 &&
          oldestMsgSeq != 0 &&
          minMessageSeq - oldestMsgSeq > 1) {
        isSyncMsg = true;
        startMsgSeq = oldestMsgSeq;
        endMsgSeq = minMessageSeq;
      }
    }
    if (!isSyncMsg) {
      //判断当前页是否连续
      for (int i = 0, size = tempList.length; i < size; i++) {
        int nextIndex = i + 1;
        if (nextIndex < tempList.length) {
          if (tempList[nextIndex].messageSeq != 0 &&
              tempList[i].messageSeq != 0 &&
              tempList[nextIndex].messageSeq - tempList[i].messageSeq > 1) {
            //判断该条消息是否被删除
            int num = await getDeletedCount(tempList[i].messageSeq,
                tempList[nextIndex].messageSeq, channelId, channelType);
            if (num <
                (tempList[nextIndex].messageSeq - tempList[i].messageSeq) - 1) {
              isSyncMsg = true;
              int max = tempList[nextIndex].messageSeq;
              int min = tempList[i].messageSeq;
              if (tempList[nextIndex].messageSeq < tempList[i].messageSeq) {
                max = tempList[i].messageSeq;
                min = tempList[nextIndex].messageSeq;
              }
              if (pullMode == 0) {
                // 下拉
                startMsgSeq = max;
                endMsgSeq = min;
              } else {
                startMsgSeq = min;
                endMsgSeq = max;
              }
              break;
            }
          }
        }
      }
    }

    if (!isSyncMsg) {
      if (minMessageSeq == 1) {
        requestCount = 0;
        iGetOrSyncHistoryMsgBack(list);
        return;
      }
    }
    //计算最后一页后是否还存在消息
    if (!isSyncMsg && tempList.length < limit) {
      if (pullMode == 0) {
        //如果下拉获取数据
        isSyncMsg = true;
        startMsgSeq = oldestMsgSeq;
        endMsgSeq = 0;
      } else {
        //如果上拉获取数据
        isSyncMsg = true;
        startMsgSeq = oldestMsgSeq;
        endMsgSeq = 0;
      }
    }

    if (isSyncMsg &&
        (startMsgSeq != endMsgSeq || (startMsgSeq == 0 && endMsgSeq == 0)) &&
        requestCount < 5) {
      if (requestCount == 0) {
        syncBack();
      }
      //同步消息
      requestCount++;
      WKIM.shared.messageManager.setSyncChannelMsgListener(
          channelId, channelType, startMsgSeq, endMsgSeq, limit, pullMode,
          (syncChannelMsg) {
        if (syncChannelMsg != null &&
            syncChannelMsg.messages != null &&
            syncChannelMsg.messages!.isNotEmpty) {
          getOrSyncHistoryMessages(channelId, channelType, oldestOrderSeq,
              contain, pullMode, limit, iGetOrSyncHistoryMsgBack, syncBack);
        } else {
          requestCount = 0;
          iGetOrSyncHistoryMsgBack(list);
        }
      });
    } else {
      requestCount = 0;
      iGetOrSyncHistoryMsgBack(list);
    }
  }

  Future<int> getDeletedCount(int minMessageSeq, int maxMessageSeq,
      String channelID, int channelType) async {
    String sql =
        "select count(*) num from ${WKDBConst.tableMessage} where channel_id='$channelID' and channel_type=$channelType and message_seq>$minMessageSeq and message_seq<$maxMessageSeq and is_deleted=1";
    int num = 0;
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      num = WKDBConst.readInt(data, 'num');
    }
    return num;
  }

  Future<int> getMsgSeq(String channelID, int channelType, int oldestOrderSeq,
      int pullMode) async {
    String sql;
    int messageSeq = 0;
    if (pullMode == 1) {
      sql =
          "select message_seq from ${WKDBConst.tableMessage} where channel_id='$channelID' and channel_type=$channelType and  order_seq>$oldestOrderSeq and message_seq<>0 order by message_seq desc limit 1";
    } else {
      sql =
          "select message_seq from ${WKDBConst.tableMessage} where channel_id=$channelID and channel_type=$channelType and  order_seq<$oldestOrderSeq and message_seq<>0 order by message_seq asc limit 1";
    }

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      messageSeq = WKDBConst.readInt(data, 'message_seq');
    }
    return messageSeq;
  }

  insertMsgList(List<WKMsg> list) async {
    if (list.isEmpty) return;
    if (list.length == 1) {
      insert(list[0]);
      return;
    }
    List<WKMsg> saveList = [];
    for (int i = 0, size = list.length; i < size; i++) {
      bool isExist = false;
      for (int j = 0, len = saveList.length; j < len; j++) {
        if (list[i].clientMsgNO == saveList[j].clientMsgNO) {
          isExist = true;
          break;
        }
      }
      if (isExist) {
        list[i].clientMsgNO = WKIM.shared.messageManager.generateClientMsgNo();
        list[i].isDeleted = 1;
      }
      saveList.add(list[i]);
    }
    List<String> clientMsgNos = [];
    List<WKMsg> existMsgList = [];
    for (int i = 0, size = saveList.length; i < size; i++) {
      if (clientMsgNos.length == 200) {
        List<WKMsg> tempList = await queryWithClientMsgNos(clientMsgNos);
        if (tempList.isNotEmpty) {
          existMsgList.addAll(tempList);
        }

        clientMsgNos.clear();
      }
      if (saveList[i].clientMsgNO != '') {}
      clientMsgNos.add(saveList[i].clientMsgNO);
    }
    if (clientMsgNos.isNotEmpty) {
      List<WKMsg> tempList = await queryWithClientMsgNos(clientMsgNos);
      if (tempList.isNotEmpty) {
        existMsgList.addAll(tempList);
      }

      clientMsgNos.clear();
    }

    for (WKMsg msg in saveList) {
      for (WKMsg tempMsg in existMsgList) {
        if (tempMsg.clientMsgNO != '' &&
            msg.clientMsgNO != '' &&
            tempMsg.clientMsgNO == msg.clientMsgNO) {
          msg.isDeleted = 1;
          msg.clientMsgNO = WKIM.shared.messageManager.generateClientMsgNo();
          break;
        }
      }
    }
    //  insertMsgList(saveList);
    List<Map<String, Object>> cvList = [];
    for (WKMsg wkMsg in saveList) {
      cvList.add(getMap(wkMsg));
    }
    if (cvList.isNotEmpty) {
      WKDBHelper.shared.getDB().transaction((txn) async {
        for (int i = 0; i < cvList.length; i++) {
          txn.insert(WKDBConst.tableMessage, cvList[i]);
        }
      });
    }
  }

  Future<List<WKMsg>> queryWithClientMsgNos(List<String> clientMsgNos) async {
    List<WKMsg> msgs = [];
    StringBuffer sb = StringBuffer();
    sb.write(
        "select * from ${WKDBConst.tableMessage} where client_msg_no in (");
    for (int i = 0, size = clientMsgNos.length; i < size; i++) {
      if (i != 0) {
        sb.write(",");
      }
      sb.write("'");
      sb.write(clientMsgNos[i]);
      sb.write("'");
    }
    sb.write(")");

    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sb.toString());
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        msgs.add(WKDBConst.serializeWKMsg(data));
      }
    }
    return msgs;
  }

  Future<bool> insertOrUpdateMsgExtras(List<WKMsgExtra> list) async {
    List<String> msgIds = [];
    for (int i = 0, size = list.length; i < size; i++) {
      if (list[i].messageID != '') {
        msgIds.add(list[i].messageID);
      }
    }
    List<WKMsgExtra> existList = await queryMsgExtrasWithMsgIds(msgIds);
    List<Map<String, Object>> insertCVList = [];
    List<Map<String, Object>> updateCVList = [];
    for (int i = 0, size = list.length; i < size; i++) {
      bool isAdd = true;
      for (WKMsgExtra extra in existList) {
        if (list[i].messageID == extra.messageID) {
          updateCVList.add(getExtraMap(list[i]));
          isAdd = false;
          break;
        }
      }
      if (isAdd) {
        insertCVList.add(getExtraMap(list[i]));
      }
    }
    if (insertCVList.isNotEmpty || updateCVList.isNotEmpty) {
      WKDBHelper.shared.getDB().transaction((txn) async {
        if (insertCVList.isNotEmpty) {
          for (int i = 0; i < insertCVList.length; i++) {
            txn.insert(WKDBConst.tableMessageExtra, insertCVList[0]);
          }
          if (updateCVList.isNotEmpty) {
            for (int i = 0; i < updateCVList.length; i++) {
              txn.update(WKDBConst.tableMessageExtra, updateCVList[0],
                  where: "message_id='${updateCVList[i]['message_id']}'");
            }
          }
        }
      });
    }
    return true;
  }

  Future<int> queryMaxExtraVersionWithChannel(
      String channelID, int channelType) async {
    int extraVersion = 0;
    String sql =
        "select max(extra_version) extra_version from ${WKDBConst.tableMessageExtra} where channel_id ='$channelID' and channel_type=$channelType";
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      extraVersion = WKDBConst.readInt(data, 'extra_version');
    }
    return extraVersion;
  }

  Future<List<WKMsgExtra>> queryMsgExtrasWithMsgIds(List<String> msgIds) async {
    StringBuffer sb = StringBuffer();
    sb.write(
        "select * from ${WKDBConst.tableMessageExtra} where message_id in (");
    for (int i = 0, size = msgIds.length; i < size; i++) {
      if (i != 0) {
        sb.write(",");
      }
      sb.write("'");
      sb.write(msgIds[i]);
      sb.write("'");
    }
    sb.write(")");
    List<WKMsgExtra> list = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sb.toString());
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeMsgExtra(data));
      }
    }

    return list;
  }

  Future<List<WKMsgReaction>> queryMsgReactionWithMessageIds(
      List<String> messageIds) async {
    StringBuffer stringBuffer = StringBuffer();
    for (int i = 0, size = messageIds.length; i < size; i++) {
      if (stringBuffer.length > 0) {
        stringBuffer.write(",");
      }
      stringBuffer.write(messageIds[i]);
    }
    String sql =
        "select * from ${WKDBConst.tableMessageReaction} where message_id in ($stringBuffer) and is_deleted=0 ORDER BY created_at desc";
    List<WKMsgReaction> list = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeMsgReation(data));
      }
    }
    return list;
  }

  insertOrUpdateReactionList(List<WKMsgReaction> list) {
    if (list.isEmpty) return;
    for (int i = 0, size = list.length; i < size; i++) {
      insertOrUpdateReaction(list[i]);
    }
  }

  insertOrUpdateReaction(WKMsgReaction reaction) async {
    bool isExist = await isExistReaction(reaction.uid, reaction.messageID);
    if (isExist) {
      updateReaction(reaction);
    } else {
      insertReaction(reaction);
    }
  }

  updateReaction(WKMsgReaction reaction) {
    var map = <String, Object>{};
    map['is_deleted'] = reaction.isDeleted;
    map['seq'] = reaction.seq;
    map['emoji'] = reaction.emoji;
    WKDBHelper.shared.getDB().update(WKDBConst.tableMessageReaction, map,
        where: "message_id='${reaction.messageID}' and uid='${reaction.uid}'");
  }

  insertReaction(WKMsgReaction reaction) {
    WKDBHelper.shared
        .getDB()
        .insert(WKDBConst.tableMessageReaction, getReactionMap(reaction));
  }

  Future<bool> isExistReaction(String uid, String messageID) async {
    bool isExist = false;
    String sql =
        "select * from ${WKDBConst.tableMessageReaction} where message_id='$messageID' and uid='$uid' ";

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      isExist = true;
    }
    return isExist;
  }

  updateSendingMsgFail() {
    var map = <String, Object>{};
    map['status'] = WKSendMsgResult.sendFail;
    WKDBHelper.shared
        .getDB()
        .update(WKDBConst.tableMessage, map, where: 'status=0');
  }

  Future<WKMsg?> queryMaxOrderSeqMsgWithChannel(
      String channelID, int channelType) async {
    WKMsg? wkMsg;
    String sql =
        "select * from ${WKDBConst.tableMessage} where channel_id='$channelID' and channel_type=$channelType and is_deleted=0 and type<>0 and type<>99 order by order_seq desc limit 1";
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      if (data != null) {
        wkMsg = WKDBConst.serializeWKMsg(data);
      }
    }
    if (wkMsg != null) {
      wkMsg.reactionList = await queryReactions(wkMsg.messageID);
    }
    return wkMsg;
  }

  dynamic getMap(WKMsg msg) {
    var map = <String, Object>{};
    map['message_id'] = msg.messageID;
    map['message_seq'] = msg.messageSeq;
    map['order_seq'] = msg.orderSeq;
    map['timestamp'] = msg.timestamp;
    map['from_uid'] = msg.fromUID;
    map['channel_id'] = msg.channelID;
    map['channel_type'] = msg.channelType;
    map['is_deleted'] = msg.isDeleted;
    map['type'] = msg.contentType;
    map['content'] = msg.content;
    map['status'] = msg.status;
    map['voice_status'] = msg.voiceStatus;
    map['client_msg_no'] = msg.clientMsgNO;
    map['viewed'] = msg.viewed;
    map['viewed_at'] = msg.viewedAt;
    map['topic_id'] = msg.topicID;
    if (msg.messageContent != null) {
      map['searchable_word'] = msg.messageContent!.searchableWord();
    } else {
      map['searchable_word'] = '';
    }
    if (msg.localExtraMap != null) {
      map['extra'] = jsonEncode(msg.localExtraMap);
    } else {
      map['extra'] = '';
    }
    map['setting'] = msg.setting.encode();
    return map;
  }

  dynamic getExtraMap(WKMsgExtra extra) {
    var map = <String, Object>{};
    map['channel_id'] = extra.channelID;
    map['channel_type'] = extra.channelType;
    map['readed'] = extra.readed;
    map['readed_count'] = extra.readedCount;
    map['unread_count'] = extra.unreadCount;
    map['revoke'] = extra.revoke;
    map['revoker'] = extra.revoker;
    map['extra_version'] = extra.extraVersion;
    map['is_mutual_deleted'] = extra.isMutualDeleted;
    map['content_edit'] = extra.contentEdit;
    map['edited_at'] = extra.editedAt;
    map['need_upload'] = extra.needUpload;
    map['message_id'] = extra.messageID;
    return map;
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
