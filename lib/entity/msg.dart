import 'dart:convert';

import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../model/wk_message_content.dart';
import '../proto/proto.dart';
import '../type/const.dart';
import 'channel.dart';
import 'channel_member.dart';

class WKMsg {
  MessageHeader header = MessageHeader();
  Setting setting = Setting();
  String messageID = "";
  int messageSeq = 0;
  int clientSeq = 0;
  int timestamp = 0;
  String clientMsgNO = "";
  String fromUID = "";
  String channelID = "";
  int channelType = WKChannelType.personal;
  int contentType = 0;
  String content = "";
  int status = 0;
  int voiceStatus = 0;
  int isDeleted = 0;
  String searchableWord = "";
  WKChannel? _from;
  WKChannel? _channelInfo;
  WKChannelMember? _memberOfFrom;
  int orderSeq = 0;
  int viewed = 0;
  int viewedAt = 0;
  String topicID = "";
  dynamic localExtraMap;
  WKMsgExtra? wkMsgExtra;
  List<WKMsgReaction>? reactionList;
  WKMessageContent? messageContent;

  WKMsg() {
    clientSeq = 0;
    clientMsgNO = WKIM.shared.messageManager.generateClientMsgNo();
    timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).truncate();
  }

  setChannelInfo(WKChannel? wkChannel) {
    _channelInfo = wkChannel;
  }

  getChannelInfo() {
    return _channelInfo;
  }

  setMemberOfFrom(WKChannelMember wkChannelMember) {
    _memberOfFrom = wkChannelMember;
  }

  getMemberOfFrom() {
    return _memberOfFrom;
  }

  setFrom(WKChannel channel) {
    _from = channel;
  }

  getFrom() {
    return _from;
  }
}

class MessageHeader {
  bool redDot = false; // 是否显示红点
  bool noPersist = false; // 是否不存储
  bool syncOnce = false; // 是否只同步一次
}

class WKMsgExtra {
  String messageID = "";
  String channelID = "";
  int channelType = 0;
  int readed = 0;
  int readedCount = 0;
  int unreadCount = 0;
  int revoke = 0;
  int isMutualDeleted = 0;
  String revoker = "";
  int extraVersion = 0;
  int editedAt = 0;
  String contentEdit = "";
  int needUpload = 0;
  WKMessageContent? messageContent;
}

class WKMsgReaction {
  String messageID = "";
  String channelID = "";
  int channelType = 0;
  String uid = "";
  String name = "";
  int seq = 0;
  String emoji = "";
  int isDeleted = 0;
  String createdAt = "";
}

class WKSyncMsg {
  String messageID = '';
  int messageSeq = 0;
  String clientMsgNO = '';
  String fromUID = '';
  String channelID = '';
  int channelType = 0;
  int timestamp = 0;
  int voiceStatus = 0;
  int isDeleted = 0;
  int revoke = 0;
  String revoker = '';
  int extraVersion = 0;
  int unreadCount = 0;
  int readedCount = 0;
  int readed = 0;
  int receipt = 0;
  int setting = 0;
  dynamic payload;
  List<WKSyncMsgReaction>? reactions;
  WKSyncExtraMsg? messageExtra;

  WKMsg getWKMsg() {
    WKMsg msg = WKMsg();
    msg.channelID = channelID;
    msg.channelType = channelType;
    msg.messageID = messageID;
    msg.messageSeq = messageSeq;
    msg.clientMsgNO = clientMsgNO;
    msg.fromUID = fromUID;
    msg.timestamp = timestamp;
    msg.orderSeq = msg.messageSeq * WKIM.shared.messageManager.wkOrderSeqFactor;
    msg.voiceStatus = voiceStatus;
    msg.isDeleted = isDeleted;
    msg.status = WKSendMsgResult.sendSuccess;
    msg.wkMsgExtra = WKMsgExtra();
    msg.wkMsgExtra!.revoke = revoke;
    msg.wkMsgExtra!.revoker = revoker;
    msg.wkMsgExtra!.unreadCount = unreadCount;
    msg.wkMsgExtra!.readedCount = readedCount;
    msg.wkMsgExtra!.readed = readed;
    // msg.reactionList = reactions;
    // msg.receipt = receipt;
    msg.wkMsgExtra!.extraVersion = extraVersion;
    //处理消息设置
    msg.setting = msg.setting.decode(setting);
    //如果是单聊先将channelId改成发送者ID
    if (msg.channelID != '' &&
        msg.fromUID != '' &&
        msg.channelType == WKChannelType.personal &&
        msg.channelID == WKIM.shared.options.uid) {
      msg.channelID = msg.fromUID;
    }
    if (payload != null) {
      msg.content = jsonEncode(payload);
      msg.contentType = WKDBConst.readInt(payload, 'type');
    }
    WKIM.shared.messageManager.parsingMsg(msg);
    // 处理消息回应
    if (reactions != null && reactions!.isNotEmpty) {
      msg.reactionList = getMsgReaction(reactions!);
    }
    if (msg.contentType != WkMessageContentType.contentFormatError) {
      msg.messageContent =
          WKIM.shared.messageManager.getMessageModel(msg.contentType, payload);
    }

    return msg;
  }

