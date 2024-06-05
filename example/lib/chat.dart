import 'dart:ffi';

import 'package:example/const.dart';
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/proto/proto.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'custom_message.dart';
import 'msg.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatChannel channel =
        ModalRoute.of(context)!.settings.arguments as ChatChannel;
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.redAccent,
      ),
      home: ChatList(channel.channelID, channel.channelType),
    );
  }
}

class ChatList extends StatefulWidget {
  String channelID;
  int channelType = 0;
  ChatList(this.channelID, this.channelType, {super.key});

  @override
  State<StatefulWidget> createState() {
    return ChatListDataState(channelID, channelType);
  }
}

class ChatListDataState extends State<ChatList> {
  String channelID;
  int channelType = 0;
  final ScrollController _scrollController = ScrollController();

  ChatListDataState(this.channelID, this.channelType) {
    WKIM.shared.channelManager
        .getChannel(channelID, channelType)
        .then((channel) {
      print(channel?.localExtra);
      print(channel?.remoteExtraMap);
      WKIM.shared.channelManager.fetchChannelInfo(channelID, channelType);
      if (channelType == WKChannelType.group) {
        title = '${channel?.channelName}';
      } else {
        title = '${channel?.channelName}';
      }
    });
  }
  List<UIMsg> msgList = [];
  String title = '';

  @override
  void initState() {
    super.initState();
    initListener();
    getMsgList(0, 0, true);
  }

