import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:wukongimfluttersdk/common/logs.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/conversation.dart';
import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/db/reaction.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_media_message_content.dart';
import 'package:wukongimfluttersdk/proto/proto.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../entity/channel.dart';
import '../entity/conversation.dart';
import '../model/wk_message_content.dart';
import '../model/wk_unknown_content.dart';
import '../wkim.dart';

class WKMessageManager {
  WKMessageManager._privateConstructor();
  static final WKMessageManager _instance =
      WKMessageManager._privateConstructor();
  static WKMessageManager get shared => _instance;

  final Map<int, WKMessageContent Function(dynamic data)> _msgContentList =
      HashMap<int, WKMessageContent Function(dynamic data)>();
  Function(WKMsg wkMsg, Function(bool isSuccess, WKMsg wkMsg))?
      _uploadAttachmentBack;
  Function(WKMsg liMMsg)? _msgInsertedBack;
  Function(WKMsgExtra)? _iUploadMsgExtraListener;
  HashMap<String, Function(List<WKMsg>)>? _newMsgBack;
  HashMap<String, Function(WKMsg)>? _refreshMsgBack;
  HashMap<String, Function(String)>? _deleteMsgBack;
  HashMap<String, Function(String, int)>? _clearChannelMsgBack;
  Function(
      String channelID,
      int channelType,
      int startMessageSeq,
      int endMessageSeq,
      int limit,
      int pullMode,
      Function(WKSyncChannelMsg?) back)? _syncChannelMsgBack;

  final int wkOrderSeqFactor = 1000;

  registerMsgContent(
      int type, WKMessageContent Function(dynamic data) createMsgContent) {
    _msgContentList[type] = createMsgContent;
  }

  WKMessageContent? getMessageModel(int type, dynamic json) {
    WKMessageContent? content;
    if (_msgContentList.containsKey(type)) {
      var messageCreateCallback = _msgContentList[type];
      if (messageCreateCallback != null) {
        content = messageCreateCallback(json);
      }
    }
    content ??= WKUnknownContent();
    // 回复
    var replyJson = json['reply'];
    if (replyJson != null) {
      var reply = WKReply().decode(replyJson);
      content.reply = reply;
    }
    // var entities = WKDBConst.readString(json, 'entities');
    var jsonArray = json['entities'];
    if (jsonArray != null) {
      // var jsonArray = jsonDecode(entities);
      List<WKMsgEntity> list = [];
      for (var entityJson in jsonArray) {
        WKMsgEntity entity = WKMsgEntity();
        entity.type = WKDBConst.readString(entityJson, 'type');
        entity.offset = WKDBConst.readInt(entityJson, 'offset');
        entity.length = WKDBConst.readInt(entityJson, 'length');
        entity.value = WKDBConst.readString(entityJson, 'value');
        list.add(entity);
      }
      content.entities = list;
    }
    // 解析艾特
    var mentionJson = json['mention'];
    if (mentionJson != null) {
      var mentionInfo = WKMentionInfo();
      var mentionAll = WKDBConst.readInt(mentionJson, 'all');
      var uidList = mentionJson['uids'];
      if (uidList != null) {
        List<String> uids = [];
        for (var uid in uidList) {
          uids.add(uid);
          if (uid == WKIM.shared.options.uid) {
            mentionInfo.isMentionMe = true;
          }
        }
        mentionInfo.uids = uids;
      }
      if (mentionAll == 1) {
        mentionInfo.mentionAll = true;
        mentionInfo.isMentionMe = true;
      }
      content.mentionInfo = mentionInfo;
    }
    return content;
  }

  parsingMsg(WKMsg wkMsg) {
    if (wkMsg.content == '') {
      wkMsg.contentType = WkMessageContentType.contentFormatError;
      return;
    }
    dynamic json = jsonDecode(wkMsg.content);
    if (json == null) {
      wkMsg.contentType = WkMessageContentType.contentFormatError;
      return;
    }
    if (wkMsg.fromUID == "") {
      wkMsg.fromUID = WKDBConst.readString(json, 'from_uid');
    }
    if (wkMsg.channelType == WKChannelType.personal &&
        wkMsg.channelID != '' &&
        wkMsg.fromUID != '' &&
        wkMsg.channelID == WKIM.shared.options.uid) {
      wkMsg.channelID = wkMsg.fromUID;
    }
    if (wkMsg.contentType == WkMessageContentType.insideMsg) {
      if (json != null) {
        json['channel_id'] = wkMsg.channelID;
        json['channel_type'] = wkMsg.channelType;
      }
      WKIM.shared.cmdManager.handleCMD(json);
    }
  }

