import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import 'const.dart';

class UIMsg {
  WKMsg wkMsg;
  UIMsg(this.wkMsg);

  String getShowContent() {
    if (wkMsg.messageContent == null) {
      return '';
    }
    return wkMsg.messageContent!.displayText();
  }

  String getShowTime() {
    return CommonUtils.formatDateTime(wkMsg.timestamp);
  }

  String getStatusIV() {
    if (wkMsg.status == WKSendMsgResult.sendLoading) {
      return 'assets/loading.png';
    } else if (wkMsg.status == WKSendMsgResult.sendSuccess) {
      return 'assets/success.png';
    }
    return 'assets/error.png';
  }
}
