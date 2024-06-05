import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:example/const.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

class HttpUtils {
  static String apiURL = "https://api.githubim.com";

  static Future<int> login(String uid, String token) async {
    final dio = Dio();
    final response = await dio.post("$apiURL/user/token", data: {
      'uid': uid,
      'token': token,
      'device_flag': 0,
      'device_level': 1
    });
    return response.statusCode!;
  }

  static Future<String> getIP() async {
    final dio = Dio();
    String ip = '';
    final response = await dio.get('$apiURL/route');
    if (response.statusCode == HttpStatus.ok) {
      ip = response.data['tcp_addr'];
    }
    return ip;
  }

  static syncConversation(String lastSsgSeqs, int msgCount, int version,
      Function(WKSyncConversation) back) async {
    final dio = Dio();
    final response = await dio.post('$apiURL/conversation/sync', data: {
      "uid": UserInfo.uid, // 当前登录用户uid
      "version": version, //  当前客户端的会话最大版本号(从保存的结果里取最大的version，如果本地没有数据则传0)，
      "last_msg_seqs":
          lastSsgSeqs, //   客户端所有频道会话的最后一条消息序列号拼接出来的同步串 格式： channelID:channelType:last_msg_seq|channelID:channelType:last_msg_seq  （此字段非必填，如果不填就获取全量数据，填写了获取增量数据，看你自己的需求。）
      "msg_count": 10 // 每个会话获取最大的消息数量，一般为app点进去第一屏的数据
    });
    // print(response.data);
    WKSyncConversation conversation = WKSyncConversation();
    conversation.conversations = [];
    if (response.statusCode == HttpStatus.ok) {
      var list = response.data as List<dynamic>;
      for (int i = 0; i < list.length; i++) {
        var json = list[i];
        WKSyncConvMsg convMsg = WKSyncConvMsg();
        convMsg.channelID = json['channel_id'];
        convMsg.channelType = json['channel_type'];
        convMsg.unread = json['unread'];
        convMsg.timestamp = json['timestamp'];
        convMsg.lastMsgSeq = json['last_msg_seq'];
        convMsg.lastClientMsgNO = json['last_client_msg_no'];
        convMsg.version = json['version'];
        var msgListJson = json['recents'] as List<dynamic>;
        List<WKSyncMsg> msgList = [];
        if (msgListJson.isNotEmpty) {
          for (int j = 0; j < msgListJson.length; j++) {
            var msgJson = msgListJson[j];
            msgList.add(getWKSyncMsg(msgJson));
          }
        }

        convMsg.recents = msgList;
        conversation.conversations!.add(convMsg);
      }
    }
    back(conversation);
  }

  static syncChannelMsg(
      String channelID,
      int channelType,
      int startMsgSeq,
      int endMsgSeq,
      int limit,
      int pullMode,
      Function(WKSyncChannelMsg) back) async {
    final dio = Dio();
    print('开始seq: $startMsgSeq 结束seq: $endMsgSeq');
    final response = await dio.post('$apiURL/channel/messagesync', data: {
      "login_uid": UserInfo.uid, // 当前登录用户uid
      "channel_id": channelID, //  频道ID
      "channel_type": channelType, // 频道类型
      "start_message_seq": startMsgSeq, // 开始消息列号（结果包含start_message_seq的消息）
      "end_message_seq": endMsgSeq, // 结束消息列号（结果不包含end_message_seq的消息）
      "limit": limit, // 消息数量限制
      "pull_mode": pullMode // 拉取模式 0:向下拉取 1:向上拉取
    });
    if (response.statusCode == HttpStatus.ok) {
      var data = response.data;
      WKSyncChannelMsg msg = WKSyncChannelMsg();
      msg.startMessageSeq = data['start_message_seq'];
      msg.endMessageSeq = data['end_message_seq'];
      msg.more = data['more'];
      var messages = data['messages'] as List<dynamic>;

      List<WKSyncMsg> msgList = [];
      for (int i = 0; i < messages.length; i++) {
        dynamic json = messages[i];
        msgList.add(getWKSyncMsg(json));
      }
      msg.messages = msgList;
      back(msg);
    }
  }

  static WKSyncMsg getWKSyncMsg(dynamic json) {
    WKSyncMsg msg = WKSyncMsg();
    msg.channelID = json['channel_id'];
    msg.messageID = json['message_id'].toString();
    msg.channelType = json['channel_type'];
    msg.clientMsgNO = json['client_msg_no'];
    msg.messageSeq = json['message_seq'];
    msg.fromUID = json['from_uid'];
    msg.timestamp = json['timestamp'];
    //  msg.payload = json['payload'];
    String payload = json['payload'];
    try {
      msg.payload = jsonDecode(utf8.decode(base64Decode(payload)));
      print('消息seq: ${msg.messageSeq},查询的消息${msg.payload}');
    } catch (e) {
      // print('异常了');
    }
    return msg;
  }
}
