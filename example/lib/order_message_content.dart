import 'package:wukongimfluttersdk/model/wk_message_content.dart';

class OrderMsg extends WKMessageContent {
  var orderNo = "";
  var title = '';
  var imgUrl = '';
  var num = 0;
  var price = 0;
  OrderMsg() {
    contentType = 56;
  }
  @override
  Map<String, dynamic> encodeJson() {
    return {
      "orderNo": orderNo,
      'title': title,
      'imgUrl': imgUrl,
      'num': num,
      'price': price
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    title = json["title"];
    orderNo = json["orderNo"];
    imgUrl = json["imgUrl"];
    num = json["num"];
    price = json["price"];
    return this;
  }

  @override
  String displayText() {
    return "[订单消息]";
  }
}
