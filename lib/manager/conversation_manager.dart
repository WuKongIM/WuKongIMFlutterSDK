import 'dart:collection';

import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/db/reaction.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../db/conversation.dart';
import '../entity/conversation.dart';
import '../type/const.dart';

class WKConversationManager {
  WKConversationManager._privateConstructor();
  static final WKConversationManager _instance =
      WKConversationManager._privateConstructor();
  static WKConversationManager get shared => _instance;

  HashMap<String, Function(WKUIConversationMsg, bool)>? _refeshMsgMap;
  HashMap<String, Function(String, int)>? _deleteMsgMap;
  HashMap<String, Function()>? _clearAllRedDotMap;

  Function(String lastSsgSeqs, int msgCount, int version,
      Function(WKSyncConversation))? _syncConersationBack;

  Future<List<WKUIConversationMsg>> getAll() async {
    return await ConversationDB.shared.queryAll();
  }

  Future<bool> deleteMsg(String channelID, int channelType) async {
    bool result = await ConversationDB.shared.delete(channelID, channelType);
    if (result) {
      _setDeleteMsg(channelID, channelType);
    }

    return result;
  }

  Future<WKUIConversationMsg?> saveWithLiMMsg(WKMsg msg) async {
    WKConversationMsg wkConversationMsg = WKConversationMsg();
    if (msg.channelType == WKChannelType.communityTopic &&
        msg.channelID != '') {
      if (msg.channelID.contains("@")) {
        var str = msg.channelID.split("@");
        wkConversationMsg.parentChannelID = str[0];
        wkConversationMsg.parentChannelType = WKChannelType.community;
      }
    }
    wkConversationMsg.channelID = msg.channelID;
    wkConversationMsg.channelType = msg.channelType;
    wkConversationMsg.localExtraMap = msg.localExtraMap;
    wkConversationMsg.lastMsgTimestamp = msg.timestamp;
    wkConversationMsg.lastClientMsgNO = msg.clientMsgNO;
    wkConversationMsg.lastMsgSeq = msg.messageSeq;
    wkConversationMsg.unreadCount = msg.header.redDot ? 1 : 0;
    WKUIConversationMsg? uiMsg = await ConversationDB.shared
        .insertOrUpdateWithConvMsg(wkConversationMsg);
    return uiMsg;
  }

  Future<int> getExtraMaxVersion() async {
    return ConversationDB.shared.queryExtraMaxVersion();
  }

  Future<WKUIConversationMsg?> getWithChannel(
      String channelID, int channelType) async {
    var msg = await ConversationDB.shared
        .queryMsgByMsgChannelId(channelID, channelType);
    if (msg != null) {
      return ConversationDB.shared.getUIMsg(msg);
    }
    return null;
  }

  clearAll() {
    ConversationDB.shared.clearAll();
  }

  clearAllRedDot() async {
    int row = await ConversationDB.shared.clearAllRedDot();
    if (row > 0) {
      _setClearAllRedDot();
    }
  }

  updateRedDot(String channelID, int channelType, int redDot) async {
    var map = <String, Object>{};
    map['unread_count'] = redDot;
    var result = await ConversationDB.shared
        .updateWithField(map, channelID, channelType);
    if (result > 0) {
      _refreshMsg(channelID, channelType);
    }
  }

  _refreshMsg(String channelID, int channelType) async {
    var msg = await ConversationDB.shared
        .queryMsgByMsgChannelId(channelID, channelType);
    if (msg != null) {
      var uiMsg = ConversationDB.shared.getUIMsg(msg);
      setRefreshMsg(uiMsg, true);
    }
  }

  addOnClearAllRedDotListener(String key, Function() back) {
    _clearAllRedDotMap ??= HashMap();
    _clearAllRedDotMap![key] = back;
  }

  removeClearAllRedDotListener(String key) {
    if (_clearAllRedDotMap != null) {
      _clearAllRedDotMap!.remove(key);
    }
  }

  _setClearAllRedDot() {
    if (_clearAllRedDotMap != null) {
      _clearAllRedDotMap!.forEach((key, back) {
        back();
      });
    }
  }

  addOnDeleteMsgListener(String key, Function(String, int) back) {
    _deleteMsgMap ??= HashMap();
    _deleteMsgMap![key] = back;
  }

  removeDeleteMsgListener(String key) {
    if (_deleteMsgMap != null) {
      _deleteMsgMap!.remove(key);
    }
  }

  _setDeleteMsg(String channelID, int channelType) {
    if (_deleteMsgMap != null) {
      _deleteMsgMap!.forEach((key, back) {
        back(channelID, channelType);
      });
    }
  }

  setRefreshMsg(WKUIConversationMsg msg, bool isEnd) {
    if (_refeshMsgMap != null) {
      _refeshMsgMap!.forEach((key, back) {
        back(msg, isEnd);
      });
    }
  }

  addOnRefreshMsgListener(
      String key, Function(WKUIConversationMsg, bool) back) {
    _refeshMsgMap ??= HashMap();
    _refeshMsgMap![key] = back;
  }