  Future<WKMsg?> getWithClientMsgNo(String clientMsgNo) {
    return MessageDB.shared.queryWithClientMsgNo(clientMsgNo);
  }

  Future<int> saveMsg(WKMsg msg) async {
    return await MessageDB.shared.insert(msg);
  }

  String generateClientMsgNo() {
    return "${const Uuid().v4().toString().replaceAll("-", "")}5";
  }

  Future<int> getMessageOrderSeq(
      int messageSeq, String channelID, int channelType) async {
    if (messageSeq == 0) {
      int tempOrderSeq =
          await MessageDB.shared.queryMaxOrderSeq(channelID, channelType);
      return tempOrderSeq + 1;
    }
    return messageSeq * wkOrderSeqFactor;
  }

  Future<int> updateViewedAt(int viewedAt, String clientMsgNO) async {
    dynamic json = <String, Object>{};
    json['viewed'] = 1;
    json['viewed_at'] = viewedAt;
    return MessageDB.shared.updateMsgWithFieldAndClientMsgNo(json, clientMsgNO);
  }

  Future<int> getMaxExtraVersionWithChannel(
      String channelID, int channelType) async {
    return MessageDB.shared
        .queryMaxExtraVersionWithChannel(channelID, channelType);
  }

  saveRemoteExtraMsg(List<WKMsgExtra> list) async {
    MessageDB.shared.insertMsgExtras(list);
    List<String> msgIds = [];
    List<String> deletedMsgIds = [];
    for (var extra in list) {
      msgIds.add(extra.messageID);
      if (extra.isMutualDeleted == 1) {
        deletedMsgIds.add(extra.messageID);
      }
    }
    var msgList = await MessageDB.shared.queryWithMessageIds(msgIds);
    for (var msg in msgList) {
      for (var extra in list) {
        msg.wkMsgExtra ??= WKMsgExtra();
        if (msg.messageID == extra.messageID) {
          msg.wkMsgExtra!.readed = extra.readed;
          msg.wkMsgExtra!.readedCount = extra.readedCount;
          msg.wkMsgExtra!.unreadCount = extra.unreadCount;
          msg.wkMsgExtra!.revoke = extra.revoke;
          msg.wkMsgExtra!.revoker = extra.revoker;
          msg.wkMsgExtra!.isMutualDeleted = extra.isMutualDeleted;
          msg.wkMsgExtra!.editedAt = extra.editedAt;
          msg.wkMsgExtra!.contentEdit = extra.contentEdit;
          msg.wkMsgExtra!.extraVersion = extra.extraVersion;
          if (extra.contentEdit != '') {
            dynamic contentJson = jsonDecode(extra.contentEdit);
            msg.wkMsgExtra!.messageContent = WKIM.shared.messageManager
                .getMessageModel(WkMessageContentType.text, contentJson);
          }
          break;
        }
      }
      setRefreshMsg(msg);
    }
    if (deletedMsgIds.isNotEmpty) {
      MessageDB.shared.deleteWithMessageIDs(deletedMsgIds);
    }
  }

  void setSyncChannelMsgListener(
      String channelID,
      int channelType,
      int startMessageSeq,
      int endMessageSeq,
      int limit,
      int pullMode,
      Function(WKSyncChannelMsg?) back) async {
    if (_syncChannelMsgBack != null) {
      _syncChannelMsgBack!(channelID, channelType, startMessageSeq,
          endMessageSeq, limit, pullMode, (result) async {
        if (result != null && result.messages != null) {
          _saveSyncChannelMSGs(result.messages!).then((value) => back(result));
        } else {
          back(result);
        }
      });
    }
  }

