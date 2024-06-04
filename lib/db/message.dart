import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:wukongimfluttersdk/db/channel.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/reaction.dart';
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

  Future<bool> isExist(String clientMsgNo) async {
    bool isExist = false;
    List<Map<String, Object?>> list = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableMessage,
        where: "client_msg_no=?",
        whereArgs: [clientMsgNo]);
    if (list.isNotEmpty) {
      isExist = true;
    }
    return isExist;
  }

  Future<int> insert(WKMsg msg) async {
    if (msg.clientSeq != 0) {
      updateMsg(msg);
      return msg.clientSeq;
    }
    if (msg.clientMsgNO != '') {
      bool exist = await isExist(msg.clientMsgNO);
      if (exist) {
        msg.isDeleted = 1;
        msg.clientMsgNO = WKIM.shared.messageManager.generateClientMsgNo();
      }
    }
    return await WKDBHelper.shared.getDB().insert(
        WKDBConst.tableMessage, getMap(msg),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateMsg(WKMsg msg) async {
    return await WKDBHelper.shared.getDB().update(
        WKDBConst.tableMessage, getMap(msg),
        where: "client_seq=?", whereArgs: [msg.clientSeq]);
  }

  Future<int> updateMsgWithField(dynamic map, int clientSeq) async {
    return await WKDBHelper.shared.getDB().update(WKDBConst.tableMessage, map,
        where: "client_seq=?", whereArgs: [clientSeq]);
  }

  Future<int> updateMsgWithFieldAndClientMsgNo(
      dynamic map, String clientMsgNO) async {
    return await WKDBHelper.shared.getDB().update(WKDBConst.tableMessage, map,
        where: "client_msg_no=?", whereArgs: [clientMsgNO]);
  }

  Future<WKMsg?> queryWithClientMsgNo(String clientMsgNo) async {
    WKMsg? wkMsg;
    String sql =
        "select $messageCols,$extraCols from ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} ON ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.client_msg_no=?";

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql, [clientMsgNo]);
    if (list.isNotEmpty) {
      wkMsg = WKDBConst.serializeWKMsg(list[0]);
    }
    if (wkMsg != null) {
      wkMsg.reactionList =
          await ReactionDB.shared.queryWithMessageId(wkMsg.messageID);
    }
    return wkMsg;
  }

  Future<WKMsg?> queryWithClientSeq(int clientSeq) async {
    WKMsg? wkMsg;
    String sql =
        "select $messageCols,$extraCols from ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} ON ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.client_seq=?";

    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql, [clientSeq]);
    if (list.isNotEmpty) {
      wkMsg = WKDBConst.serializeWKMsg(list[0]);
    }
    if (wkMsg != null) {
      wkMsg.reactionList =
          await ReactionDB.shared.queryWithMessageId(wkMsg.messageID);
    }
    return wkMsg;
  }

  Future<List<WKMsg>> queryWithMessageIds(List<String> messageIds) async {
    String sql =
        "select $messageCols,$extraCols from ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} ON ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.message_id in (${WKDBConst.getPlaceholders(messageIds.length)})";
    List<WKMsg> list = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql, messageIds);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeWKMsg(data));
      }
    }
    return list;
  }

  Future<int> queryMaxOrderSeq(String channelID, int channelType) async {
    int maxOrderSeq = 0;
    String sql =
        "select max(order_seq) order_seq from ${WKDBConst.tableMessage} where channel_id =? and channel_type=? and type<>99 and type<>0 and is_deleted=0";
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql, [channelID, channelType]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      maxOrderSeq = WKDBConst.readInt(data, 'order_seq');
    }
    return maxOrderSeq;
  }

  Future<int> getMaxMessageSeq(String channelID, int channelType) async {
    String sql =
        "SELECT max(message_seq) message_seq FROM ${WKDBConst.tableMessage} WHERE channel_id=? AND channel_type=?";
    int messageSeq = 0;
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql, [channelID, channelType]);
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
        "select order_seq from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and type<>99 and order_seq <=? order by order_seq desc limit ?";
    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()
        .rawQuery(sql, [channelID, channelType, maxOrderSeq, limit]);
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
    var args = [];
    if (oldestOrderSeq <= 0) {
      sql =
          "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,?";
      args.add(channelId);
      args.add(channelType);
      args.add(limit);
    } else {
      if (pullMode == 0) {
        if (contain) {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq<=?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,?";
        } else {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq<?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,?";
        }
      } else {
        if (contain) {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq>=?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq asc limit 0,?";
        } else {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq>?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq asc limit 0,?";
        }
      }
      args.add(channelId);
      args.add(channelType);
      args.add(oldestOrderSeq);
      args.add(limit);
    }
    List<String> messageIds = [];
    List<String> replyMsgIds = [];
    List<String> fromUIDs = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql, args);
    if (results.isNotEmpty) {
      WKChannel? wkChannel =
          await ChannelDB.shared.query(channelId, channelType);
      for (Map<String, Object?> data in results) {
        WKMsg wkMsg = WKDBConst.serializeWKMsg(data);
        wkMsg.setChannelInfo(wkChannel);
        if (wkMsg.messageID != '') {
          messageIds.add(wkMsg.messageID);
        }

        if (wkMsg.messageContent != null &&
            wkMsg.messageContent!.reply != null &&
            wkMsg.messageContent!.reply!.messageId != '') {
          replyMsgIds.add(wkMsg.messageContent!.reply!.messageId);
        }
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
    List<WKMsgReaction> list =
        await ReactionDB.shared.queryWithMessageIds(messageIds);
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
    if (replyMsgIds.isNotEmpty) {
      List<WKMsgExtra> msgExtraList =
          await queryMsgExtrasWithMsgIds(replyMsgIds);
      if (msgExtraList.isNotEmpty) {
        for (WKMsgExtra extra in msgExtraList) {
          for (int i = 0, size = msgList.length; i < size; i++) {
            if (msgList[i].messageContent != null &&
                msgList[i].messageContent!.reply != null &&
                extra.messageID ==
                    msgList[i].messageContent!.reply!.messageId) {
              msgList[i].messageContent!.reply!.revoke = extra.revoke;
            }
            if (extra.contentEdit != '' &&
                msgList[i].messageContent != null &&
                msgList[i].messageContent!.reply != null &&
                msgList[i].messageContent!.reply!.messageId != '' &&
                extra.messageID ==
                    msgList[i].messageContent!.reply!.messageId) {
              msgList[i].messageContent!.reply!.editAt = extra.editedAt;
              msgList[i].messageContent!.reply!.contentEdit = extra.contentEdit;
              var json = jsonEncode(extra.contentEdit);
              var type = WKDBConst.readInt(json, 'type');
              msgList[i].messageContent!.reply!.contentEditMsgModel =
                  WKIM.shared.messageManager.getMessageModel(type, json);
              break;
            }
          }
        }
      }
    }
    return msgList;
  }

  var requestCount = 0;
  var isMore = 1;
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
    if (isMore == 0) {
      iGetOrSyncHistoryMsgBack(list);
      isMore = 1;
      requestCount = 0;
      return;
    }
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
    if (oldestMsgSeq == 1 || isMore == 0) {
      isMore = 1;
      requestCount = 0;
      iGetOrSyncHistoryMsgBack(list);
      return;
    }
    if (pullMode == 0) {
      //下拉获取消息
      if (maxMessageSeq != 0 &&
          oldestMsgSeq != 0 &&
          oldestMsgSeq - maxMessageSeq > 1) {
        isSyncMsg = true;
        if (contain) {
          startMsgSeq = oldestMsgSeq;
        } else {
          startMsgSeq = oldestMsgSeq - 1;
        }
        endMsgSeq = maxMessageSeq;
      }
    } else {
      //上拉获取消息
      if (minMessageSeq != 0 &&
          oldestMsgSeq != 0 &&
          minMessageSeq - oldestMsgSeq > 1) {
        isSyncMsg = true;
        if (contain) {
          startMsgSeq = oldestMsgSeq;
        } else {
          startMsgSeq = oldestMsgSeq + 1;
        }
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
                if (max > startMsgSeq) {
                  startMsgSeq = max;
                }
                if (endMsgSeq == 0 || min < endMsgSeq) {
                  endMsgSeq = min;
                }
              } else {
                if (startMsgSeq == 0 || min < startMsgSeq) {
                  startMsgSeq = min;
                }
                if (max > endMsgSeq) {
                  endMsgSeq = max;
                }
              }
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
    int syncLimit = limit;
    if (!isSyncMsg && tempList.length < limit) {
      isSyncMsg = true;
      if (contain) {
        startMsgSeq = oldestMsgSeq;
      } else {
        if (pullMode == 0) {
          startMsgSeq = oldestMsgSeq - 1;
        } else {
          startMsgSeq = oldestMsgSeq + 1;
        }
      }
      endMsgSeq = 0;
    }
    if (startMsgSeq == 0 && endMsgSeq == 0 && tempList.length < limit) {
      isSyncMsg = true;
      endMsgSeq = oldestMsgSeq;
      startMsgSeq = 0;
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
          channelId, channelType, startMsgSeq, endMsgSeq, syncLimit, pullMode,
          (syncChannelMsg) {
        if (syncChannelMsg != null &&
            syncChannelMsg.messages != null &&
            syncChannelMsg.messages!.isNotEmpty) {
          isMore = syncChannelMsg.more;
          getOrSyncHistoryMessages(channelId, channelType, oldestOrderSeq,
              contain, pullMode, limit, iGetOrSyncHistoryMsgBack, syncBack);
        } else {
          requestCount = 0;
          isMore = 1;
          iGetOrSyncHistoryMsgBack(list);
        }
      });
    } else {
      requestCount = 0;
      isMore = 1;
      iGetOrSyncHistoryMsgBack(list);
    }
  }

  Future<int> getDeletedCount(int minMessageSeq, int maxMessageSeq,
      String channelID, int channelType) async {
    String sql =
        "select count(*) num from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and message_seq>? and message_seq<? and is_deleted=1";
    int num = 0;
    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()
        .rawQuery(sql, [channelID, channelType, minMessageSeq, maxMessageSeq]);
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
          "select message_seq from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and  order_seq>? and message_seq<>0 order by message_seq desc limit 1";
    } else {
      sql =
          "select message_seq from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and  order_seq<? and message_seq<>0 order by message_seq asc limit 1";
    }

    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()
        .rawQuery(sql, [channelID, channelType, oldestOrderSeq]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      messageSeq = WKDBConst.readInt(data, 'message_seq');
    }
    return messageSeq;
  }

  Future<bool> insertMsgList(List<WKMsg> list) async {
    if (list.isEmpty) return true;
    if (list.length == 1) {
      insert(list[0]);
      return true;
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
          txn.insert(WKDBConst.tableMessage, cvList[i],
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    }
    return true;
  }

  Future<List<WKMsg>> queryWithClientMsgNos(List<String> clientMsgNos) async {
    List<WKMsg> msgs = [];
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableMessage,
        where:
            "client_msg_no in (${WKDBConst.getPlaceholders(clientMsgNos.length)})",
        whereArgs: clientMsgNos);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        msgs.add(WKDBConst.serializeWKMsg(data));
      }
    }
    return msgs;
  }

  Future<bool> insertMsgExtras(List<WKMsgExtra> list) async {
    if (list.isEmpty) {
      return true;
    }
    List<Map<String, Object>> insertCVList = [];
    for (int i = 0, size = list.length; i < size; i++) {
      insertCVList.add(getExtraMap(list[i]));
    }
    WKDBHelper.shared.getDB().transaction((txn) async {
      if (insertCVList.isNotEmpty) {
        for (int i = 0; i < insertCVList.length; i++) {
          txn.insert(WKDBConst.tableMessageExtra, insertCVList[i],
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
    return true;
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
            txn.insert(WKDBConst.tableMessageExtra, insertCVList[i],
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        if (updateCVList.isNotEmpty) {
          for (int i = 0; i < updateCVList.length; i++) {
            txn.update(WKDBConst.tableMessageExtra, updateCVList[0],
                where: "message_id=?",
                whereArgs: [updateCVList[i]['message_id']]);
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
        "select max(extra_version) extra_version from ${WKDBConst.tableMessageExtra} where channel_id =? and channel_type=?";
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql, [channelID, channelType]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      extraVersion = WKDBConst.readInt(data, 'extra_version');
    }
    return extraVersion;
  }

  Future<List<WKMsgExtra>> queryMsgExtraWithNeedUpload(int needUpload) async {
    String sql =
        "select * from ${WKDBConst.tableMessageExtra}  where need_upload=?";
    List<WKMsgExtra> list = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql, [needUpload]);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeMsgExtra(data));
      }
    }

    return list;
  }

  Future<WKMsgExtra?> queryMsgExtraWithMsgID(String messageID) async {
    WKMsgExtra? msgExtra;
    List<Map<String, Object?>> list = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableMessageExtra,
        where: "message_id=?",
        whereArgs: [messageID]);
    if (list.isNotEmpty) {
      msgExtra = WKDBConst.serializeMsgExtra(list[0]);
    }
    return msgExtra;
  }

  Future<List<WKMsgExtra>> queryMsgExtrasWithMsgIds(List<String> msgIds) async {
    List<WKMsgExtra> list = [];
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableMessageExtra,
        where: "message_id in (${WKDBConst.getPlaceholders(msgIds.length)})",
        whereArgs: msgIds);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeMsgExtra(data));
      }
    }

    return list;
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
        "select * from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and is_deleted=0 and type<>0 and type<>99 order by order_seq desc limit 1";
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB().rawQuery(sql, [channelID, channelType]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      if (data != null) {
        wkMsg = WKDBConst.serializeWKMsg(data);
      }
    }
    if (wkMsg != null) {
      wkMsg.reactionList =
          await ReactionDB.shared.queryWithMessageId(wkMsg.messageID);
    }
    return wkMsg;
  }

  Future<int> deleteWithMessageIDs(List<String> msgIds) async {
    var map = <String, Object>{};
    map['is_deleted'] = 1;
    return await WKDBHelper.shared.getDB().update(WKDBConst.tableMessage, map,
        where: "message_id in (${WKDBConst.getPlaceholders(msgIds.length)})",
        whereArgs: msgIds);
  }

  Future<int> deleteWithChannel(String channelId, int channelType) async {
    var map = <String, Object>{};
    map['is_deleted'] = 1;
    return await WKDBHelper.shared.getDB().update(WKDBConst.tableMessage, map,
        where: "channel_id=? and channel_type=?",
        whereArgs: [channelId, channelType]);
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
}
