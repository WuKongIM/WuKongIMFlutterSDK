import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'channel.dart';
import 'cmd.dart';
import 'msg.dart';
import 'reminder.dart';

class WKConversationMsg {
  //频道id
  String channelID = '';
  //频道类型
  int channelType = WKChannelType.personal;
  //最后一条消息本地ID
  String lastClientMsgNO = '';
  //是否删除
  int isDeleted = 0;
  //服务器同步版本号
  int version = 0;
  //最后一条消息时间
  int lastMsgTimestamp = 0;
  //未读消息数量
  int unreadCount = 0;
  //最后一条消息序号
  int lastMsgSeq = 0;
  //扩展字段
  dynamic localExtraMap;
  WKConversationMsgExtra? msgExtra;
  String parentChannelID = '';
  int parentChannelType = 0;
}

class WKConversationMsgExtra {
  String channelID = '';
  int channelType = 0;
  int browseTo = 0;
  int keepMessageSeq = 0;
  int keepOffsetY = 0;
  String draft = '';
  int version = 0;
  int draftUpdatedAt = 0;
}

class WKUIConversationMsg {
  int lastMsgSeq = 0;
  String clientMsgNo = '';
  //频道ID
  String channelID = '';
  //频道类型
  int channelType = 0;
  //最后一条消息时间
  int lastMsgTimestamp = 0;
  //消息频道
  WKChannel? _wkChannel;
  //消息正文
  WKMsg? _wkMsg;
  //未读消息数量
  int unreadCount = 0;
  int isDeleted = 0;
  WKConversationMsgExtra? _remoteMsgExtra;
  //高亮内容[{type:1,text:'[有人@你]'}]
  List<WKReminder>? _reminderList;
  //扩展字段
  dynamic localExtraMap;
  String parentChannelID = '';
  int parentChannelType = 0;

  Future<WKMsg?> getWkMsg() async {
    _wkMsg ??= await WKIM.shared.messageManager.getWithClientMsgNo(clientMsgNo);
    return _wkMsg;
  }

  void setWkMsg(WKMsg wkMsg) {
    _wkMsg = wkMsg;
  }

  Future<WKChannel?> getWkChannel() async {
    _wkChannel ??=
        await WKIM.shared.channelManager.getChannel(channelID, channelType);
    return _wkChannel;
  }

  void setWkChannel(WKChannel wkChannel) {
    _wkChannel = wkChannel;
  }

  Future<List<WKReminder>?> getReminderList() async {
    _reminderList ??= await WKIM.shared.reminderManager
        .getWithChannel(channelID, channelType, 0);
    return _reminderList;
  }

  void setReminderList(List<WKReminder> list) {
    _reminderList = list;
  }

  WKConversationMsgExtra? getRemoteMsgExtra() {
    return _remoteMsgExtra;
  }

  void setRemoteMsgExtra(WKConversationMsgExtra? extra) {
    _remoteMsgExtra = extra;
  }
}

class WKSyncConversation {
  int cmdVersion = 0;
  List<WkSyncCMD>? cmds;
  String uid = '';
  List<WKSyncConvMsg>? conversations;
}

class WKSyncConvMsg {
  String channelID = '';
  int channelType = 0;
  String lastClientMsgNO = '';
  int lastMsgSeq = 0;
  int offsetMsgSeq = 0;
  int timestamp = 0;
  int unread = 0;
  int version = 0;
  List<WKSyncMsg>? recents;
}