  Future<bool> _saveSyncChannelMSGs(List<WKSyncMsg> list) async {
    List<WKMsg> msgList = [];
    List<WKMsgExtra> msgExtraList = [];
    List<WKMsgReaction> msgReactionList = [];
    for (int j = 0, len = list.length; j < len; j++) {
      WKMsg wkMsg = list[j].getWKMsg();
      msgList.add(wkMsg);
      if (list[j].messageExtra != null) {
        WKMsgExtra extra = wkSyncExtraMsg2WKMsgExtra(
            wkMsg.channelID, wkMsg.channelType, list[j].messageExtra!);
        msgExtraList.add(extra);
      }
      if (wkMsg.reactionList != null && wkMsg.reactionList!.isNotEmpty) {
        msgReactionList.addAll(wkMsg.reactionList!);
      }
    }
    bool isSuccess = true;
    if (msgExtraList.isNotEmpty) {
      isSuccess = await MessageDB.shared.insertMsgExtras(msgExtraList);
    }
    if (msgList.isNotEmpty) {
      isSuccess = await MessageDB.shared.insertMsgList(msgList);
    }
    if (msgReactionList.isNotEmpty) {
      isSuccess =
          await ReactionDB.shared.insertOrUpdateReactionList(msgReactionList);
    }
    return isSuccess;
  }

  WKMsgExtra wkSyncExtraMsg2WKMsgExtra(
      String channelID, int channelType, WKSyncExtraMsg extraMsg) {
    WKMsgExtra extra = WKMsgExtra();
    extra.channelID = channelID;
    extra.channelType = channelType;
    extra.unreadCount = extraMsg.unreadCount;
    extra.readedCount = extraMsg.readedCount;
    extra.readed = extraMsg.readed;
    extra.messageID = extraMsg.messageIdStr;
    extra.isMutualDeleted = extraMsg.isMutualDeleted;
    extra.extraVersion = extraMsg.extraVersion;
    extra.revoke = extraMsg.revoke;
    extra.revoker = extraMsg.revoker;
    extra.needUpload = 0;
    if (extraMsg.contentEdit != null) {
      extra.contentEdit = jsonEncode(extraMsg.contentEdit);
    }

    extra.editedAt = extraMsg.editedAt;
    return extra;
  }

  saveMessageReactions(List<WKSyncMsgReaction> list) async {
    if (list.isEmpty) return;
    List<WKMsgReaction> reactionList = [];
    List<String> msgIds = [];
    for (int i = 0, size = list.length; i < size; i++) {
      WKMsgReaction reaction = WKMsgReaction();
      reaction.messageID = list[i].messageID;
      reaction.channelID = list[i].channelID;
      reaction.channelType = list[i].channelType;
      reaction.uid = list[i].uid;
      reaction.name = list[i].name;
      reaction.seq = list[i].seq;
      reaction.emoji = list[i].emoji;
      reaction.isDeleted = list[i].isDeleted;
      reaction.createdAt = list[i].createdAt;
      msgIds.add(reaction.messageID);
      reactionList.add(reaction);
    }
    ReactionDB.shared.insertOrUpdateReactionList(reactionList);
    List<WKMsg> msgList = await MessageDB.shared.queryWithMessageIds(msgIds);
    getMsgReactionsAndRefreshMsg(msgIds, msgList);
  }

  getMsgReactionsAndRefreshMsg(
      List<String> messageIds, List<WKMsg> updatedMsgList) async {
    List<WKMsgReaction> reactionList =
        await ReactionDB.shared.queryWithMessageIds(messageIds);
    for (int i = 0, size = updatedMsgList.length; i < size; i++) {
      for (int j = 0, len = reactionList.length; j < len; j++) {
        if (updatedMsgList[i].messageID == reactionList[j].messageID) {
          if (updatedMsgList[i].reactionList == null) {
            updatedMsgList[i].reactionList = [];
          }
          updatedMsgList[i].reactionList!.add(reactionList[j]);
        }
      }
      setRefreshMsg(updatedMsgList[i]);
    }
  }

