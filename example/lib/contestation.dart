import 'package:wukongimfluttersdk/entity/conversation.dart';

class UIConversation {
  String lastContent = '';
  WKUIConversationMsg msg;
  UIConversation(this.msg);

  String getUnreadCount() {
    if (msg.unreadCount > 0) {
      return '${msg.unreadCount}';
    }
    return '';
  }
}
