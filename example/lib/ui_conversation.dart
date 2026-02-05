import 'dart:convert';

import 'package:example/const.dart';
import 'package:example/http.dart';
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'popmenu_util.dart';
import 'popup_item.dart';
import 'ui_chat.dart';
import 'conversation_msg.dart';
import 'ui_input_dialog.dart';

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
  var allUnreadCount = 0;
  var nodeId = 0;
  _initListener() {
    // 监听连接状态事件
    WKIM.shared.connectionManager.addOnConnectionStatus('home',
        (status, reason, connInfo) {
      if (status == WKConnectStatus.connecting) {
        _connectionStatusStr = '连接中...';
      } else if (status == WKConnectStatus.success) {
        if (connInfo != null) {
          nodeId = connInfo.nodeId;
        }
        _connectionStatusStr = '连接成功(节点:${connInfo?.nodeId})';
      } else if (status == WKConnectStatus.noNetwork) {
        _connectionStatusStr = '网络异常';
      } else if (status == WKConnectStatus.syncMsg) {
        _connectionStatusStr = '同步消息中...';
      } else if (status == WKConnectStatus.kicked) {
        _connectionStatusStr = '未连接，在其他设备登录';
      } else if (status == WKConnectStatus.fail) {
        _connectionStatusStr = '未连接';
      } else if (status == WKConnectStatus.syncCompleted) {
        _connectionStatusStr = '连接成功(节点:$nodeId)';
         WKIM.shared.conversationManager.getAllUnreadCount().then((value) {
      allUnreadCount = value;
    });
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

      // 清除红点后也重新排序，保持列表排序的一致性
      _sortMessagesByTimestamp();

      setState(() {});
    });
    WKIM.shared.conversationManager
        .addOnRefreshMsgListListener('chat_conversation', (msgs) async {
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
            msgList[i].reminders = null;
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

      _sortMessagesByTimestamp();

      if (mounted) {
        setState(() {});
      }
    });

    // 监听刷新channel资料事件
    WKIM.shared.channelManager.addOnRefreshListener("cover_chat", (channel) {
      for (var i = 0; i < msgList.length; i++) {
        if (msgList[i].msg.channelID == channel.channelID &&
            msgList[i].msg.channelType == channel.channelType) {
          msgList[i].msg.setWkChannel(channel);
          msgList[i].channelAvatar = "${HttpUtils.apiURL}/${channel.avatar}";
          msgList[i].channelName = channel.channelName;
          msgList[i].top = channel.top;
          msgList[i].mute = channel.mute;
          // 刷新频道信息后重新排序（虽然时间戳没变，但保持一致性）
          _sortMessagesByTimestamp();

          setState(() {});
          break;
        }
      }
    });
  }

  /// 对会话列表按时间戳排序，最新的会话排在前面
  void _sortMessagesByTimestamp() {
    msgList.sort(
        (a, b) => b.msg.lastMsgTimestamp.compareTo(a.msg.lastMsgTimestamp));
  }

  void _getDataList() {
    Future<List<WKUIConversationMsg>> list =
        WKIM.shared.conversationManager.getAll();
    list.then((result) {
      for (var i = 0; i < result.length; i++) {
        msgList.add(UIConversation(result[i]));
      }

      _sortMessagesByTimestamp();
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
    if (uiConversation.reminders == null) {
      uiConversation.msg.getReminderList().then((value) {
        uiConversation.reminders = value;
        setState(() {});
      });
      return content;
    }
    if (uiConversation.reminders!.isNotEmpty) {
      for (var i = 0; i < uiConversation.reminders!.length; i++) {
        if (uiConversation.reminders![i].type ==
                WKMentionType.wkReminderTypeMentionMe &&
            uiConversation.reminders![i].done == 0) {
          var d = uiConversation.reminders![i].data;
          if (d is Map) {
            content = d['type'];
          } else if (d is String && WKDBConst.isJsonString(d)) {
            var obj = jsonDecode(d);
            content = obj['type'];
          } else {
            content = d;
          }
          // content = uiConversation.reminders![i].data;
          break;
        }
      }
    }
    return content;
  }

  String getChannelAvatarURL(UIConversation uiConversation) {
    if (uiConversation.channelAvatar == '') {
      uiConversation.msg.getWkChannel().then((channel) {
        if (channel != null) {
          uiConversation.channelAvatar =
              "${HttpUtils.apiURL}/${channel.avatar}";
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
          if (uiConversation.channelName == '') {
            WKIM.shared.channelManager.fetchChannelInfo(
                uiConversation.msg.channelID, uiConversation.msg.channelType);
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
      color: Colors.white,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFF0584FE).withOpacity(0.1),
                    ),
                    width: 55,
                    height: 55,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        getChannelAvatarURL(uiMsg),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              getChannelName(uiMsg).isNotEmpty
                                  ? getChannelName(uiMsg).substring(0, 1)
                                  : "?",
                              style: const TextStyle(
                                color: Color(0xFF0584FE),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (uiMsg.msg.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.white, width: 2),
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          uiMsg.msg.unreadCount > 99
                              ? '99+'
                              : '${uiMsg.msg.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            getChannelName(uiMsg),
                            style: const TextStyle(
                              color: Color(0xFF1D1D1F),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          CommonUtils.formatDateTime(uiMsg.msg.lastMsgTimestamp)
                              .split(' ')
                              .last,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (getReminderText(uiMsg).isNotEmpty)
                          Text(
                            '[${getReminderText(uiMsg)}] ',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            getShowContent(uiMsg),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (uiMsg.mute == 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.notifications_off_outlined,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        if (uiMsg.top == 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.push_pin_outlined,
                              size: 14,
                              color: Colors.orange.shade300,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              _connectionStatusStr,
              style: const TextStyle(
                color: Color(0xFF1D1D1F),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '用户:${UserInfo.name} • 未读($allUnreadCount)',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        itemCount: msgList.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 83,
          color: Colors.grey.shade100,
        ),
        itemBuilder: (context, pos) {
          return GestureDetector(
            onLongPressStart: (details) {
              longClick(msgList[pos], context, details);
            },
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
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showDialog(context);
        },
        backgroundColor: const Color(0xFF0584FE),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      persistentFooterButtons: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextButton.icon(
                  onPressed: () => WKIM.shared.connectionManager.disconnect(false),
                  icon: const Icon(Icons.power_settings_new, color: Colors.red),
                  label: const Text('断开', style: TextStyle(color: Colors.red)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextButton.icon(
                  onPressed: () => WKIM.shared.connectionManager.connect(),
                  icon: const Icon(Icons.refresh, color: Color(0xFF0584FE)),
                  label: const Text('重连', style: TextStyle(color: Color(0xFF0584FE))),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF0584FE).withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => InputDialog(
        title: const Text("创建新的聊天"),
        back: (channelID, channelType) async {
          bool isSuccess = await HttpUtils.createGroup(channelID);
          if (isSuccess) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatPage(),
                settings: RouteSettings(
                  arguments: ChatChannel(
                    channelID,
                    channelType,
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  longClick(UIConversation uiMsg, BuildContext context,
      LongPressStartDetails details) {
    List<PopupItem> items = [];
    if (uiMsg.msg.unreadCount > 0) {
      items.add(PopupItem(
        text: '设置已读',
        onTap: () {
          HttpUtils.clearUnread(uiMsg.msg.channelID, uiMsg.msg.channelType);
        },
      ));
    }
    items.add(PopupItem(
        text: '测试提醒项',
        onTap: () {
          List<WKReminder> list = [];
          WKReminder reminder = WKReminder();
          reminder.needUpload = 0;
          reminder.type = WKMentionType.wkReminderTypeMentionMe;
          //  reminder.data = '[有人@你]';
          reminder.done = 0;
          reminder.reminderID = 11;
          reminder.version = 1;
          reminder.publisher = "uid_1";
          reminder.channelID = uiMsg.msg.channelID;
          reminder.channelType = uiMsg.msg.channelType;
          // 这两种都可以
          reminder.data = "[有人@你]";
          // reminder.data = jsonEncode({"type": "[有人@你]"});
          list.add(reminder);
          WKIM.shared.reminderManager.saveOrUpdateReminders(list);
        }));
    // 新增测试置顶
    items.add(PopupItem(
      text: '测试置顶',
      onTap: () async {
        WKChannel? channel = await uiMsg.msg.getWkChannel();
        if (channel != null) {
          channel.top = channel.top == 1 ? 0 : 1;
          WKIM.shared.channelManager.addOrUpdateChannel(channel);
        }
      },
    ));
    // 新增测试免打扰
    items.add(PopupItem(
      text: '测试免打扰',
      onTap: () async {
        WKChannel? channel = await uiMsg.msg.getWkChannel();
        if (channel != null) {
          channel.mute = channel.mute == 1 ? 0 : 1;
          WKIM.shared.channelManager.addOrUpdateChannel(channel);
          uiMsg.msg.setWkChannel(channel);
        }
      },
    ));

    PopmenuUtil.showPopupMenu(context, details, items);
  }
}