  /*
     * 查询或同步某个频道消息
     *
     * @param channelId                频道ID
     * @param channelType              频道类型
     * @param oldestOrderSeq           最后一次消息大orderSeq 第一次进入聊天传入0
     * @param contain                  是否包含 oldestOrderSeq 这条消息
     * @param pullMode                 拉取模式 0:向下拉取 1:向上拉取
     * @param aroundMsgOrderSeq        查询此消息附近消息
     * @param limit                    每次获取数量
     * @param iGetOrSyncHistoryMsgBack 请求返还
     */
  getOrSyncHistoryMessages(
      String channelId,
      int channelType,
      int oldestOrderSeq,
      bool contain,
      int pullMode,
      int limit,
      int aroundMsgOrderSeq,
      final Function(List<WKMsg>) iGetOrSyncHistoryMsgBack,
      final Function() syncBack) async {
    if (aroundMsgOrderSeq != 0) {
      int maxMsgSeq = await getMaxMessageSeq(channelId, channelType);
      int aroundMsgSeq = getOrNearbyMsgSeq(aroundMsgOrderSeq);

      if (maxMsgSeq >= aroundMsgSeq && maxMsgSeq - aroundMsgSeq <= limit) {
        // 显示最后一页数据
//                oldestOrderSeq = 0;
        oldestOrderSeq =
            await getMessageOrderSeq(maxMsgSeq, channelId, channelType);
        contain = true;
        pullMode = 0;
      } else {
        int minOrderSeq = await MessageDB.shared
            .getOrderSeq(channelId, channelType, aroundMsgOrderSeq, 3);
        if (minOrderSeq == 0) {
          oldestOrderSeq = aroundMsgOrderSeq;
        } else {
          if (minOrderSeq + limit < aroundMsgOrderSeq) {
            if (aroundMsgOrderSeq % wkOrderSeqFactor == 0) {
              oldestOrderSeq = ((aroundMsgOrderSeq / wkOrderSeqFactor - 3) *
                      wkOrderSeqFactor)
                  .toInt();
            } else {
              oldestOrderSeq = aroundMsgOrderSeq - 3;
            }
          } else {
            // todo 这里只会查询3条数据  oldestOrderSeq = minOrderSeq
            int startOrderSeq = await MessageDB.shared
                .getOrderSeq(channelId, channelType, aroundMsgOrderSeq, limit);
            if (startOrderSeq == 0) {
              oldestOrderSeq = aroundMsgOrderSeq;
            } else {
              oldestOrderSeq = startOrderSeq;
            }
          }
        }
        pullMode = 1;
        contain = true;
      }
    }
    MessageDB.shared.getOrSyncHistoryMessages(
        channelId,
        channelType,
        oldestOrderSeq,
        contain,
        pullMode,
        limit,
        iGetOrSyncHistoryMsgBack,
        syncBack);
  }

  int getOrNearbyMsgSeq(int orderSeq) {
    if (orderSeq % wkOrderSeqFactor == 0) {
      return orderSeq ~/ wkOrderSeqFactor;
    }
    return (orderSeq - orderSeq % wkOrderSeqFactor) ~/ wkOrderSeqFactor;
  }

  Future<int> getMaxMessageSeq(String channelID, int channelType) {
    return MessageDB.shared.getMaxMessageSeq(channelID, channelType);
  }

  pushNewMsg(List<WKMsg> list) {
    if (_newMsgBack != null) {
      _newMsgBack!.forEach((key, back) {
        back(list);
      });
    }
  }

  addOnNewMsgListener(String key, Function(List<WKMsg>) newMsgListener) {
    _newMsgBack ??= HashMap();
    if (key != '') {
      _newMsgBack![key] = newMsgListener;
    }
  }

  removeNewMsgListener(String key) {
    if (_newMsgBack != null) {
      _newMsgBack!.remove(key);
    }
  }

  addOnClearChannelMsgListener(String key, Function(String, int) back) {
    _clearChannelMsgBack ??= HashMap();
    if (key != '') {
      _clearChannelMsgBack![key] = back;
    }
  }

  removeClearChannelMsgListener(String key) {
    if (_clearChannelMsgBack != null) {
      _clearChannelMsgBack!.remove(key);
    }
  }

  _setClearChannelMsg(String channelID, int channelType) {
    if (_clearChannelMsgBack != null) {
      _clearChannelMsgBack!.forEach((key, back) {
        back(channelID, channelType);
      });
    }
  }

  addOnDeleteMsgListener(String key, Function(String) back) {
    _deleteMsgBack ??= HashMap();
    if (key != '') {
      _deleteMsgBack![key] = back;
    }
  }

