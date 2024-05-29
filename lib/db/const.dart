import 'dart:convert';

import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../proto/proto.dart';

class WKDBConst {
  static const tableMessage = 'message';
  static const tableMessageReaction = 'message_reaction';
  static const tableMessageExtra = 'message_extra';
  static const tableConversation = 'conversation';
  static const tableConversationExtra = 'conversation_extra';
  static const tableChannel = 'channel';
  static const tableChannelMember = 'channel_members';
  static const tableReminders = 'reminders';
  static const tableRobot = 'robot';
  static const tableRobotMenu = 'robot_menu';

  static WKMsg serializeWKMsg(dynamic data) {
    WKMsg msg = WKMsg();
    msg.messageID = readString(data, 'message_id');
    msg.messageSeq = readInt(data, 'message_seq');
    msg.clientSeq = readInt(data, 'client_seq');
    msg.timestamp = readInt(data, 'timestamp');
    msg.fromUID = readString(data, 'from_uid');
    msg.channelID = readString(data, 'channel_id');
    msg.channelType = readInt(data, 'channel_type');
    msg.contentType = readInt(data, 'type');
    msg.content = readString(data, 'content');
    msg.status = readInt(data, 'status');
    msg.voiceStatus = readInt(data, 'voice_status');
    msg.searchableWord = readString(data, 'searchable_word');
    msg.clientMsgNO = readString(data, 'client_msg_no');
    msg.isDeleted = readInt(data, 'is_deleted');
    msg.orderSeq = readInt(data, 'order_seq');
    int setting = readInt(data, 'setting');
    msg.setting = Setting().decode(setting);
    msg.viewed = readInt(data, 'viewed');
    msg.viewedAt = readInt(data, 'viewed_at');
    msg.topicID = readString(data, 'topic_id');
    // 扩展表数据
    msg.wkMsgExtra = serializeMsgExtra(data);
    msg.localExtraMap = readDynamic(data, 'extra');
    if (msg.content != '') {
      dynamic contentJson = jsonDecode(msg.content);
      msg.messageContent = WKIM.shared.messageManager
          .getMessageModel(msg.contentType, contentJson);
    }
    if (msg.wkMsgExtra!.contentEdit != '') {
      dynamic json = jsonDecode(msg.wkMsgExtra!.contentEdit);
      msg.wkMsgExtra!.messageContent = WKIM.shared.messageManager
          .getMessageModel(WkMessageContentType.text, json);
    }

    return msg;
  }

  static WKMsgExtra serializeMsgExtra(dynamic data) {
    WKMsgExtra extra = WKMsgExtra();
    extra.messageID = readString(data, 'message_id');
    extra.channelID = readString(data, 'channel_id');
    extra.channelType = readInt(data, 'channel_type');
    extra.readed = readInt(data, 'readed');
    extra.readedCount = readInt(data, 'readed_count');
    extra.unreadCount = readInt(data, 'unread_count');
    extra.revoke = readInt(data, 'revoke');
    extra.isMutualDeleted = readInt(data, 'is_mutual_deleted');
    extra.revoker = readString(data, 'revoker');
    extra.extraVersion = readInt(data, 'extra_version');
    extra.editedAt = readInt(data, 'edited_at');
    extra.contentEdit = readString(data, 'content_edit');
    extra.needUpload = readInt(data, 'need_upload');
    return extra;
  }

  static WKMsgReaction serializeMsgReation(dynamic data) {
    WKMsgReaction reaction = WKMsgReaction();
    reaction.channelID = readString(data, 'channel_id');
    reaction.channelType = readInt(data, 'channel_type');
    reaction.isDeleted = readInt(data, 'is_deleted');
    reaction.uid = readString(data, 'uid');
    reaction.name = readString(data, 'name');
    reaction.messageID = readString(data, 'message_id');
    reaction.createdAt = readString(data, 'created_at');
    reaction.seq = readInt(data, 'seq');
    reaction.emoji = readString(data, 'emoji');
    return reaction;
  }

  static WKConversationMsg serializeCoversation(dynamic data) {
    WKConversationMsg msg = WKConversationMsg();
    msg.channelID = readString(data, 'channel_id');
    msg.channelType = readInt(data, 'channel_type');
    msg.lastMsgTimestamp = readInt(data, 'last_msg_timestamp');
    msg.unreadCount = readInt(data, 'unread_count');
    msg.isDeleted = readInt(data, 'is_deleted');
    msg.version = readInt(data, 'version');
    msg.lastClientMsgNO = readString(data, 'last_client_msg_no');
    msg.lastMsgSeq = readInt(data, 'last_msg_seq');
    msg.parentChannelID = readString(data, 'parent_channel_id');
    msg.parentChannelType = readInt(data, 'parent_channel_type');
    msg.localExtraMap = readDynamic(data, 'extra');
    msg.msgExtra = serializeConversationExtra(data);
    return msg;
  }

  static WKConversationMsgExtra serializeConversationExtra(dynamic data) {
    WKConversationMsgExtra extra = WKConversationMsgExtra();
    extra.channelID = readString(data, 'channel_id');
    extra.channelType = readInt(data, 'channel_type');
    extra.keepMessageSeq = readInt(data, 'keep_message_seq');
    extra.keepOffsetY = readInt(data, 'keep_offset_y');
    extra.draft = readString(data, 'draft');
    extra.browseTo = readInt(data, 'browse_to');
    extra.draftUpdatedAt = readInt(data, 'draft_updated_at');
    extra.version = readInt(data, 'version');
    if (data['extra_version'] != null) {
      extra.version = readInt(data, 'extra_version');
    }
    return extra;
  }

