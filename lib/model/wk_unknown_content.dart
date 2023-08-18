import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

class WKUnknownContent extends WKMessageContent {
  WKUnknownContent() {
    contentType = WkMessageContentType.unknown;
  }
  @override
  String displayText() {
    return '[未知消息]';
  }
}