  List<WKMsgReaction> getMsgReaction(List<WKSyncMsgReaction> msgReaction) {
    List<WKMsgReaction> list = [];
    for (int i = 0, size = msgReaction.length; i < size; i++) {
      WKMsgReaction reaction = WKMsgReaction();
      reaction.channelID = msgReaction[i].channelID;
      reaction.channelType = msgReaction[i].channelType;
      reaction.uid = msgReaction[i].uid;
      reaction.name = msgReaction[i].name;
      reaction.emoji = msgReaction[i].emoji;
      reaction.seq = msgReaction[i].seq;
      reaction.isDeleted = msgReaction[i].isDeleted;
      reaction.messageID = msgReaction[i].messageID;
      reaction.createdAt = msgReaction[i].createdAt;
      list.add(reaction);
    }
    return list;
  }
}

class WKSyncMsgReaction {
  String messageID = '';
  String uid = '';
  String name = '';
  String channelID = '';
  int channelType = 0;
  int seq = 0;
  String emoji = '';
  int isDeleted = 0;
  String createdAt = '';
}

class WKSyncExtraMsg {
  int messageID = 0;
  String messageIdStr = '';
  int revoke = 0;
  String revoker = '';
  int voiceStatus = 0;
  int isMutualDeleted = 0;
  int extraVersion = 0;
  int unreadCount = 0;
  int readedCount = 0;
  int readed = 0;
  dynamic contentEdit;
  int editedAt = 0;
}

class WKReply {
  // 被回复的消息根ID，多级回复时的第一次回复的消息ID
  String rootMid = '';
  // 被回复的消息ID
  String messageId = '';
  // 被回复的MessageSeq
  int messageSeq = 0;
  // 被回复者uid
  String fromUID = '';
  // 被回复者名称
  String fromName = '';
  // 被回复的消息体
  WKMessageContent? payload;
  // 被回复消息编辑后的内容
  String contentEdit = '';
  // 被回复消息编辑后的消息实体
  WKMessageContent? contentEditMsgModel;
  // 编辑时间
  int editAt = 0;
  int revoke = 0;

  dynamic encode() {
    var json = <String, dynamic>{};
    json['root_mid'] = rootMid;
    json['message_id'] = messageId;
    json['message_seq'] = messageSeq;
    json['from_uid'] = fromUID;
    json['from_name'] = fromName;
    if (payload != null) {
      var contentJson = payload!.encodeJson();
      contentJson['type'] = payload!.contentType;
      json['payload'] = contentJson;
    }
    return json;
  }

  WKReply decode(dynamic data) {
    rootMid = WKDBConst.readString(data, 'root_mid');
    messageId = WKDBConst.readString(data, 'message_id');
    messageSeq = WKDBConst.readInt(data, 'message_seq');
    fromUID = WKDBConst.readString(data, 'from_uid');
    fromName = WKDBConst.readString(data, 'from_name');
    var json = data['payload'];
    // String contentJson = WKDBConst.readString(data, 'payload');
    if (json != null) {
      // var json = jsonDecode(contentJson);
      var type = json['type'];
      payload = WKIM.shared.messageManager.getMessageModel(type, json);
    }
    return this;
  }
}

class WKMsgEntity {
  int offset = 0;
  int length = 0;
  String type = '';
  String value = '';
}

class WKSyncChannelMsg {
  int startMessageSeq = 0;
  int endMessageSeq = 0;
  int more = 0;
  List<WKSyncMsg>? messages = [];
}

class WKMentionInfo {
  bool isMentionMe = false;
  bool mentionAll = false;
  List<String>? uids;
}
