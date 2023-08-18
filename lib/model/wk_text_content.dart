import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

class WKTextContent extends WKMessageContent {
  WKTextContent(content) {
    contentType = WkMessageContentType.text;
    this.content = content;
  }
  @override
  Map<String, dynamic> encodeJson() {
    return {"content": content};
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    content = WKDBConst.readString(json, 'content');
    return this;
  }

  @override
  String displayText() {
    return content;
  }

  @override
  String searchableWord() {
    return content;
  }
}