  initListener() {
    WKIM.shared.messageManager.addOnMsgInsertedListener((wkMsg) {
      setState(() {
        msgList.add(UIMsg(wkMsg));
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    });
    WKIM.shared.messageManager.addOnNewMsgListener('chat', (msgs) {
      setState(() {
        for (var i = 0; i < msgs.length; i++) {
          if (msgs[i].setting.receipt == 1) {
            // 消息需要回执
            testReceipt(msgs[i]);
          }
          if (msgs[i].isDeleted == 0) {
            msgList.add(UIMsg(msgs[i]));
          }
        }
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    });
    WKIM.shared.messageManager.addOnRefreshMsgListener('chat', (wkMsg) {
      for (var i = 0; i < msgList.length; i++) {
        if (msgList[i].wkMsg.clientMsgNO == wkMsg.clientMsgNO) {
          msgList[i].wkMsg.messageID = wkMsg.messageID;
          msgList[i].wkMsg.messageSeq = wkMsg.messageSeq;
          msgList[i].wkMsg.status = wkMsg.status;
          msgList[i].wkMsg.wkMsgExtra = wkMsg.wkMsgExtra;
          break;
        }
      }
      setState(() {});
    });
    // 清除聊天记录
    WKIM.shared.messageManager.addOnClearChannelMsgListener("chat",
        (channelId, channelType) {
      if (channelID == channelId) {
        msgList.clear();
        setState(() {});
      }
    });
  }

  // 模拟同步消息扩展后保存到db
  testReceipt(WKMsg wkMsg) async {
    if (wkMsg.viewed == 0) {
      var maxVersion = await WKIM.shared.messageManager
          .getMaxExtraVersionWithChannel(channelID, channelType);
      var extra = WKMsgExtra();
      extra.messageID = wkMsg.messageID;
      extra.channelID = channelID;
      extra.channelType = channelType;
      extra.readed = 1;
      extra.readedCount = 1;
      extra.extraVersion = maxVersion + 1;
      List<WKMsgExtra> list = [];
      list.add(extra);
      WKIM.shared.messageManager.saveRemoteExtraMsg(list);
    }
  }

  getPrevious() {
    var oldOrderSeq = 0;
    for (var msg in msgList) {
      if (oldOrderSeq == 0 || oldOrderSeq > msg.wkMsg.orderSeq) {
        oldOrderSeq = msg.wkMsg.orderSeq;
      }
    }
    getMsgList(oldOrderSeq, 0, false);
  }

  getLast() {
    var oldOrderSeq = 0;
    for (var msg in msgList) {
      if (oldOrderSeq == 0 || oldOrderSeq < msg.wkMsg.orderSeq) {
        oldOrderSeq = msg.wkMsg.orderSeq;
      }
    }
    getMsgList(oldOrderSeq, 1, false);
  }

  getMsgList(int oldestOrderSeq, int pullMode, bool isReset) {
    WKIM.shared.messageManager.getOrSyncHistoryMessages(channelID, channelType,
        oldestOrderSeq, oldestOrderSeq == 0, pullMode, 5, 0, (list) {
      List<UIMsg> uiList = [];
      for (int i = 0; i < list.length; i++) {
        if (pullMode == 0 && !isReset) {
          uiList.add(UIMsg(list[i]));
          // msgList.insert(0, UIMsg(list[i]));
        } else {
          msgList.add(UIMsg(list[i]));
        }
      }
      if (uiList.isNotEmpty) {
        msgList.insertAll(0, uiList);
      }
      setState(() {});
      if (isReset) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    }, () {
      print('消息同步中');
    });
  }

  Widget _buildRow(UIMsg uiMsg) {
    if (uiMsg.wkMsg.fromUID == UserInfo.uid) {
      return Container(
        padding: const EdgeInsets.only(left: 0, top: 5, right: 0, bottom: 5),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.only(left: 5, top: 3, right: 5, bottom: 3),
                margin: const EdgeInsets.only(
                    left: 60, top: 0, right: 5, bottom: 0),
                decoration: const BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    color: Colors.blue),
                alignment: Alignment.bottomRight,
                child: Column(
                  children: [
                    Container(
                      alignment: Alignment.centerRight,
                      child: Text(
                        uiMsg.getShowContent(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          uiMsg.getShowTime(),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
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
            Container(
              decoration: const BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  color: Color.fromARGB(255, 243, 33, 131)),
              width: 50,
              alignment: Alignment.center,
              height: 50,
              margin: const EdgeInsets.fromLTRB(0, 0, 10, 0),
              child: Text(
                CommonUtils.getAvatar(uiMsg.wkMsg.fromUID),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.only(left: 0, top: 5, right: 0, bottom: 5),
        child: Row(
          children: [
            // Container(
            //   decoration: const BoxDecoration(
            //       shape: BoxShape.rectangle,
            //       borderRadius: BorderRadius.all(Radius.circular(20)),
            //       color: Color.fromARGB(255, 215, 80, 1)),
            //   width: 50,
            //   alignment: Alignment.center,
            //   height: 50,
            //   margin: const EdgeInsets.fromLTRB(0, 0, 10, 0),
            //   child: Text(
            //     CommonUtils.getAvatar(uiMsg.wkMsg.fromUID),
            //     style: const TextStyle(
            //         color: Colors.white,
            //         fontSize: 20,
            //         fontWeight: FontWeight.bold),
            //   ),
            // ),
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                margin: const EdgeInsets.only(
                    left: 0, top: 0, right: 60, bottom: 0),
                child: Container(
                  padding: const EdgeInsets.only(
                      left: 10, top: 3, right: 10, bottom: 3),
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
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            uiMsg.getShowTime(),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      );
    }
  }

  var content = '';
  final TextEditingController _textEditingController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          MaterialButton(
              child: const Text(
                '清空记录',
                style: TextStyle(color: Color.fromARGB(255, 4, 80, 194)),
              ),
              onPressed: () {
                WKIM.shared.messageManager
                    .clearWithChannel(channelID, channelType);
              }),
        ],
      ),
      body: Container(
        padding:
            const EdgeInsets.only(left: 10, top: 10, right: 10, bottom: 10),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  itemCount: msgList.length,
                  itemBuilder: (context, pos) {
                    return _buildRow(msgList[pos]);
                  }),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                      onChanged: (v) {
                        content = v;
                      },
                      controller: _textEditingController,
                      decoration: const InputDecoration(hintText: '请输入内容'),
                      autofocus: true),
                ),
                MaterialButton(
                  onPressed: () {
                    getPrevious();
                  },
                  color: Colors.brown,
                  child:
                      const Text("上一页", style: TextStyle(color: Colors.white)),
                ),
                MaterialButton(
                  onPressed: () {
                    getLast();
                  },
                  color: Colors.brown,
                  child:
                      const Text("下一页", style: TextStyle(color: Colors.white)),
                ),
                MaterialButton(
                  onPressed: () {
                    if (content != '') {
                      _textEditingController.text = '';
                      Setting setting = Setting();
                      setting.receipt = 1; //开启回执
                      // 回复
                      WKTextContent text = WKTextContent(content);
                      WKReply reply = WKReply();
                      reply.messageId = "11";
                      reply.rootMid = "111";
                      reply.fromUID = "11";
                      reply.fromName = "12";
                      WKTextContent payloadText = WKTextContent("dds");
                      reply.payload = payloadText;
                      text.reply = reply;
                      // 标记
                      List<WKMsgEntity> list = [];
                      WKMsgEntity entity = WKMsgEntity();
                      entity.offset = 0;
                      entity.value = "1";
                      entity.length = 1;
                      list.add(entity);
                      text.entities = list;
                      // 艾特
                      WKMentionInfo mentionInfo = WKMentionInfo();
                      mentionInfo.mentionAll = true;
                      mentionInfo.uids = ['uid_1', 'uid_2'];
                      text.mentionInfo = mentionInfo;
                      // CustomMsg customMsg = CustomMsg(content);
                      WKIM.shared.messageManager.sendMessageWithSetting(
                          text, WKChannel(channelID, channelType), setting);
                      // WKImageContent imageContent = WKImageContent(100, 200);
                      // imageContent.localPath = 'addskds';
                      // WKIM.shared.messageManager.sendMessage(
                      //     imageContent, WKChannel(channelID, channelType));
                      // WKCardContent cardContent = WKCardContent('333', '我333');
                      // WKIM.shared.messageManager.sendMessage(
                      //     cardContent, WKChannel(channelID, channelType));
                      // WKVideoContent videoContent = WKVideoContent();
                      // videoContent.coverLocalPath = 'coverLocalPath';
                      // videoContent.localPath = 'localPath';
                      // videoContent.height = 10;
                      // videoContent.width = 100;
                      // videoContent.size = 122;
                      // videoContent.second = 9;
                      // WKIM.shared.messageManager.sendMessage(
                      //     videoContent, WKChannel(channelID, channelType));
                      // WKVoiceContent voiceContent = WKVoiceContent(10);
                      // voiceContent.localPath = 'videoContent';
                      // voiceContent.waveform = 'waveform';
                      // WKIM.shared.messageManager.sendMessage(
                      //     voiceContent, WKChannel(channelID, channelType));
                    }
                  },
                  color: Colors.blue,
                  child: const Text(
                    '发送',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    WKIM.shared.messageManager.removeNewMsgListener('chat');
    WKIM.shared.messageManager.removeOnRefreshMsgListener('chat');
  }
}
