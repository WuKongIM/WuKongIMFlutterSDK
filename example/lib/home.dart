import 'package:example/const.dart';
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'chat.dart';
import 'contestation.dart';
import 'input_dialog.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.redAccent,
      ),
      home: const ListViewShowData(),
    );
  }
}

class ListViewShowData extends StatefulWidget {
  const ListViewShowData({super.key});

  @override
  State<StatefulWidget> createState() {
    return ListViewShowDataState();
  }
}

class ListViewShowDataState extends State<ListViewShowData> {
  List<UIConversation> msgList = [];
  @override
  void initState() {
    super.initState();
    _getDataList();
    _initListener();
  }

  var _connectionStatusStr = '';
  _initListener() {
    // 监听连接状态事件
    WKIM.shared.connectionManager.addOnConnectionStatus('home',
        (status, reason) {
      if (status == WKConnectStatus.connecting) {
        _connectionStatusStr = '连接中...';
      } else if (status == WKConnectStatus.success) {
        _connectionStatusStr = '最近会话【连接成功】';
      } else if (status == WKConnectStatus.noNetwork) {
        _connectionStatusStr = '网络异常';
      } else if (status == WKConnectStatus.syncMsg) {
        _connectionStatusStr = '同步消息中...';
      } else if (status == WKConnectStatus.kicked) {
        _connectionStatusStr = '未连接，在其他设备登录';
      } else if (status == WKConnectStatus.fail) {
        _connectionStatusStr = '未连接';
      }
      if (mounted) {
        setState(() {});
      }
    });
    WKIM.shared.conversationManager
        .addOnClearAllRedDotListener("chat_conversation", () {
      for (var i = 0; i < msgList.length; i++) {
        msgList[i].msg.unreadCount = 0;
      }
      setState(() {});
    });
    WKIM.shared.conversationManager
        .addOnRefreshMsgListListener('chat_conversation', (msgs) {
      if (msgs.isEmpty) {
        return;
      }
      List<UIConversation> list = [];
      for (WKUIConversationMsg msg in msgs) {
        bool isAdd = true;
        for (var i = 0; i < msgList.length; i++) {
          if (msgList[i].msg.channelID == msg.channelID) {
            msgList[i].msg = msg;
            msgList[i].lastContent = '';
            isAdd = false;
            break;
          }
        }
        if (isAdd) {
          list.add(UIConversation(msg));
        }
      }
      if (list.isNotEmpty) {
        msgList.addAll(list);
      }
      if (mounted) {
        setState(() {});
      }
    });
    // 监听更新消息事件
    // WKIM.shared.conversationManager.addOnRefreshMsgListener('chat_conversation',
    //     (msg, isEnd) async {
    //   bool isAdd = true;
    //   for (var i = 0; i < msgList.length; i++) {
    //     if (msgList[i].msg.channelID == msg.channelID &&
    //         msgList[i].msg.channelType == msg.channelType) {
    //       msgList[i].msg = msg;
    //       msgList[i].lastContent = '';
    //       isAdd = false;
    //       break;
    //     }
    //   }
    //   if (isAdd) {
    //     msgList.add(UIConversation(msg));
    //   }
    //   if (isEnd && mounted) {
    //     setState(() {});
    //   }
    // });
    // 监听刷新channel资料事件
    WKIM.shared.channelManager.addOnRefreshListener("cover_chat", (channel) {
      for (var i = 0; i < msgList.length; i++) {
        if (msgList[i].msg.channelID == channel.channelID &&
            msgList[i].msg.channelType == channel.channelType) {
          msgList[i].msg.setWkChannel(channel);
          msgList[i].channelAvatar = channel.avatar;
          msgList[i].channelName = channel.channelName;
          setState(() {});
          break;
        }
      }
    });
  }

  void _getDataList() {
    Future<List<WKUIConversationMsg>> list =
        WKIM.shared.conversationManager.getAll();
    list.then((result) {
      for (var i = 0; i < result.length; i++) {
        msgList.add(UIConversation(result[i]));
      }

      setState(() {});
    });
  }

  String getShowContent(UIConversation uiConversation) {
    if (uiConversation.lastContent == '') {
      uiConversation.msg.getWkMsg().then((value) {
        if (value != null && value.messageContent != null) {
          uiConversation.lastContent = value.messageContent!.displayText();
          setState(() {});
        }
      });
      return '';
    }
    return uiConversation.lastContent;
  }