  removeDeleteMsgListener(String key) {
    if (_deleteMsgBack != null) {
      _deleteMsgBack!.remove(key);
    }
  }

  _setDeleteMsg(String clientMsgNo) {
    if (_deleteMsgBack != null) {
      _deleteMsgBack!.forEach((key, back) {
        back(clientMsgNo);
      });
    }
  }

  _setUploadMsgExtra(WKMsgExtra extra) {
    if (_iUploadMsgExtraListener != null) {
      _iUploadMsgExtraListener!(extra);
    }
    Future.delayed(const Duration(seconds: 5), () {
      _startCheckTimer();
    });
  }

  Timer? checkMsgNeedUploadTimer;
  _startCheckTimer() {
    _stopCheckMsgNeedUploadTimer();
    checkMsgNeedUploadTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      var list = await MessageDB.shared.queryMsgExtraWithNeedUpload(1);
      if (list.isNotEmpty) {
        for (var extra in list) {
          if (_iUploadMsgExtraListener != null) {
            _iUploadMsgExtraListener!(extra);
          }
        }
      } else {
        _stopCheckMsgNeedUploadTimer();
      }
    });
  }

  _stopCheckMsgNeedUploadTimer() {
    if (checkMsgNeedUploadTimer != null) {
      checkMsgNeedUploadTimer!.cancel();
      checkMsgNeedUploadTimer = null;
    }
  }

  addOnUploadMsgExtra(Function(WKMsgExtra) back) {
    _iUploadMsgExtraListener = back;
  }

  addOnRefreshMsgListener(String key, Function(WKMsg) back) {
    _refreshMsgBack ??= HashMap();
    if (key != '') {
      _refreshMsgBack![key] = back;
    }
  }

  removeOnRefreshMsgListener(String key) {
    if (_refreshMsgBack != null) {
      _refreshMsgBack!.remove(key);
    }
  }

  setRefreshMsg(WKMsg wkMsg) {
    if (_refreshMsgBack != null) {
      _refreshMsgBack!.forEach((key, back) {
        back(wkMsg);
      });
    }
  }

  addOnSyncChannelMsgListener(
      Function(
              String channelID,
              int channelType,
              int startMessageSeq,
              int endMessageSeq,
              int limit,
              int pullMode,
              Function(WKSyncChannelMsg?) back)?
          syncChannelMsgListener) {
    _syncChannelMsgBack = syncChannelMsgListener;
  }

  setOnMsgInserted(WKMsg wkMsg) {
    if (_msgInsertedBack != null) {
      _msgInsertedBack!(wkMsg);
    }
  }

  addOnMsgInsertedListener(Function(WKMsg) insertListener) {
    _msgInsertedBack = insertListener;
  }

  addOnUploadAttachmentListener(Function(WKMsg, Function(bool, WKMsg)) back) {
    _uploadAttachmentBack = back;
  }

  sendMessage(WKMessageContent messageContent, WKChannel channel) async {
    var header = MessageHeader();
    header.redDot = true;
    sendMessageWithSettingAndHeader(messageContent, channel, Setting(), header);
  }

  sendMessageWithSetting(
      WKMessageContent messageContent, WKChannel channel, Setting setting) {
    var header = MessageHeader();
    header.redDot = true;
    sendMessageWithSettingAndHeader(messageContent, channel, setting, header);
  }

  sendMessageWithSettingAndHeader(WKMessageContent messageContent,
      WKChannel channel, Setting setting, MessageHeader header) async {
    WKMsg wkMsg = WKMsg();
    wkMsg.setting = setting;
    wkMsg.header = header;
    wkMsg.messageContent = messageContent;
    wkMsg.topicID = messageContent.topicId;
    wkMsg.channelID = channel.channelID;
    wkMsg.channelType = channel.channelType;
    wkMsg.fromUID = WKIM.shared.options.uid!;
    wkMsg.contentType = messageContent.contentType;
    int tempOrderSeq = await MessageDB.shared
        .queryMaxOrderSeq(wkMsg.channelID, wkMsg.channelType);
    wkMsg.orderSeq = tempOrderSeq + 1;

    wkMsg.content = _getSendPayload(wkMsg);
    int row = await saveMsg(wkMsg);
    wkMsg.clientSeq = row;
    WKIM.shared.messageManager.setOnMsgInserted(wkMsg);
    if (row > 0) {
      WKUIConversationMsg? uiMsg =
          await WKIM.shared.conversationManager.saveWithLiMMsg(wkMsg);
      if (uiMsg != null) {
        List<WKUIConversationMsg> uiMsgs = [];
        uiMsgs.add(uiMsg);
        WKIM.shared.conversationManager.setRefreshUIMsgs(uiMsgs);
      }
    }
    if (wkMsg.messageContent is WKMediaMessageContent) {
      // 附件消息
      if (_uploadAttachmentBack != null) {
        _uploadAttachmentBack!(wkMsg, (isSuccess, uploadedMsg) {
          if (!isSuccess) {
            wkMsg.status = WKSendMsgResult.sendFail;
            updateMsgStatusFail(wkMsg.clientSeq);
            return;
          }
          // 重新编码消息正文
          Map<String, dynamic> json = uploadedMsg.messageContent!.encodeJson();
          json['type'] = uploadedMsg.contentType;
          //uploadedMsg.content = jsonEncode(json);
          updateContent(
              uploadedMsg.clientMsgNO, uploadedMsg.messageContent!, false);
          Map<String, dynamic> sendJson = HashMap();
          // 过滤 ‘localPath’ 和 ‘coverLocalPath’
          json.forEach((key, value) {
            if (key != 'localPath' && key != 'coverLocalPath') {
              sendJson[key] = value;
            }
          });
          uploadedMsg.content = jsonEncode(sendJson);
          WKIM.shared.connectionManager.sendMessage(uploadedMsg);
        });
      } else {
        Logs.debug(
            '未监听附件消息上传事件，请监听`WKMessageManager`的`addOnUploadAttachmentListener`方法');
      }
    } else {
      WKIM.shared.connectionManager.sendMessage(wkMsg);
    }
  }

  String _getSendPayload(WKMsg wkMsg) {
    dynamic json = wkMsg.messageContent!.encodeJson();
    json['type'] = wkMsg.contentType;
    if (wkMsg.messageContent!.reply != null) {
      json['reply'] = wkMsg.messageContent!.reply!.encode();
    }

    if (wkMsg.messageContent!.entities != null &&
        wkMsg.messageContent!.entities!.isNotEmpty) {
      var jsonArray = [];
      for (WKMsgEntity entity in wkMsg.messageContent!.entities!) {
        var jo = <String, dynamic>{};
        jo['offset'] = entity.offset;
        jo['length'] = entity.length;
        jo['type'] = entity.type;
        jo['value'] = entity.value;
        jsonArray.add(jo);
      }
      json['entities'] = jsonArray;
    }
    // 解析艾特
    if (wkMsg.messageContent!.mentionInfo != null) {
      var mentionJson = {};
      if (wkMsg.messageContent!.mentionInfo!.mentionAll) {
        mentionJson['all'] = 1;
      }
      if (wkMsg.messageContent!.mentionInfo!.uids != null &&
          wkMsg.messageContent!.mentionInfo!.uids!.isNotEmpty) {
        var jsonArray = [];
        for (String uid in wkMsg.messageContent!.mentionInfo!.uids!) {
          jsonArray.add(uid);
        }
        mentionJson['uids'] = jsonArray;
      }
      json['mention'] = mentionJson;
    }
    return jsonEncode(json);
  }

  updateSendResult(
      String messageID, int clientSeq, int messageSeq, int reasonCode) async {
    WKMsg? wkMsg = await MessageDB.shared.queryWithClientSeq(clientSeq);
    if (wkMsg != null) {
      wkMsg.messageID = messageID;
      wkMsg.messageSeq = messageSeq;
      wkMsg.status = reasonCode;
      var map = <String, Object>{};
      map['message_id'] = messageID;
      map['message_seq'] = messageSeq;
      map['status'] = reasonCode;
      int orderSeq = await WKIM.shared.messageManager
          .getMessageOrderSeq(messageSeq, wkMsg.channelID, wkMsg.channelType);
      map['order_seq'] = orderSeq;
      MessageDB.shared.updateMsgWithField(map, clientSeq);
      setRefreshMsg(wkMsg);
    }
  }

  updateMsgStatusFail(int clientMsgSeq) async {
    var map = <String, Object>{};
    map['status'] = WKSendMsgResult.sendFail;
    int row = await MessageDB.shared.updateMsgWithField(map, clientMsgSeq);
    if (row > 0) {
      MessageDB.shared.queryWithClientSeq(clientMsgSeq).then((wkMsg) {
        if (wkMsg != null) {
          setRefreshMsg(wkMsg);
        }
      });
    }
  }

  updateContent(String clientMsgNO, WKMessageContent messageContent,
      bool isRefreshUI) async {
    WKMsg? wkMsg = await MessageDB.shared.queryWithClientMsgNo(clientMsgNO);
    if (wkMsg != null) {
      var map = <String, Object>{};
      dynamic json = messageContent.encodeJson();
      json['type'] = wkMsg.contentType;

      map['content'] = jsonEncode(json);
      int result = await MessageDB.shared
          .updateMsgWithFieldAndClientMsgNo(map, clientMsgNO);
      if (isRefreshUI && result > 0) {
        setRefreshMsg(wkMsg);
      }
    }
  }

  updateSendingMsgFail() {
    MessageDB.shared.updateSendingMsgFail();
  }

  updateLocalExtraWithClientMsgNo(String clientMsgNO, dynamic data) async {
    WKMsg? wkMsg = await MessageDB.shared.queryWithClientMsgNo(clientMsgNO);
    if (wkMsg != null) {
      var map = <String, Object>{};
      map['extra'] = jsonEncode(data);
      int result = await MessageDB.shared
          .updateMsgWithFieldAndClientMsgNo(map, clientMsgNO);
      if (result > 0) {
        setRefreshMsg(wkMsg);
      }
    }
  }

  updateMsgEdit(String messageID, String channelID, int channelType,
      Map<String, dynamic> content) async {
    var msgExtra = await MessageDB.shared.queryMsgExtraWithMsgID(messageID);
    msgExtra ??= WKMsgExtra();
    msgExtra.messageID = messageID;
    msgExtra.channelID = channelID;
    msgExtra.channelType = channelType;
    msgExtra.editedAt =
        (DateTime.now().millisecondsSinceEpoch / 1000).truncate();
    msgExtra.contentEdit = jsonEncode(content);
    msgExtra.needUpload = 1;
    List<WKMsgExtra> list = [];
    list.add(msgExtra);
    List<String> messageIds = [];
    messageIds.add(messageID);
    var result = await MessageDB.shared.insertMsgExtras(list);
    if (result) {
      var wkMsgs = await MessageDB.shared.queryWithMessageIds(messageIds);
      getMsgReactionsAndRefreshMsg(messageIds, wkMsgs);
      _setUploadMsgExtra(msgExtra);
    }
  }

  clearWithChannel(String channelId, int channelType) async {
    int row = await MessageDB.shared.deleteWithChannel(channelId, channelType);
    if (row > 0) {
      _setClearChannelMsg(channelId, channelType);
    }
  }

  deleteWithClientMsgNo(String clientMsgNo) async {
    var map = <String, Object>{};
    map['is_deleted'] = 1;

    var result = await MessageDB.shared
        .updateMsgWithFieldAndClientMsgNo(map, clientMsgNo);
    if (result > 0) {
      _setDeleteMsg(clientMsgNo);
      var wkMsg = await getWithClientMsgNo(clientMsgNo);
      if (wkMsg != null) {
        var coverMsg = await ConversationDB.shared
            .queryMsgByMsgChannelId(wkMsg.channelID, wkMsg.channelType);
        if (coverMsg != null && coverMsg.lastClientMsgNO == clientMsgNo) {
          var tempMsg = await MessageDB.shared.queryMaxOrderSeqMsgWithChannel(
              wkMsg.channelID, wkMsg.channelType);
          if (tempMsg != null) {
            var uiMsg =
                await WKIM.shared.conversationManager.saveWithLiMMsg(tempMsg);
            if (uiMsg != null) {
              List<WKUIConversationMsg> uiMsgs = [];
              uiMsgs.add(uiMsg);
              WKIM.shared.conversationManager.setRefreshUIMsgs(uiMsgs);
            }
          }
        }
      }
    }
  }
}
