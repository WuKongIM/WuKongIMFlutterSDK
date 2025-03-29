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
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Image.network(
      getChannelAvatarURL(uiMsg),
      height: 40,
      width: 40,
      fit: BoxFit.cover,
      errorBuilder:
          (BuildContext context, Object exception, StackTrace? stackTrace) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/ic_default_avatar.png',
            width: 40,
            height: 40,
          ),
        );
      },
    ),
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
  return GestureDetector(
    onLongPressStart: (details) {
      longClick(uiMsg, context, details);
    },
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.only(
        left: leftMargin,
        top: 0,
        right: rightMargin,
        bottom: 0,
      ),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 250, 250, 250),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft: uiMsg.wkMsg.fromUID == UserInfo.uid
              ? const Radius.circular(22)
              : const Radius.circular(0),
          bottomRight: uiMsg.wkMsg.fromUID == UserInfo.uid
              ? const Radius.circular(0)
              : const Radius.circular(22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '订单号：${orderContent.orderNo}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  orderContent.imgUrl,
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object exception,
                      StackTrace? stackTrace) {
                    return Image.asset(
                      'assets/ic_default_avatar.png',
                      width: 80,
                      height: 80,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderContent.title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "\$${orderContent.price}",
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '共${orderContent.num}件',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
  return GestureDetector(
    onLongPressStart: (details) {
      longClick(uiMsg, context, details);
    },
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.zero,
          bottomRight: Radius.circular(22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            uiMsg.getShowContent(),
            style: const TextStyle(color: Colors.black87, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            uiMsg.getShowTime(),
            style: const TextStyle(color: Colors.black45, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

Widget sendTextView(UIMsg uiMsg, BuildContext context) {
  return GestureDetector(
    onLongPressStart: (details) {
      longClick(uiMsg, context, details);
    },
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0584FE),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.zero,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            uiMsg.getShowContent(),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                uiMsg.getShowTime(),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 4),
              Image(
                image: AssetImage(uiMsg.getStatusIV()),
                width: 16,
                height: 16,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