  String getReminderText(UIConversation uiConversation) {
    String content = "";
    if (uiConversation.isMentionMe == 0) {
      uiConversation.msg.getReminderList().then((value) {
        if (value != null && value.isNotEmpty) {
          for (var i = 0; i < value.length; i++) {
            if (value[i].type == WKMentionType.wkReminderTypeMentionMe &&
                value[i].done == 0) {
              content = value[i].data;
              uiConversation.isMentionMe = 1;
              setState(() {});
              break;
            }
          }
        }
      });
    } else {
      content = "[有人@你]";
    }
    return content;
  }

  String getChannelAvatarURL(UIConversation uiConversation) {
    if (uiConversation.channelAvatar == '') {
      uiConversation.msg.getWkChannel().then((channel) {
        if (channel != null) {
          uiConversation.channelAvatar = channel.avatar;
        }
      });
    }
    return uiConversation.channelAvatar;
  }

  String getChannelName(UIConversation uiConversation) {
    if (uiConversation.channelName == '') {
      uiConversation.msg.getWkChannel().then((channel) {
        if (channel != null) {
          if (channel.channelRemark == '') {
            uiConversation.channelName = channel.channelName;
          } else {
            uiConversation.channelName = channel.channelRemark;
          }
        } else {
          WKIM.shared.channelManager.fetchChannelInfo(
              uiConversation.msg.channelID, uiConversation.msg.channelType);
        }
      });
    }
    return uiConversation.channelName;
  }

  Widget _buildRow(UIConversation uiMsg) {
    return Container(
        margin: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  color: Colors.blue),
              width: 50,
              alignment: Alignment.center,
              height: 50,
              margin: const EdgeInsets.fromLTRB(0, 0, 10, 0),
              child: Image.network(
                getChannelAvatarURL(uiMsg),
                height: 200,
                width: 200,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object exception,
                    StackTrace? stackTrace) {
                  return Image.asset('assets/ic_default_avatar.png');
                },
              ),
            ),
            Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        getChannelName(uiMsg),
                        style:
                            const TextStyle(color: Colors.black, fontSize: 18),
                        maxLines: 1,
                      ),
                      Expanded(
                        child: Text(
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 16),
                          CommonUtils.formatDateTime(
                              uiMsg.msg.lastMsgTimestamp),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        getReminderText(uiMsg),
                        style: const TextStyle(
                            color: Color.fromARGB(255, 247, 2, 2),
                            fontSize: 14),
                        maxLines: 1,
                      ),
                      Text(
                        getShowContent(uiMsg),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                        maxLines: 1,
                      ),
                      Expanded(
                        child: Text(
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          uiMsg.getUnreadCount(),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  )
                ]))
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_connectionStatusStr),
      ),
      body: ListView.builder(
          shrinkWrap: true,
          itemCount: msgList.length,
          itemBuilder: (context, pos) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatPage(),
                    settings: RouteSettings(
                      arguments: ChatChannel(
                        msgList[pos].msg.channelID,
                        msgList[pos].msg.channelType,
                      ),
                    ),
                  ),
                );
              },
              child: _buildRow(msgList[pos]),
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showDialog(context);
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
      persistentFooterButtons: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 240, 117, 2),
          ),
          onPressed: () {
            WKIM.shared.conversationManager.clearAllRedDot();
          },
          child: const Text(
            '清除未读',
            style: TextStyle(color: Colors.white),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 240, 2, 133),
          ),
          onPressed: () {
            if (msgList.isEmpty) {
              return;
            }

            List<WKReminder> list = [];
            WKReminder reminder = WKReminder();
            reminder.needUpload = 0;
            reminder.type = WKMentionType.wkReminderTypeMentionMe;
            reminder.data = '[有人@你]';
            reminder.done = 0;
            reminder.reminderID = 11;
            reminder.version = 1;
            reminder.publisher = "uid_1";
            reminder.channelID = msgList[0].msg.channelID;
            reminder.channelType = msgList[0].msg.channelType;
            list.add(reminder);
            WKIM.shared.reminderManager.saveOrUpdateReminders(list);
          },
          child: const Text(
            '提醒项',
            style: TextStyle(color: Colors.white),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          onPressed: () {
            WKIM.shared.connectionManager.disconnect(false);
          },
          child: const Text(
            '断开',
            style: TextStyle(color: Colors.white),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 31, 27, 239),
          ),
          onPressed: () {
            WKIM.shared.connectionManager.connect();
          },
          child: const Text(
            '重连',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => InputDialog(
        title: const Text("创建新的聊天"),
        back: (channelID, channelType) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(),
              settings: RouteSettings(
                arguments: ChatChannel(
                  channelID,
                  channelType,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