  static WKChannel serializeChannel(dynamic data) {
    String channelID = readString(data, 'channel_id');
    int channelType = readInt(data, 'channel_type');
    WKChannel channel = WKChannel(channelID, channelType);
    channel.channelName = readString(data, 'channel_name');
    channel.channelRemark = readString(data, 'channel_remark');
    channel.showNick = readInt(data, 'show_nick');
    channel.top = readInt(data, 'top');
    channel.mute = readInt(data, 'mute');
    channel.isDeleted = readInt(data, 'is_deleted');
    channel.forbidden = readInt(data, 'forbidden');
    channel.status = readInt(data, 'status');
    channel.follow = readInt(data, 'follow');
    channel.invite = readInt(data, 'invite');
    channel.version = readInt(data, 'version');
    channel.avatar = readString(data, 'avatar');
    channel.online = readInt(data, 'online');
    channel.lastOffline = readInt(data, 'last_offline');
    channel.category = readString(data, 'category');
    channel.receipt = readInt(data, 'receipt');
    channel.robot = readInt(data, 'robot');
    channel.username = readString(data, 'username');
    channel.avatarCacheKey = readString(data, 'avatar_cache_key');
    channel.deviceFlag = readInt(data, 'device_flag');
    channel.parentChannelID = readString(data, 'parent_channel_id');
    channel.parentChannelType = readInt(data, 'parent_channel_type');
    String parentChannelId = readString(data, 'c_parent_channel_id');
    int parentChannelType = readInt(data, 'c_parent_channel_type');
    if (parentChannelId != '') {
      channel.parentChannelID = parentChannelId;
      channel.parentChannelType = parentChannelType;
    }
    channel.createdAt = readString(data, 'created_at');
    channel.updatedAt = readString(data, 'updated_at');
    channel.remoteExtraMap = readDynamic(data, 'remote_extra');
    channel.localExtra = readDynamic(data, 'extra');
    return channel;
  }

  static WKChannelMember serializeChannelMember(dynamic data) {
    WKChannelMember member = WKChannelMember();
    member.status = readInt(data, 'status');
    member.channelID = readString(data, 'channel_id');
    member.channelType = readInt(data, 'channel_type');
    member.memberUID = readString(data, 'member_uid');
    member.memberName = readString(data, 'member_name');
    member.memberAvatar = readString(data, 'member_avatar');
    member.memberRemark = readString(data, 'member_remark');
    member.role = readInt(data, 'role');
    member.isDeleted = readInt(data, 'is_deleted');
    member.version = readInt(data, 'version');
    member.createdAt = readString(data, 'created_at');
    member.updatedAt = readString(data, 'updated_at');
    member.memberInviteUID = readString(data, 'member_invite_uid');
    member.robot = readInt(data, 'robot');
    member.forbiddenExpirationTime = readInt(data, 'forbidden_expiration_time');
    String channelName = readString(data, 'channel_name');
    if (channelName != '') {
      member.memberName = channelName;
    }
    member.remark = readString(data, 'channel_remark');
    String channelAvatar = readString(data, 'avatar');
    if (channelAvatar != '') {
      member.memberAvatar = channelAvatar;
    }
    String avatarCache = readString(data, 'avatar_cache_key');
    if (avatarCache != '') {
      member.memberAvatarCacheKey = avatarCache;
    } else {
      member.memberAvatarCacheKey = readString(data, 'member_avatar_cache_key');
    }
    member.extraMap = readDynamic(data, 'extra');
    return member;
  }

  static WKReminder serializeReminder(dynamic data) {
    WKReminder reminder = WKReminder();
    reminder.type = readInt(data, 'type');
    reminder.reminderID = readInt(data, 'reminder_id');
    reminder.messageID = readString(data, 'message_id');
    reminder.messageSeq = readInt(data, 'message_seq');
    reminder.isLocate = readInt(data, 'is_locate');
    reminder.channelID = readString(data, 'channel_id');
    reminder.channelType = readInt(data, 'channel_type');
    reminder.text = readString(data, 'text');
    reminder.version = readInt(data, 'version');
    reminder.done = readInt(data, 'done');
    reminder.needUpload = readInt(data, 'need_upload');
    reminder.publisher = readString(data, 'publisher');
    reminder.data = readDynamic(data, 'data');
    return reminder;
  }

  static int readInt(dynamic data, String key) {
    dynamic result = data[key];
    if (result == Null || result == null) {
      return 0;
    }
    return result as int;
  }

  static String readString(dynamic data, String key) {
    dynamic result = data[key];
    if (result == Null || result == null) {
      return '';
    }
    return result.toString();
  }

  static dynamic readDynamic(dynamic data, String key) {
    String jsonStr = readString(data, key);
    if (jsonStr != '' && isJsonString(jsonStr)) {
      return jsonDecode(jsonStr);
    }
    return jsonStr;
  }

  static bool isJsonString(String str) {
    try {
      final parsed = json.decode(str);
      return parsed is Map || parsed is List;
    } on FormatException {
      return false;
    }
  }

  static String getPlaceholders(int count) {
    StringBuffer placeholders = StringBuffer();
    for (int i = 0; i < count; i++) {
      if (i != 0) {
        placeholders.write(", ");
      }
      placeholders.write("?");
    }
    return placeholders.toString();
  }
}