  removeOnRefreshMsg(String key) {
    if (_refeshMsgMap != null) {
      _refeshMsgMap!.remove(key);
    }
  }

  addOnSyncConversationListener(
      Function(String lastSsgSeqs, int msgCount, int version,
              Function(WKSyncConversation))
          back) {
    _syncConersationBack = back;
  }

  setSyncConversation(Function() back) async {
    WKIM.shared.connectionManager
        .setConnectionStatus(WKConnectStatus.syncMsg, 'sync_conversation_msgs');
    if (_syncConersationBack != null) {
      int version = await ConversationDB.shared.getMaxVersion();
      String lastMsgSeqStr = await ConversationDB.shared.getLastMsgSeqs();
      _syncConersationBack!(lastMsgSeqStr, 200, version, (msgs) {
        _saveSyncCoversation(msgs);
        back();
      });
    }
  }

  _saveSyncCoversation(WKSyncConversation? syncChat) {
    if (syncChat == null ||
        syncChat.conversations == null ||
        syncChat.conversations!.isEmpty) {
      return;
    }
    List<WKConversationMsg> conversationMsgList = [];
    List<WKMsg> msgList = [];
    List<WKMsgReaction> msgReactionList = [];
    List<WKMsgExtra> msgExtraList = [];
    List<WKUIConversationMsg> uiMsgList = [];
    if (syncChat.conversations != null && syncChat.conversations!.isNotEmpty) {
      for (int i = 0, size = syncChat.conversations!.length; i < size; i++) {
        WKConversationMsg conversationMsg = WKConversationMsg();

        int channelType = syncChat.conversations![i].channelType;
        String channelID = syncChat.conversations![i].channelID;
        if (channelType == WKChannelType.communityTopic) {
          var str = channelID.split("@");
          conversationMsg.parentChannelID = str[0];
          conversationMsg.parentChannelType = WKChannelType.community;
        }
        conversationMsg.channelID = syncChat.conversations![i].channelID;
        conversationMsg.channelType = syncChat.conversations![i].channelType;
        conversationMsg.lastMsgSeq = syncChat.conversations![i].lastMsgSeq;
        conversationMsg.lastClientMsgNO =
            syncChat.conversations![i].lastClientMsgNO;
        conversationMsg.lastMsgTimestamp = syncChat.conversations![i].timestamp;
        conversationMsg.unreadCount = syncChat.conversations![i].unread;
        conversationMsg.version = syncChat.conversations![i].version;
        WKUIConversationMsg uiMsg =
            ConversationDB.shared.getUIMsg(conversationMsg);
        //聊天消息对象
        if (syncChat.conversations![i].recents != null &&
            syncChat.conversations![i].recents!.isNotEmpty) {
          for (WKSyncMsg wkSyncRecent in syncChat.conversations![i].recents!) {
            WKMsg msg = wkSyncRecent.getWKMsg();
            if (msg.reactionList != null && msg.reactionList!.isNotEmpty) {
              msgReactionList.addAll(msg.reactionList!);
            }
            //判断会话列表的fromUID
            if (conversationMsg.lastClientMsgNO == msg.clientMsgNO) {
              conversationMsg.isDeleted = msg.isDeleted;
              uiMsg.isDeleted = conversationMsg.isDeleted;
              uiMsg.setWkMsg(msg);
            }
            if (wkSyncRecent.messageExtra != null) {
              WKMsgExtra extra = WKIM.shared.messageManager
                  .wkSyncExtraMsg2WKMsgExtra(msg.channelID, msg.channelType,
                      wkSyncRecent.messageExtra!);
              msgExtraList.add(extra);
            }
            msgList.add(msg);
          }
        }
        conversationMsgList.add(conversationMsg);
        uiMsgList.add(uiMsg);
      }
    }
    if (msgExtraList.isNotEmpty) {
      MessageDB.shared.insertOrUpdateMsgExtras(msgExtraList);
    }

    if (msgList.isNotEmpty) {
      MessageDB.shared.insertMsgList(msgList);
    }
    if (conversationMsgList.isNotEmpty) {
      ConversationDB.shared.insertMsgList(conversationMsgList);
    }
    if (msgReactionList.isNotEmpty) {
      ReactionDB.shared.insertOrUpdateReactionList(msgReactionList);
    }
    if (msgList.isNotEmpty && msgList.length < 20) {
      msgList.sort((a, b) => a.messageSeq.compareTo(b.messageSeq));
      WKIM.shared.messageManager.pushNewMsg(msgList);
    }
    if (uiMsgList.isNotEmpty) {
      for (int i = 0, size = uiMsgList.length; i < size; i++) {
        WKIM.shared.conversationManager
            .setRefreshMsg(uiMsgList[i], i == uiMsgList.length - 1);
      }
    }
    if (syncChat.cmds != null && syncChat.cmds!.isNotEmpty) {
      for (int i = 0, size = syncChat.cmds!.length; i < size; i++) {
        dynamic json = <String, dynamic>{};
        json['cmd'] = syncChat.cmds![i].cmd;
        json['param'] = syncChat.cmds![i].param;
        WKIM.shared.cmdManager.handleCMD(json);
      }
    }
  }
}
