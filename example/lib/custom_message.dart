import 'package:wukongimfluttersdk/model/wk_message_content.dart';

class CustomMsg extends WKMessageContent {
  var name = "";
  CustomMsg(this.name) {
    contentType = 12;
  }
  @override
  Map<String, dynamic> encodeJson() {
    return {"name": name};
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    name = json["name"];
    return this;
  }

  @override
  String displayText() {
    return "我是自定义消息：$name";
  }
}
