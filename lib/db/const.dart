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
    msg.timestamp = data['timestamp'];
    msg.fromUID = data['from_uid'];
    msg.channelID = data['channel_id'];
    msg.channelType = data['channel_type'];
    msg.contentType = data['type'];
    msg.content = data['content'];
    msg.status = data['status'];
    msg.voiceStatus = data['voice_status'];
    msg.searchableWord = data['searchable_word'];
    msg.clientMsgNO = data['client_msg_no'];
    msg.isDeleted = data['is_deleted'];
    msg.orderSeq = data['order_seq'];
    int setting = data['setting'];
    msg.setting = Setting().decode(setting);
    msg.viewed = data['viewed'];
    msg.viewedAt = data['viewed_at'];
    msg.topicID = data['topic_id'];
    // 扩展表数据
    msg.wkMsgExtra = serializeMsgExtra(data);

    String extra = data['extra'];
    if (extra != '') {
      msg.localExtraMap = jsonEncode(extra);
    }
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
    reaction.channelID = data['channel_id'];
    reaction.channelType = data['channel_type'];
    reaction.isDeleted = data['is_deleted'];
    reaction.uid = data['uid'];
    reaction.name = data['name'];
    reaction.messageID = data['message_id'];
    reaction.createdAt = data['created_at'];
    reaction.seq = data['seq'];
    reaction.emoji = data['emoji'];
    reaction.isDeleted = data['is_deleted'];
    return reaction;
  }

  static WKConversationMsg serializeCoversation(dynamic data) {
    WKConversationMsg msg = WKConversationMsg();
    msg.channelID = data['channel_id'];
    msg.channelType = data['channel_type'];
    msg.lastMsgTimestamp = data['last_msg_timestamp'];
    msg.unreadCount = data['unread_count'];
    msg.isDeleted = data['is_deleted'];
    msg.version = data['version'];
    msg.lastClientMsgNO = data['last_client_msg_no'];
    msg.lastMsgSeq = data['last_msg_seq'];
    msg.parentChannelID = data['parent_channel_id'];
    msg.parentChannelType = data['parent_channel_type'];
    String extra = data['extra'];
    if (extra != '') {
      msg.localExtraMap = jsonDecode(extra);
    }
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
      extra.version = data['extra_version'];
    }
    return extra;
  }

  static WKChannel serializeChannel(dynamic data) {
    String channelID = data['channel_id'];
    int channelType = data['channel_type'];
    WKChannel channel = WKChannel(channelID, channelType);
    channel.channelName = data['channel_name'];
    channel.channelRemark = data['channel_remark'];
    channel.showNick = data['show_nick'];
    channel.top = data['top'];
    channel.mute = data['mute'];
    channel.isDeleted = data['is_deleted'];
    channel.forbidden = data['forbidden'];
    channel.status = data['status'];
    channel.follow = data['follow'];
    channel.invite = data['invite'];
    channel.version = data['version'];
    channel.avatar = data['avatar'];
    channel.online = data['online'];
    channel.lastOffline = data['last_offline'];
    channel.category = data['category'];
    channel.receipt = data['receipt'];
    channel.robot = data['robot'];
    channel.username = data['username'];
    channel.avatarCacheKey = data['avatar_cache_key'];
    channel.deviceFlag = data['device_flag'];
    channel.parentChannelID = data['parent_channel_id'];
    channel.parentChannelType = data['parent_channel_type'];
    channel.createdAt = data['created_at'];
    channel.updatedAt = data['updated_at'];
    String remoteExtra = data['remote_extra'];
    if (remoteExtra != '') {
      channel.remoteExtraMap = jsonDecode(remoteExtra);
    }
    String localExtra = data['extra'];
    if (remoteExtra != '') {
      channel.localExtra = jsonDecode(localExtra);
    }
    return channel;
  }

  static WKChannelMember serializeChannelMember(dynamic data) {
    WKChannelMember member = WKChannelMember();
    member.status = data['status'];
    member.channelID = data['channel_id'];
    member.channelType = data['channel_type'];
    member.memberUID = data['member_uid'];
    member.memberName = data['member_name'];
    member.memberAvatar = data['member_avatar'];
    member.memberRemark = data['member_remark'];
    member.role = data['role'];
    member.isDeleted = data['is_deleted'];
    member.version = data['version'];
    member.createdAt = data['created_at'];
    member.updatedAt = data['updated_at'];
    member.memberInviteUID = data['member_invite_uid'];
    member.robot = data['robot'];
    member.forbiddenExpirationTime = data['forbidden_expiration_time'];
    String channelName = readString(data, 'channel_name');
    if (channelName != '') {
      member.memberName = channelName;
    }
    member.remark = readString(data, 'channel_remark');
    member.memberAvatar = readString(data, 'avatar');
    String avatarCache = readString(data, 'avatar_cache_key');
    if (avatarCache != '') {
      member.memberAvatarCacheKey = avatarCache;
    } else {
      member.memberAvatarCacheKey = readString(data, 'member_avatar_cache_key');
    }
    String extra = readString(data, 'extra');
    if (extra != '') {
      member.extraMap = jsonDecode(extra);
    }

    return member;
  }

  static WKReminder serializeReminder(dynamic data) {
    WKReminder reminder = WKReminder();
    reminder.type = data['type'];
    reminder.reminderID = data['reminder_id'];
    reminder.messageID = data['message_id'];
    reminder.messageSeq = data['message_seq'];
    reminder.isLocate = data['is_locate'];
    reminder.channelID = data['channel_id'];
    reminder.channelType = data['channel_type'];
    reminder.text = data['text'];
    reminder.version = data['version'];
    reminder.done = data['done'];
    String data1 = data['data'];
    reminder.needUpload = data['needUpload'];
    reminder.publisher = data['publisher'];
    if (data1 != '') {
      reminder.data = jsonDecode(data1);
    }
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
}
