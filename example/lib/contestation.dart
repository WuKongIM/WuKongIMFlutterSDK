import 'package:wukongimfluttersdk/entity/conversation.dart';

class UIConversation {
  String lastContent = '';
  String channelAvatar = '';
  String channelName = '';
  int isMentionMe = 0;
  WKUIConversationMsg msg;
  UIConversation(this.msg);

  String getUnreadCount() {
    if (msg.unreadCount > 0) {
      return '${msg.unreadCount}';
    }
    return '';
  }
}
