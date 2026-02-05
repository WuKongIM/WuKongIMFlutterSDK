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
    return ChatList(channel.channelID, channel.channelType);
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
      print("扩展：${channel?.localExtra}");
      print("扩展1：${channel?.remoteExtraMap}");
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

  Widget _buildRow(UIMsg uiMsg, BuildContext context) {
    if (uiMsg.wkMsg.wkMsgExtra?.revoke == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: getRevokedView(uiMsg, context),
      );
    }
    if (uiMsg.wkMsg.fromUID == UserInfo.uid) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: getSendView(uiMsg, context),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: chatAvatar(uiMsg),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: chatAvatar(uiMsg),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: getRecvView(uiMsg, context),
            ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1D1D1F), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1D1D1F)),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1D1D1F),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Color(0xFF1D1D1F)),
            onSelected: (value) => {
              if (value == '清空聊天记录')
                {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          backgroundColor: Colors.white,
                          title: const Text('确认清空聊天记录？'),
                          content: const Text('清空后将无法恢复，确定要清空吗?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                '取消',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                HttpUtils.clearChannelMsg(
                                    channelID, channelType);
                              },
                              child: const Text('确认',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
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
            SizedBox(
              width: 45,
              height: 45,
              child: FloatingActionButton(
                heroTag: 'previous',
                onPressed: () {
                  getPrevious();
                },
                tooltip: '上一页',
                backgroundColor: Colors.white.withOpacity(0.8),
                elevation: 2,
                child: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF0584FE)),
              ),
            ),
            const SizedBox(height: 10.0),
            SizedBox(
              width: 45,
              height: 45,
              child: FloatingActionButton(
                heroTag: 'next',
                onPressed: () {
                  getLast();
                },
                backgroundColor: Colors.white.withOpacity(0.8),
                elevation: 2,
                tooltip: '下一页',
                child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF0584FE)),
              ),
            ),
            const SizedBox(height: 80.0),
          ]),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  itemCount: msgList.length,
                  itemBuilder: (context, pos) {
                    return _buildRow(msgList[pos], context);
                  }),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                          onChanged: (v) {
                            content = v;
                          },
                          controller: _textEditingController,
                          decoration: const InputDecoration(
                            hintText: '输入消息...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                          style: const TextStyle(fontSize: 15),
                          maxLines: null,
                          autofocus: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
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
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.card_giftcard, color: Colors.orange, size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (content != '') {
                        _textEditingController.text = '';
                        Setting setting = Setting();
                        setting.receipt = 1; //开启回执
                        WKTextContent text = WKTextContent(content);
                        var option = WKSendOptions();
                        option.setting = setting;
                        WKIM.shared.messageManager.sendWithOption(
                            text, WKChannel(channelID, channelType), option);
                        content = '';
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0584FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
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

Widget _buildItem(UIMsg uiMsg, BuildContext context) {
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ChatPage(),
          settings: RouteSettings(
            arguments: ChatChannel(
              uiMsg.wkMsg.channelID,
              uiMsg.wkMsg.channelType,
            ),
          ),
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              getChannelAvatarURL(uiMsg),
              height: 50,
              width: 50,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object exception,
                  StackTrace? stackTrace) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/ic_default_avatar.png',
                    width: 50,
                    height: 50,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uiMsg.wkMsg.getFrom()?.channelName ?? '未知用户',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  uiMsg.getShowContent(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            uiMsg.getShowTime(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
}
