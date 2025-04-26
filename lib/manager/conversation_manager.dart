import 'dart:collection';

import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/db/reaction.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../db/conversation.dart';
import '../entity/conversation.dart';
import '../type/const.dart';

/// 会话管理器，负责管理和维护会话数据
class WKConversationManager {
  WKConversationManager._privateConstructor() {
    _refreshMsgMap = HashMap<String, Function(WKUIConversationMsg, bool)>();
    _refreshMsgListMap = HashMap<String, Function(List<WKUIConversationMsg>)>();
    _deleteMsgMap = HashMap<String, Function(String, int)>();
    _clearAllRedDotMap = HashMap<String, Function()>();
  }
  
  static final WKConversationManager _instance =
      WKConversationManager._privateConstructor();
  static WKConversationManager get shared => _instance;

  /// 单个会话刷新监听器
  late final HashMap<String, Function(WKUIConversationMsg, bool)> _refreshMsgMap;
  
  /// 会话列表刷新监听器
  late final HashMap<String, Function(List<WKUIConversationMsg>)> _refreshMsgListMap;
  
  /// 会话删除监听器
  late final HashMap<String, Function(String, int)> _deleteMsgMap;
  
  /// 清除所有红点监听器
  late final HashMap<String, Function()> _clearAllRedDotMap;

  /// 同步会话回调
  Function(String lastSsgSeqs, int msgCount, int version,
      Function(WKSyncConversation))? _syncConversationBack;

  /// 获取所有会话
  Future<List<WKUIConversationMsg>> getAll() async {
    return await ConversationDB.shared.queryAll();
  }

  /// 删除指定频道的会话
  Future<bool> deleteMsg(String channelID, int channelType) async {
    bool result = await ConversationDB.shared.delete(channelID, channelType);
    if (result) {
      _notifyDeleteMsg(channelID, channelType);
    }
    return result;
  }

  /// 根据消息保存会话
  Future<WKUIConversationMsg?> saveWithLiMMsg(WKMsg msg, int redDot) async {
    WKConversationMsg wkConversationMsg = WKConversationMsg();
    if (msg.channelType == WKChannelType.communityTopic &&
        msg.channelID.isNotEmpty) {
      if (msg.channelID.contains("@")) {
        var str = msg.channelID.split("@");
        wkConversationMsg.parentChannelID = str[0];
        wkConversationMsg.parentChannelType = WKChannelType.community;
      }
    }
    wkConversationMsg.channelID = msg.channelID;
    wkConversationMsg.channelType = msg.channelType;
    wkConversationMsg.lastMsgTimestamp = msg.timestamp;
    wkConversationMsg.lastClientMsgNO = msg.clientMsgNO;
    wkConversationMsg.lastMsgSeq = msg.messageSeq;
    wkConversationMsg.unreadCount = redDot;
    WKUIConversationMsg? uiMsg = await ConversationDB.shared
        .insertOrUpdateWithConvMsg(wkConversationMsg);
    return uiMsg;
  }

  /// 获取所有未读消息总数
  Future<int> getAllUnreadCount() async {
    return ConversationDB.shared.queryAllUnreadCount();
  }

  /// 获取扩展信息的最大版本号
  Future<int> getExtraMaxVersion() async {
    return ConversationDB.shared.queryExtraMaxVersion();
  }

  /// 获取指定频道的会话
  Future<WKUIConversationMsg?> getWithChannel(
      String channelID, int channelType) async {
    var msg = await ConversationDB.shared
        .queryMsgByMsgChannelId(channelID, channelType);
    if (msg != null) {
      return ConversationDB.shared.getUIMsg(msg);
    }
    return null;
  }

  /// 清除所有会话
  Future<void> clearAll() async {
    await ConversationDB.shared.clearAll();
  }

  /// 清除所有会话的未读数
  Future<void> clearAllRedDot() async {
    int row = await ConversationDB.shared.clearAllRedDot();
    if (row > 0) {
      _notifyClearAllRedDot();
    }
  }

  /// 更新指定频道的未读数
  Future<void> updateRedDot(String channelID, int channelType, int redDot) async {
    var map = <String, Object>{};
    map['unread_count'] = redDot;
    var result = await ConversationDB.shared
        .updateWithField(map, channelID, channelType);
    if (result > 0) {
      await _refreshChannelMsg(channelID, channelType);
    }
  }

  /// 刷新指定频道的会话
  Future<void> _refreshChannelMsg(String channelID, int channelType) async {
    var msg = await ConversationDB.shared
        .queryMsgByMsgChannelId(channelID, channelType);
    if (msg != null) {
      var uiMsg = ConversationDB.shared.getUIMsg(msg);
      List<WKUIConversationMsg> uiMsgs = [uiMsg];
      setRefreshUIMsgs(uiMsgs);
    }
  }

  /// 添加清除所有红点监听器
  void addOnClearAllRedDotListener(String key, Function() listener) {
    _clearAllRedDotMap[key] = listener;
  }

  /// 移除清除所有红点监听器
  void removeClearAllRedDotListener(String key) {
    _clearAllRedDotMap.remove(key);
  }

  /// 通知清除所有红点
  void _notifyClearAllRedDot() {
    _clearAllRedDotMap.forEach((_, listener) {
      listener();
    });
  }

  /// 添加会话删除监听器
  void addOnDeleteMsgListener(String key, Function(String, int) listener) {
    _deleteMsgMap[key] = listener;
  }

  /// 移除会话删除监听器
  void removeDeleteMsgListener(String key) {
    _deleteMsgMap.remove(key);
  }

