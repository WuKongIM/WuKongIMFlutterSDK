import 'package:wukongimfluttersdk/entity/msg.dart';

class WKMessageContent {
  var contentType = 0;
  String content = "";
  String topicId = "";
  WKReply? reply;
  List<WKMsgEntity>? entities;
  WKMentionInfo? mentionInfo;
  Map<String, dynamic> encodeJson() {
    return {};
  }

  WKMessageContent decodeJson(Map<String, dynamic> json) {
    return this;
  }

  String displayText() {
    return content;
  }

  String searchableWord() {
    return content;
  }

  int readInt(dynamic json, String key) {
    dynamic result = json[key];
    if (result == Null || result == null) {
      return 0;
    }
    return result as int;
  }

  String readString(dynamic json, String key) {
    dynamic result = json[key];
    if (result == Null || result == null) {
      return '';
    }
    return result.toString();
  }
}
