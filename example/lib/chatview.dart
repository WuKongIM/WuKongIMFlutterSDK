import 'package:example/const.dart';
import 'package:example/http.dart';
import 'package:example/msg.dart';
import 'package:example/order_message_content.dart';
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'popmenu_util.dart';
import 'popup_item.dart';

getChannelAvatarURL(UIMsg uiMsg) {
  var fromChannel = uiMsg.wkMsg.getFrom();
  if (fromChannel != null && fromChannel.avatar != '') {
    return HttpUtils.getAvatarUrl(fromChannel.channelID);
  }
  WKIM.shared.channelManager
      .fetchChannelInfo(uiMsg.wkMsg.fromUID, WKChannelType.personal);
  return '';
}

Widget chatAvatar(UIMsg uiMsg) {
  return Image.network(
    getChannelAvatarURL(uiMsg),
    height: 40,
    width: 40,
    fit: BoxFit.cover,
    errorBuilder:
        (BuildContext context, Object exception, StackTrace? stackTrace) {
      return Image.asset(
        'assets/ic_default_avatar.png',
        width: 40,
        height: 40,
      );
    },
  );
}

longClick(
    UIMsg uiMsg, BuildContext context, LongPressStartDetails details) async {
  List<PopupItem> items = [];
  items.add(PopupItem(
    text: '删除',
    onTap: () {
      HttpUtils.deleteMsg(
          uiMsg.wkMsg.clientMsgNO,
          uiMsg.wkMsg.channelID,
          uiMsg.wkMsg.channelType,
          uiMsg.wkMsg.messageSeq,
          uiMsg.wkMsg.messageID);
    },
  ));
  if (uiMsg.wkMsg.fromUID == UserInfo.uid &&
      uiMsg.wkMsg.status == WKSendMsgResult.sendSuccess) {
    items.add(PopupItem(
      text: '撤回',
      onTap: () {
        HttpUtils.revokeMsg(
            uiMsg.wkMsg.clientMsgNO,
            uiMsg.wkMsg.channelID,
            uiMsg.wkMsg.channelType,
            uiMsg.wkMsg.messageSeq,
            uiMsg.wkMsg.messageID);
      },
    ));
  }
  await PopmenuUtil.showPopupMenu(context, details, items);
}

Widget orderView(UIMsg uiMsg, BuildContext context) {
  var leftMargin = 60.0;
  var rightMargin = 5.0;
  if (uiMsg.wkMsg.fromUID != UserInfo.uid) {
    leftMargin = 10.0;
    rightMargin = 60.0;
  }
  var orderContent = uiMsg.wkMsg.messageContent as OrderMsg;
  return Expanded(
    child: GestureDetector(
      onLongPressStart: (details) {
        longClick(uiMsg, context, details);
      },
      child: Container(
        padding: const EdgeInsets.only(left: 5, top: 5, right: 5, bottom: 5),
        margin: EdgeInsets.only(
            left: leftMargin, top: 0, right: rightMargin, bottom: 0),
        decoration: const BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.all(Radius.circular(12)),
            color: Color.fromARGB(255, 250, 250, 250)),
        alignment: Alignment.centerLeft,
        child: Column(
          children: [
            Container(
              margin:
                  const EdgeInsets.only(left: 5, top: 5, right: 5, bottom: 5),
              alignment: Alignment.centerLeft,
              child: Text(
                '订单号：${orderContent.orderNo}',
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              margin:
                  const EdgeInsets.only(left: 5, top: 5, right: 5, bottom: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Image.network(
                    orderContent.imgUrl,
                    height: 80,
                    width: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (BuildContext context, Object exception,
                        StackTrace? stackTrace) {
                      return Image.asset('assets/ic_default_avatar.png');
                    },
                  ),
                  Expanded(
                      child: Container(
                    margin: const EdgeInsets.only(
                        left: 10, top: 5, right: 0, bottom: 5),
                    child: Column(
                      children: [
                        Text(
                          '商品名称：${orderContent.title}',
                          softWrap: true,
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Text("\$${orderContent.price}",
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 100.0),
                            Text('共${orderContent.num}件',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  ))
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget getRevokedView(UIMsg uiMsg, BuildContext context) {
  return Container(
    alignment: Alignment.center,
    margin: const EdgeInsets.only(left: 60, top: 10, right: 60, bottom: 10),
    child: const Text('消息被撤回',
        style: TextStyle(
            color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
  );
}

Widget getSendView(UIMsg uiMsg, BuildContext context) {
  if (uiMsg.wkMsg.contentType == 56) {
    return orderView(uiMsg, context);
  } else {
    return sendTextView(uiMsg, context);
  }
}

Widget getRecvView(UIMsg uiMsg, BuildContext context) {
  if (uiMsg.wkMsg.contentType == 56) {
    return orderView(uiMsg, context);
  } else {
    return recvTextView(uiMsg, context);
  }
}

Widget recvTextView(UIMsg uiMsg, BuildContext context) {
  return Expanded(
    child: GestureDetector(
      onLongPressStart: (details) {
        longClick(uiMsg, context, details);
      },
      child: Container(
        alignment: Alignment.centerLeft,
        margin: const EdgeInsets.only(left: 10, top: 0, right: 60, bottom: 0),
        child: Container(
          padding:
              const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 5),
          decoration: const BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.all(Radius.circular(12)),
              color: Color.fromARGB(255, 163, 33, 243)),
          child: Column(
            children: [
              Container(
                alignment: Alignment.topLeft,
                child: Text(
                  uiMsg.getShowContent(),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    uiMsg.getShowTime(),
                    style: const TextStyle(
                        color: Color.fromARGB(255, 226, 215, 215),
                        fontSize: 12),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    ),
  );
}

Widget sendTextView(UIMsg uiMsg, BuildContext context) {
  var alignment = Alignment.bottomRight;
  if (uiMsg.wkMsg.fromUID != UserInfo.uid) {
    alignment = Alignment.centerLeft;
  }
  return Expanded(
    child: GestureDetector(
      onLongPressStart: (details) {
        longClick(uiMsg, context, details);
      },
      child: Container(
        padding: const EdgeInsets.only(left: 5, top: 3, right: 5, bottom: 3),
        margin: const EdgeInsets.only(left: 60, top: 0, right: 5, bottom: 0),
        decoration: const BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.all(Radius.circular(12)),
            color: Color.fromARGB(255, 9, 75, 243)),
        alignment: alignment,
        child: Column(
          children: [
            Container(
              alignment: Alignment.centerLeft,
              child: Text(
                uiMsg.getShowContent(),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  uiMsg.getShowTime(),
                  style: const TextStyle(
                      color: Color.fromARGB(255, 226, 215, 215), fontSize: 12),
                ),
                Image(
                    image: AssetImage(uiMsg.getStatusIV()),
                    width: 30,
                    height: 30)
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
