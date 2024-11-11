import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';

class UIConversation {
  String lastContent = '';
  String channelAvatar = '';
  String channelName = '';
  WKUIConversationMsg msg;
  UIConversation(this.msg);
  List<WKReminder>? reminders;
  String getUnreadCount() {
    if (msg.unreadCount > 0) {
      return '${msg.unreadCount}';
    }
    return '';
  }
}
