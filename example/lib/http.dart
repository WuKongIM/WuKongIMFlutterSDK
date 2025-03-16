import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:example/const.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

class HttpUtils {
  // static String apiURL = "https://api.githubim.com";
  static String apiURL = "http://62.234.8.38:7090/v1";
  // static String apiURL = "http://175.27.245.108:15001";
  static getAvatarUrl(String uid) {
    return "$apiURL/users/$uid/avatar";
  }

  static getGroupAvatarUrl(String gid) {
    return "$apiURL/groups/$gid/avatar";
  }

  static Future<int> login(String uid, String token) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    final response = await dio.post("$apiURL/user/login", data: {
      'uid': uid,
      'token': token,
      'device_flag': 0,
      'device_level': 1
    });
    try {
      if (response.statusCode == HttpStatus.ok) {
        UserInfo.name = response.data['name'];
      }
    } catch (e) {
      print('获取用户信息失败');
    }

    return response.statusCode!;
  }

  static Future<String> getIP(String uid) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    String ip = '';
    try {
      final response = await dio.get('$apiURL/users/$uid/route');
      if (response.statusCode == HttpStatus.ok) {
        ip = response.data['tcp_addr'];
      }
    } catch (e) {
      ip = '';
    }

    return ip;
  }

  static syncConversation(String lastSsgSeqs, int msgCount, int version,
      Function(WKSyncConversation) back) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };

    final response = await dio.post('$apiURL/conversation/sync', data: {
      "login_uid": UserInfo.uid, // 当前登录用户uid
      "version": version, //  当前客户端的会话最大版本号(从保存的结果里取最大的version，如果本地没有数据则传0)，
      "last_msg_seqs":
          lastSsgSeqs, //   客户端所有频道会话的最后一条消息序列号拼接出来的同步串 格式： channelID:channelType:last_msg_seq|channelID:channelType:last_msg_seq  （此字段非必填，如果不填就获取全量数据，填写了获取增量数据，看你自己的需求。）
      "msg_count": 10, // 每个会话获取最大的消息数量，一般为app点进去第一屏的数据
      "device_uuid": UserInfo.uid,
    });
    // print(response.data);
    WKSyncConversation conversation = WKSyncConversation();
    conversation.conversations = [];

    if (response.statusCode == HttpStatus.ok) {
      try {
        var list = response.data['conversations'];
        // var list = jsonDecode(response.data);
        for (int i = 0; i < list.length; i++) {
          var json = list[i];
          WKSyncConvMsg convMsg = WKSyncConvMsg();
          convMsg.channelID = json['channel_id'];
          convMsg.channelType = json['channel_type'];
          convMsg.unread = json['unread'] ?? 0;
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
      } catch (e) {
        print('同步最近会话错误');
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
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    final response = await dio.post('$apiURL/message/channel/sync', data: {
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
      var messages = data['messages'];

      List<WKSyncMsg> msgList = [];
      for (int i = 0; i < messages.length; i++) {
        dynamic json = messages[i];
        msgList.add(getWKSyncMsg(json));
      }
      print('同步channel消息数量：${msgList.length}');
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
    msg.isDeleted = json['is_deleted'];
    msg.timestamp = json['timestamp'];
    //  msg.payload = json['payload'];

    // String payload = json['payload'];
    try {
      msg.payload = json['payload'];
      // msg.payload = jsonDecode(utf8.decode(base64Decode(payload)));
    } catch (e) {
      // print('异常了');
    }
    // 解析扩展
    var extraJson = json['message_extra'];
    if (extraJson != null) {
      var extra = getMsgExtra(extraJson);
      msg.messageExtra = extra;
    }
    return msg;
  }

  static WKSyncExtraMsg getMsgExtra(dynamic extraJson) {
    var extra = WKSyncExtraMsg();
    extra.messageID = extraJson['message_id'];
    extra.messageIdStr = extraJson['message_id_str'];
    extra.revoke = extraJson['revoke'] ?? 0;
    extra.revoker = extraJson['revoker'] ?? '';
    extra.readed = extraJson['readed'] ?? 0;
    extra.readedCount = extraJson['readed_count'] ?? 0;
    extra.isMutualDeleted = extraJson['is_mutual_deleted'] ?? 0;
    return extra;
  }

  static getGroupInfo(String groupId) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    final response = await dio.get('$apiURL/groups/$groupId');
    if (response.statusCode == HttpStatus.ok) {
      var json = response.data;
      var channel = WKChannel(groupId, WKChannelType.group);
      channel.channelName = json['name'];
      channel.avatar = json['avatar'];
      WKIM.shared.channelManager.addOrUpdateChannel(channel);
    } else {
      print('获取群信息失败');
    }
  }

  static getUserInfo(String uid) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    try {
      final response = await dio.get('$apiURL/users/$uid');
      if (response.statusCode == HttpStatus.ok) {
        var json = response.data;
        var channel = WKChannel(uid, WKChannelType.personal);
        channel.channelName = json['name'];
        channel.avatar = json['avatar'];
        WKIM.shared.channelManager.addOrUpdateChannel(channel);
      }
    } catch (e) {
      print('获取用户信息失败$e');
    }
  }

  static revokeMsg(String clientMsgNo, String channelId, int channelType,
      int msgSeq, String msgId) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    try {
      final response = await dio.post('$apiURL/message/revoke', data: {
        'login_uid': UserInfo.uid,
        'channel_id': channelId,
        'channel_type': channelType,
        'client_msg_no': clientMsgNo,
        'message_seq': msgSeq,
        'message_id': msgId,
      });
      if (response.statusCode == HttpStatus.ok) {
        print('撤回消息成功');
      }
    } catch (e) {
      print('获取用户信息失败$e');
    }
  }

  static deleteMsg(String clientMsgNo, String channelId, int channelType,
      int msgSeq, String msgId) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    try {
      final response = await dio.post('$apiURL/message/delete', data: {
        'login_uid': UserInfo.uid,
        'channel_id': channelId,
        'channel_type': channelType,
        'message_seq': msgSeq,
        'message_id': msgId,
      });
      if (response.statusCode == HttpStatus.ok) {
        WKIM.shared.messageManager.deleteWithClientMsgNo(clientMsgNo);
      }
    } catch (e) {
      print('删除消息失败$e');
    }
  }

  static syncMsgExtra(String channelId, int channelType, int version) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    try {
      final response = await dio.post('$apiURL/message/extra/sync', data: {
        'login_uid': UserInfo.uid,
        'channel_id': channelId,
        'channel_type': channelType,
        'source': UserInfo.uid,
        'limit': 100,
        'extra_version': version,
      });
      if (response.statusCode == HttpStatus.ok) {
        var arrJson = response.data;
        if (arrJson != null && arrJson.length > 0) {
          List<WKMsgExtra> list = [];
          for (int i = 0; i < arrJson.length; i++) {
            var extraJson = arrJson[i];
            WKMsgExtra extra = WKMsgExtra();
            extra.messageID = extraJson['message_id_str'];
            extra.revoke = extraJson['revoke'] ?? 0;
            extra.revoker = extraJson['revoker'] ?? '';
            extra.readed = extraJson['readed'] ?? 0;
            extra.readedCount = extraJson['readed_count'] ?? 0;
            extra.isMutualDeleted = extraJson['is_mutual_deleted'] ?? 0;
            extra.extraVersion = extraJson['extra_version'] ?? 0;
            list.add(extra);
          }
          WKIM.shared.messageManager.saveRemoteExtraMsg(list);
        }
      }
    } catch (e) {
      print('同步消息扩展失败$e');
    }
  }

  // 清空红点
  static clearUnread(String channelId, int channelType) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    try {
      final response = await dio.put('$apiURL/conversation/clearUnread', data: {
        'login_uid': UserInfo.uid,
        'channel_id': channelId,
        'channel_type': channelType,
        'unread': 0,
      });
      if (response.statusCode == HttpStatus.ok) {
        print('清空红点成功');
      }
    } catch (e) {
      print('清空红点失败$e');
    }
  }

  // 清除频道消息
  static clearChannelMsg(String channelId, int channelType) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    try {
      int maxSeq = await WKIM.shared.messageManager
          .getMaxMessageSeq(channelId, channelType);
      final response = await dio.post('$apiURL/message/offset', data: {
        'login_uid': UserInfo.uid,
        'channel_id': channelId,
        'channel_type': channelType,
        'message_seq': maxSeq
      });
      if (response.statusCode == HttpStatus.ok) {
        WKIM.shared.messageManager.clearWithChannel(channelId, channelType);
      }
    } catch (e) {
      print('清除频道消息失败$e');
    }
  }

  // 创建群
  static Future<bool> createGroup(String groupNo) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    try {
      final response = await dio.post('$apiURL/group/create', data: {
        'login_uid': UserInfo.uid,
        'group_no': groupNo,
      });
      if (response.statusCode == HttpStatus.ok) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('创建群失败$e');
      return false;
    }
  }

  // 修改群名称
  static Future<bool> updateGroupName(String groupNo, String groupName) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // 信任所有证书
      return true;
    };
    final dio = Dio();
    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        return httpClient;
      };
    try {
      final response = await dio.put('$apiURL/groups/$groupNo', data: {
        'login_uid': UserInfo.uid,
        'name': groupName,
      });
      if (response.statusCode == HttpStatus.ok) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('修改群名称失败$e');
      return false;
    }
  }
}
