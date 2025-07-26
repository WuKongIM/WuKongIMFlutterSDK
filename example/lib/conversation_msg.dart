import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';

class UIConversation {
  String lastContent = '';
  String channelAvatar = '';
  String channelName = '';
  WKUIConversationMsg msg;
  int top = 0;
  int mute = 0;
  UIConversation(this.msg) {
    // 初始化top和mute
    msg.getWkChannel().then((channel) {
      if (channel != null) {
        top = channel.top;
        mute = channel.mute;
      }
    });
  }
  List<WKReminder>? reminders;
  String getUnreadCount() {
    if (msg.unreadCount > 0) {
      return '${msg.unreadCount}';
    }
    return '';
  }
}
