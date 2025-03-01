import 'package:example/const.dart';
import 'package:example/http.dart';
import 'package:example/order_message_content.dart';
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/proto/proto.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'chatview.dart';
import 'msg.dart';
import 'ui_input_dialog.dart';

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
      WKIM.shared.channelManager.fetchChannelInfo(channelID, channelType);
      title = '${channel?.channelName}';
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
    // 监听刷新频道
    WKIM.shared.channelManager.addOnRefreshListener('chat', (channel) {
      if (channelID == channel.channelID) {
        title = channel.channelName;
      }
      for (var i = 0; i < msgList.length; i++) {
        if (msgList[i].wkMsg.fromUID == channel.channelID) {
          msgList[i].wkMsg.setFrom(channel);
        }
      }
      setState(() {});
    });

    // 监听发送消息入库返回
    WKIM.shared.messageManager.addOnMsgInsertedListener((wkMsg) {
      setState(() {
        msgList.add(UIMsg(wkMsg));
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    });

    // 监听新消息
    WKIM.shared.messageManager.addOnNewMsgListener('chat', (msgs) {
      print('收到${msgs.length}条新消息');
      setState(() {
        for (var i = 0; i < msgs.length; i++) {
          if (msgs[i].channelID != channelID) {
            continue;
          }
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

    // 监听消息刷新
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

    // 监听删除消息
    WKIM.shared.messageManager.addOnDeleteMsgListener('chat', (clientMsgNo) {
      for (var i = 0; i < msgList.length; i++) {
        if (msgList[i].wkMsg.clientMsgNO == clientMsgNo) {
          setState(() {
            msgList.removeAt(i);
          });
          break;
        }
      }
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
      print('同步完成${list.length}条消息');
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
    if (uiMsg.wkMsg.wkMsgExtra?.revoke == 1) {
      return getRevokedView(uiMsg, context);
    }
    if (uiMsg.wkMsg.fromUID == UserInfo.uid) {
      return Container(
        padding: const EdgeInsets.only(left: 0, top: 5, right: 0, bottom: 5),
        child: Row(
          children: [
            getSendView(uiMsg, context),
            chatAvatar(uiMsg),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.only(left: 0, top: 5, right: 0, bottom: 5),
        child: Row(
          children: [chatAvatar(uiMsg), getRecvView(uiMsg, context)],
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
          PopupMenuButton<String>(
            onSelected: (value) => {
              if (value == '清空聊天记录')
                {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          backgroundColor: Colors.white,
                          title: const Text('确认清空聊天记录？'),
                          content: const Text('清空后将无法恢复，确定要清空吗?'),
                          actions: <Widget>[
                            GestureDetector(
                              child: const Text(
                                '取消',
                                style: TextStyle(
                                    color: Color.fromARGB(255, 113, 112, 112),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            GestureDetector(
                              child: Container(
                                margin: const EdgeInsets.only(left: 20),
                                child: const Text('确认',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                HttpUtils.clearChannelMsg(
                                    channelID, channelType);
                              },
                            ),
                          ],
                        );
                      })
                }
              else if (value == '修改群名称')
                {showUpdateChannelNameDialog(context)}
            },
            itemBuilder: (context) {
              return getPopuMenuItems();
            },
          )
        ],
      ),
      floatingActionButton: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'previous',
              onPressed: () {
                getPrevious();
              },
              tooltip: '上一页',
              backgroundColor: Colors.white,
              child: const Icon(Icons.vertical_align_top),
            ),
            const SizedBox(height: 10.0),
            FloatingActionButton(
              heroTag: 'next',
              onPressed: () {
                getLast();
              },
              backgroundColor: Colors.white,
              tooltip: '下一页',
              child: const Icon(Icons.vertical_align_bottom),
            ),
            const SizedBox(height: 70.0),
          ]),
      body: Container(
        padding:
            const EdgeInsets.only(left: 10, top: 10, right: 10, bottom: 10),
        color: const Color.fromARGB(255, 221, 221, 221),
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
                    DateTime now = DateTime.now();
                    var orderMsg = OrderMsg();
                    orderMsg.title = "问界M9纯电版 旗舰SUV 2024款 3.0L 自动 豪华版";
                    orderMsg.num = 300;
                    orderMsg.price = 20;
                    orderMsg.orderNo = '${now.millisecondsSinceEpoch}';
                    orderMsg.imgUrl =
                        "https://img0.baidu.com/it/u=4245434814,3643211003&fm=253&fmt=auto&app=120&f=JPEG?w=674&h=500";
                    WKIM.shared.messageManager.sendMessage(
                        orderMsg, WKChannel(channelID, channelType));
                  },
                  color: Colors.brown,
                  child: const Text("自定义消息",
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10.0),
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
                      var option = WKSendOptions();
                      option.setting = setting;
                      WKIM.shared.messageManager.sendWithOption(
                          text, WKChannel(channelID, channelType), option);

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

  getPopuMenuItems() {
    var list = <PopupMenuItem<String>>[];
    list.add(const PopupMenuItem<String>(
      value: '清空聊天记录',
      child: Text('清空聊天记录'),
    ));
    if (channelType == WKChannelType.group) {
      list.add(const PopupMenuItem<String>(
        value: '修改群名称',
        child: Text('修改群名称'),
      ));
    }
    return list;
  }

  showUpdateChannelNameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => InputDialog(
        title: const Text("请输入群名称"),
        isOnlyText: true,
        hintText: '请输入群名称',
        back: (name, channelType) {
          HttpUtils.updateGroupName(channelID, name);
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    // 移出监听
    WKIM.shared.messageManager.removeNewMsgListener('chat');
    WKIM.shared.messageManager.removeOnRefreshMsgListener('chat');
    WKIM.shared.messageManager.removeDeleteMsgListener('chat');
    WKIM.shared.channelManager.removeOnRefreshListener('chat');
  }
}
