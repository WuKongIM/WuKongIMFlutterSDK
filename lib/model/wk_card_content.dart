import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

class WKCardContent extends WKMessageContent {
  String name;
  String uid;
  String? vercode;
  WKCardContent(this.uid, this.name) {
    contentType = WkMessageContentType.card;
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    name = readString(json, 'name');
    uid = readString(json, 'uid');
    vercode = readString(json, 'uid');
    return this;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return {'name': name, 'uid': uid, 'vercode': vercode};
  }

  @override
  String displayText() {
    return "[名片]";
  }

  @override
  String searchableWord() {
    return "[名片]";
  }
}
