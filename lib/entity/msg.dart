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
  String message_id = '';
  int message_seq = 0;
  String client_msg_no = '';
  String from_uid = '';
  String channel_id = '';
  int channel_type = 0;
  int timestamp = 0;
  int voice_status = 0;
  int is_deleted = 0;
  int revoke = 0;
  String revoker = '';
  int extra_version = 0;
  int unread_count = 0;
  int readed_count = 0;
  int readed = 0;
  int receipt = 0;
  int setting = 0;
  dynamic payload;
  List<WKSyncMsgReaction>? reactions;
  WKSyncExtraMsg? message_extra;

  WKMsg getWKMsg() {
    WKMsg msg = WKMsg();
    msg.channelID = channel_id;
    msg.channelType = channel_type;
    msg.messageID = message_id;
    msg.messageSeq = message_seq;
    msg.clientMsgNO = client_msg_no;
    msg.fromUID = from_uid;
    msg.timestamp = timestamp;
    msg.orderSeq = msg.messageSeq * WKIM.shared.messageManager.wkOrderSeqFactor;
    msg.voiceStatus = voice_status;
    msg.isDeleted = is_deleted;
    msg.status = WKSendMsgResult.sendSuccess;
    msg.wkMsgExtra = WKMsgExtra();
    msg.wkMsgExtra!.revoke = revoke;
    msg.wkMsgExtra!.revoker = revoker;
    msg.wkMsgExtra!.unreadCount = unread_count;
    msg.wkMsgExtra!.readedCount = readed_count;
    msg.wkMsgExtra!.readed = readed;
    // msg.reactionList = reactions;
    // msg.receipt = receipt;
    msg.wkMsgExtra!.extraVersion = extra_version;
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
      reaction.channelID = msgReaction[i].channel_id;
      reaction.channelType = msgReaction[i].channel_type;
      reaction.uid = msgReaction[i].uid;
      reaction.name = msgReaction[i].name;
      reaction.emoji = msgReaction[i].emoji;
      reaction.seq = msgReaction[i].seq;
      reaction.isDeleted = msgReaction[i].is_deleted;
      reaction.messageID = msgReaction[i].message_id;
      reaction.createdAt = msgReaction[i].created_at;
      list.add(reaction);
    }
    return list;
  }
}

class WKSyncMsgReaction {
  String message_id = '';
  String uid = '';
  String name = '';
  String channel_id = '';
  int channel_type = 0;
  int seq = 0;
  String emoji = '';
  int is_deleted = 0;
  String created_at = '';
}

class WKSyncExtraMsg {
  int message_id = 0;
  String message_id_str = '';
  int revoke = 0;
  String revoker = '';
  int voice_status = 0;
  int is_mutual_deleted = 0;
  int extra_version = 0;
  int unread_count = 0;
  int readed_count = 0;
  int readed = 0;
  dynamic content_edit;
  int edited_at = 0;
}

class WKSyncChannelMsg {
  int start_message_seq = 0;
  int end_message_seq = 0;
  int more = 0;
  List<WKSyncMsg>? messages = [];
}