  /// 通知会话已删除
  void _notifyDeleteMsg(String channelID, int channelType) {
    _deleteMsgMap.forEach((_, listener) {
      listener(channelID, channelType);
    });
  }

  /// 通知刷新单个会话
  void _notifyRefreshMsg(WKUIConversationMsg msg, bool isEnd) {
    _refreshMsgMap.forEach((_, listener) {
      listener(msg, isEnd);
    });
  }

  /// 添加会话刷新监听器（已废弃）
  @Deprecated("请使用 addOnRefreshMsgListListener 方法替代")
  void addOnRefreshMsgListener(
      String key, Function(WKUIConversationMsg, bool) listener) {
    _refreshMsgMap[key] = listener;
  }

  /// 移除会话刷新监听器
  void removeOnRefreshMsg(String key) {
    _refreshMsgMap.remove(key);
  }

  /// 刷新会话UI列表
  void setRefreshUIMsgs(List<WKUIConversationMsg> msgs) {
    _notifyRefreshMsgList(msgs);
    for (int i = 0, size = msgs.length; i < size; i++) {
      _notifyRefreshMsg(msgs[i], i == msgs.length - 1);
    }
  }

  /// 通知刷新会话列表
  void _notifyRefreshMsgList(List<WKUIConversationMsg> msgs) {
    _refreshMsgListMap.forEach((_, listener) {
      listener(msgs);
    });
  }

  /// 添加会话列表刷新监听器
  void addOnRefreshMsgListListener(
      String key, Function(List<WKUIConversationMsg>) listener) {
    _refreshMsgListMap[key] = listener;
  }

  /// 移除会话列表刷新监听器
  void removeOnRefreshMsgListListener(String key) {
    _refreshMsgListMap.remove(key);
  }

  /// 添加同步会话监听器
  void addOnSyncConversationListener(
      Function(String lastSsgSeqs, int msgCount, int version,
              Function(WKSyncConversation))
          listener) {
    _syncConversationBack = listener;
  }

  /// 触发同步会话操作
  Future<void> setSyncConversation(Function() callback) async {
    WKIM.shared.connectionManager.setConnectionStatus(WKConnectStatus.syncMsg);
    if (_syncConversationBack != null) {
      int version = await ConversationDB.shared.getMaxVersion();
      String lastMsgSeqStr = await ConversationDB.shared.getLastMsgSeqs();
      _syncConversationBack!(lastMsgSeqStr, 200, version, (msgs) {
        _saveSyncConversation(msgs);
        callback();
      });
    }
  }

  /// 保存同步的会话数据
  void _saveSyncConversation(WKSyncConversation? syncChat) {
    if (syncChat == null ||
        syncChat.conversations == null ||
        syncChat.conversations!.isEmpty) {
      return;
    }
    
    // 初始化数据集合
    List<WKConversationMsg> conversationMsgList = [];
    List<WKMsg> msgList = [];
    List<WKMsgReaction> msgReactionList = [];
    List<WKMsgExtra> msgExtraList = [];
    List<WKUIConversationMsg> uiMsgList = [];
    
    // 处理同步的会话数据
    if (syncChat.conversations != null && syncChat.conversations!.isNotEmpty) {
      for (int i = 0, size = syncChat.conversations!.length; i < size; i++) {
        WKConversationMsg conversationMsg = WKConversationMsg();

        int channelType = syncChat.conversations![i].channelType;
        String channelID = syncChat.conversations![i].channelID;
        
        // 处理社区主题频道
        if (channelType == WKChannelType.communityTopic) {
          var str = channelID.split("@");
          conversationMsg.parentChannelID = str[0];
          conversationMsg.parentChannelType = WKChannelType.community;
        }
        
        // 设置会话属性
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
            
        // 处理最近消息
        if (syncChat.conversations![i].recents != null &&
            syncChat.conversations![i].recents!.isNotEmpty) {
          for (WKSyncMsg wkSyncRecent in syncChat.conversations![i].recents!) {
            WKMsg msg = wkSyncRecent.getWKMsg();
            
            // 处理反应列表
            if (msg.reactionList != null && msg.reactionList!.isNotEmpty) {
              msgReactionList.addAll(msg.reactionList!);
            }
            
            // 判断会话列表的fromUID
            if (conversationMsg.lastClientMsgNO == msg.clientMsgNO) {
              conversationMsg.isDeleted = msg.isDeleted;
              uiMsg.isDeleted = conversationMsg.isDeleted;
              uiMsg.setWkMsg(msg);
            }
            
            // 处理消息扩展信息
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
    
    // 保存各类数据到数据库
    if (msgExtraList.isNotEmpty) {
      MessageDB.shared.insertMsgExtras(msgExtraList);
    }

    if (msgList.isNotEmpty) {
      MessageDB.shared.insertMsgList(msgList);
    }
    
    if (conversationMsgList.isNotEmpty) {
      ConversationDB.shared.insetMsgs(conversationMsgList);
    }
    
    if (msgReactionList.isNotEmpty) {
      ReactionDB.shared.insertOrUpdateReactionList(msgReactionList);
    }
    
    // 消息少于20条时，按顺序推送新消息
    if (msgList.isNotEmpty && msgList.length < 20) {
      msgList.sort((a, b) => a.messageSeq.compareTo(b.messageSeq));
      WKIM.shared.messageManager.pushNewMsg(msgList);
    }
    
    // 刷新会话UI
    if (uiMsgList.isNotEmpty) {
      setRefreshUIMsgs(uiMsgList);
    }
    
    // 处理命令
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
