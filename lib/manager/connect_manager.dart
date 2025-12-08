import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wukongimfluttersdk/db/const.dart';

import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/proto/write_read.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/common/crypto_utils.dart';
import '../common/logs.dart';
import '../entity/conversation.dart';
import '../proto/packet.dart';
import '../proto/proto.dart';
import '../type/const.dart';

class _WKSocket {
  WebSocketChannel? _channel;
  bool _isListening = false;
  bool _isClosed = false;
  static _WKSocket? _instance;
  _WKSocket._internal(this._channel);

  factory _WKSocket.newSocket(WebSocketChannel channel) {
    _instance ??= _WKSocket._internal(channel);
    return _instance!;
  }

  void close() {
    _isListening = false;
    _isClosed = true;
    _instance = null;
    try {
      _channel?.sink.close();
    } catch (e) {
      Logs.debug('关闭WebSocket时发生错误: $e');
    } finally {
      _channel = null;
    }
  }

  bool get isConnected => _channel != null && !_isClosed;

  Future<void> send(Uint8List data) async {
    try {
      if (isConnected) {
        _channel!.sink.add(data);
      } else {
        throw Exception('WebSocket未连接');
      }
    } catch (e) {
      Logs.debug('发送消息错误: $e');
      rethrow;
    }
  }

  void listen(void Function(Uint8List data) onData, void Function() onError) {
    if (!_isListening && isConnected) {
      _channel!.stream.listen(
        (data) {
          if (data is Uint8List) {
            onData(data);
          } else if (data is List<int>) {
            onData(Uint8List.fromList(data));
          } else {
            Logs.debug('收到非二进制数据: $data');
          }
        },
        onError: (err) {
          Logs.debug('WebSocket错误: ${err.toString()}');
          onError();
        },
        onDone: () {
          Logs.debug('WebSocket连接关闭');
          onError();
        },
        cancelOnError: false, // 不因为错误而取消监听
      );
      _isListening = true;
    }
  }
}

class WKConnectionManager {
  WKConnectionManager._privateConstructor();
  static final WKConnectionManager _instance =
      WKConnectionManager._privateConstructor();
  static WKConnectionManager get shared => _instance;

  // 连接状态
  bool isDisconnection = false;
  bool isReconnection = false;
  bool isNetworkUnavailable = false;
  bool _isConnecting = false;

  // 重连配置
  final int reconnMilliseconds = 1500;
  final int maxReconnectAttempts = 10;
  int _reconnectAttempts = 0;

  // 定时器
  Timer? heartTimer;
  Timer? checkNetworkTimer;
  Timer? reconnectTimer;

  final heartIntervalSecond = const Duration(seconds: 60);
  final checkNetworkSecond = const Duration(seconds: 1);

  // 心跳相关
  int unReceivePongCount = 0;
  final int maxUnReceivePongCount = 3;

  // 消息管理
  final LinkedHashMap<int, SendingMsg> _sendingMsgMap = LinkedHashMap();

  // 连接监听器
  HashMap<String, Function(int, int?, ConnectionInfo?)>? _connectionListenerMap;

  // WebSocket实例
  _WKSocket? _socket;

  // 网络状态
  ConnectivityResult? lastConnectivityResult;
  final Connectivity _connectivity = Connectivity();

  // 连接状态获取器
  bool get isConnected => _socket?.isConnected ?? false;
  bool get isConnecting => _isConnecting;

  addOnConnectionStatus(String key, Function(int, int?, ConnectionInfo?) back) {
    _connectionListenerMap ??= HashMap();
    _connectionListenerMap![key] = back;
  }

  removeOnConnectionStatus(String key) {
    if (_connectionListenerMap != null) {
      _connectionListenerMap!.remove(key);
    }
  }

  setConnectionStatus(int status, {int? reasoncode, ConnectionInfo? info}) {
    if (_connectionListenerMap != null) {
      _connectionListenerMap!.forEach((key, back) {
        back(status, reasoncode, info);
      });
    }
  }

  connect() {
    // 检查是否已经在连接中
    if (_isConnecting) {
      Logs.debug('正在连接中，跳过重复连接请求');
      return;
    }

    // 检查是否已经连接
    if (isConnected) {
      Logs.debug('已经连接，无需重复连接');
      return;
    }

    var addr = WKIM.shared.options.addr;
    if ((addr == null || addr == "") && WKIM.shared.options.getAddr == null) {
      Logs.info("没有配置addr！");
      return;
    }
    if (WKIM.shared.options.uid == "" ||
        WKIM.shared.options.uid == null ||
        WKIM.shared.options.token == "" ||
        WKIM.shared.options.token == null) {
      Logs.error("没有初始化uid或token");
      return;
    }
    if (isNetworkUnavailable) {
      Logs.debug('网络不可用，跳过连接');
      return;
    }

    // 重置重连计数
    if (!isReconnection) {
      _reconnectAttempts = 0;
    }

    disconnect(false);
    isDisconnection = false;
    _isConnecting = true;

    if (WKIM.shared.options.getAddr != null) {
      WKIM.shared.options.getAddr!((String addr) {
        _socketConnect(addr);
      });
    } else {
      _socketConnect(addr!);
    }
  }

  disconnect(bool isLogout) {
    isDisconnection = true;
    if (_socket != null) {
      _socket!.close();
    }
    if (isLogout) {
      // _isLogout = true;
      WKIM.shared.options.uid = '';
      WKIM.shared.options.token = '';
      WKIM.shared.messageManager.updateSendingMsgFail();
      WKDBHelper.shared.close();
    }
    _closeAll();
    WKIM.shared.connectionManager.setConnectionStatus(WKConnectStatus.fail);
  }

  _socketConnect(String addr) {
    Logs.info("连接地址--->$addr");
    if (addr == '') {
      _connectFail('连接地址为空');
      return;
    }

    // 将TCP地址转换为WebSocket地址
    String wsAddr = addr;
    if (!addr.startsWith('ws://') && !addr.startsWith('wss://')) {
      var addrs = addr.split(":");
      var host = addrs[0];
      var port = addrs[1];
      wsAddr = 'ws://$host:$port';
    }

    try {
      setConnectionStatus(WKConnectStatus.connecting);

      final channel = WebSocketChannel.connect(
        Uri.parse(wsAddr),
        protocols: ['wukongim'], // 可以添加自定义协议
      );

      _socket = _WKSocket.newSocket(channel);
      _connectSuccess();
    } catch (e) {
      Logs.error('WebSocket连接失败: ${e.toString()}');
      _connectFail(e);
    }
  }

  // socket 连接成功
  _connectSuccess() {
    _isConnecting = false;
    _reconnectAttempts = 0; // 重置重连计数
    isReconnection = false;
    unReceivePongCount = 0; // 重置心跳计数

    Logs.info('WebSocket连接成功');

    // 监听消息
    _socket?.listen((Uint8List data) {
      _cutDatas(data);
    }, () {
      if (isDisconnection) {
        Logs.debug("主动断开连接");
        return;
      }

      Logs.debug("连接断开，准备重连");
      // 延迟重连，避免立即重连
      Future.delayed(Duration(milliseconds: reconnMilliseconds), () {
        if (!isDisconnection) {
          connect();
        }
      });
    });

    // 发送连接包
    _sendConnectPacket();
  }

  _connectFail(error) {
    _isConnecting = false;
    Logs.error('连接失败: $error');

    // 如果不是主动断开，则尝试重连
    if (!isDisconnection && !isNetworkUnavailable) {
      _reconnectAttempts++;

      if (_reconnectAttempts <= maxReconnectAttempts) {
        Logs.info('第 $_reconnectAttempts 次重连尝试，${reconnMilliseconds}ms后重试');
        isReconnection = true;

        // 使用指数退避策略
        int delay = reconnMilliseconds * _reconnectAttempts;
        if (delay > 30000) delay = 30000; // 最大30秒

        reconnectTimer?.cancel();
        reconnectTimer = Timer(Duration(milliseconds: delay), () {
          if (!isDisconnection) {
            connect();
          }
        });
      } else {
        Logs.error('重连次数超过最大限制 ($maxReconnectAttempts)，停止重连');
        setConnectionStatus(WKConnectStatus.fail, reasoncode: -1);
      }
    }
  }

  testCutData(Uint8List data) {
    _cutDatas(data);
  }

  Uint8List? _cacheData;
  _cutDatas(Uint8List data) {
    if (_cacheData == null || _cacheData!.isEmpty) {
      _cacheData = data;
    } else {
      // 上次存在未解析完的消息
      Uint8List temp = Uint8List(_cacheData!.length + data.length);
      for (var i = 0; i < _cacheData!.length; i++) {
        temp[i] = _cacheData![i];
      }
      for (var i = 0; i < data.length; i++) {
        temp[i + _cacheData!.length] = data[i];
      }
      _cacheData = temp;
    }
    Uint8List lastMsgBytes = _cacheData!;
    int readLength = 0;
    while (lastMsgBytes.isNotEmpty && readLength != lastMsgBytes.length) {
      readLength = lastMsgBytes.length;
      ReadData readData = ReadData(lastMsgBytes);
      var b = readData.readUint8();
      var packetType = b >> 4;
      if (PacketType.values[(b >> 4)] == PacketType.pong) {
        Logs.debug('pong');
        unReceivePongCount = 0;
        Uint8List bytes = lastMsgBytes.sublist(1, lastMsgBytes.length);
        _cacheData = lastMsgBytes = bytes;
      } else {
        if (packetType < 10) {
          if (lastMsgBytes.length < 5) {
            _cacheData = lastMsgBytes;
            break;
          }
          int remainingLength = readData.readVariableLength();
          if (remainingLength == -1) {
            //剩余长度被分包
            _cacheData = lastMsgBytes;
            break;
          }
          if (remainingLength > 1 << 21) {
            _cacheData = null;
            break;
          }
          List<int> bytes = encodeVariableLength(remainingLength);

          if (remainingLength + 1 + bytes.length > lastMsgBytes.length) {
            //半包情况
            _cacheData = lastMsgBytes;
          } else {
            Uint8List msg =
                lastMsgBytes.sublist(0, remainingLength + 1 + bytes.length);
            _decodePacket(msg);
            Uint8List temps =
                lastMsgBytes.sublist(msg.length, lastMsgBytes.length);
            _cacheData = lastMsgBytes = temps;
          }
        } else {
          _cacheData = null;
          // 数据包错误，重连
          connect();
          break;
        }
      }
    }
  }

  _decodePacket(Uint8List data) {
    var packet = WKIM.shared.options.proto.decode(data);
    Logs.debug('解码出包->$packet');
    unReceivePongCount = 0;
    if (packet.header.packetType == PacketType.connack) {
      var connackPacket = packet as ConnackPacket;
      if (connackPacket.reasonCode == 1) {
        Logs.debug('连接成功！');
        WKIM.shared.options.protoVersion = connackPacket.serviceProtoVersion;
        CryptoUtils.setServerKeyAndSalt(
            connackPacket.serverKey, connackPacket.salt);
        setConnectionStatus(WKConnectStatus.success,
            reasoncode: connackPacket.reasonCode,
            info: ConnectionInfo(connackPacket.nodeId));
        // Future.delayed(Duration(seconds: 1), () {

        // });
        try {
          WKIM.shared.conversationManager.setSyncConversation(() {
            setConnectionStatus(WKConnectStatus.syncCompleted);
            _resendMsg();
          });
        } catch (e) {
          Logs.error(e.toString());
        }

        _startHeartTimer();
        _startCheckNetworkTimer();
      } else {
        setConnectionStatus(WKConnectStatus.fail,
            reasoncode: connackPacket.reasonCode);
        Logs.debug('连接失败！错误->${connackPacket.reasonCode}');
      }
    } else if (packet.header.packetType == PacketType.recv) {
      Logs.debug('收到消息');
      var recvPacket = packet as RecvPacket;
      _verifyRecvMsg(recvPacket);
      if (!recvPacket.header.noPersist) {
        _sendReceAckPacket(
            recvPacket.messageID, recvPacket.messageSeq, recvPacket.header);
      }
    } else if (packet.header.packetType == PacketType.sendack) {
      var sendack = packet as SendAckPacket;
      Logs.debug('发送结果：${sendack.reasonCode}');
      WKIM.shared.messageManager.updateSendResult(sendack.messageID,
          sendack.clientSeq, sendack.messageSeq, sendack.reasonCode);
      if (_sendingMsgMap.containsKey(sendack.clientSeq)) {
        _sendingMsgMap[sendack.clientSeq]!.isCanResend = false;
      }
    } else if (packet.header.packetType == PacketType.disconnect) {
      disconnect(true);
      // _closeAll();
      setConnectionStatus(WKConnectStatus.kicked);
    } else if (packet.header.packetType == PacketType.pong) {
      Logs.info('pong...');
    }
  }

  _closeAll() {
    Logs.debug('清理所有连接资源');

    // 停止所有定时器
    _stopCheckNetworkTimer();
    _stopHeartTimer();
    _stopReconnectTimer();

    // 关闭WebSocket连接
    if (_socket != null) {
      _socket!.close();
      _socket = null;
    }

    // 重置状态
    _isConnecting = false;
    isReconnection = false;
    unReceivePongCount = 0;
    _reconnectAttempts = 0;
  }

  _stopReconnectTimer() {
    if (reconnectTimer != null) {
      reconnectTimer!.cancel();
      reconnectTimer = null;
    }
  }

  _sendReceAckPacket(BigInt messageID, int messageSeq, PacketHeader header) {
    RecvAckPacket ackPacket = RecvAckPacket();
    ackPacket.header.noPersist = header.noPersist;
    ackPacket.header.syncOnce = header.syncOnce;
    ackPacket.header.showUnread = header.showUnread;
    ackPacket.messageID = messageID;
    ackPacket.messageSeq = messageSeq;
    _sendPacket(ackPacket);
  }

  _sendConnectPacket() async {
    CryptoUtils.init();
    var deviceID = await _getDeviceID();
    var connectPacket = ConnectPacket(
        uid: WKIM.shared.options.uid!,
        token: WKIM.shared.options.token!,
        version: WKIM.shared.options.protoVersion,
        clientKey: base64Encode(CryptoUtils.dhPublicKey!),
        deviceID: deviceID,
        clientTimestamp: DateTime.now().millisecondsSinceEpoch);
    connectPacket.deviceFlag = WKIM.shared.deviceFlagApp;
    _sendPacket(connectPacket);
  }

  _sendPacket(Packet packet) async {
    var data = WKIM.shared.options.proto.encode(packet);
    if (!isReconnection && _socket != null) {
      await _socket!.send(data);
    }
  }

  _startCheckNetworkTimer() {
    _stopCheckNetworkTimer();
    checkNetworkTimer = Timer.periodic(checkNetworkSecond, (timer) {
      var connectivityResult = _connectivity.checkConnectivity();
      connectivityResult.then((value) {
        if (value.contains(ConnectivityResult.none)) {
          isReconnection = true;
          isNetworkUnavailable = true;
          Logs.debug('网络断开了');
          _checkSedingMsg(); // 移除 await，因为 Timer 回调中不能使用 await
          setConnectionStatus(WKConnectStatus.noNetwork);
          lastConnectivityResult = ConnectivityResult.none;
        } else {
          isNetworkUnavailable = false;
          if (lastConnectivityResult != null &&
              !value.contains(lastConnectivityResult)) {
            isReconnection = true;
          }
          if (isReconnection) {
            isReconnection = false;
            connect();
          }
        }
        if (value.isNotEmpty) {
          lastConnectivityResult = value[0];
        }
      });
    });
  }

  _stopCheckNetworkTimer() {
    // if (_connectivitySubscription != null) {
    // _connectivitySubscription?.cancel();
    // }
    if (checkNetworkTimer != null) {
      checkNetworkTimer!.cancel();
      checkNetworkTimer = null;
    }
  }

  _startHeartTimer() {
    _stopHeartTimer();
    heartTimer = Timer.periodic(heartIntervalSecond, (timer) {
      if (!isConnected) {
        Logs.debug('连接已断开，停止心跳');
        return;
      }

      if (unReceivePongCount >= maxUnReceivePongCount) {
        Logs.debug('心跳包未收到pong次数过多($unReceivePongCount)，重连中...');
        isReconnection = false;
        connect();
        return;
      }

      Logs.info('发送ping...');
      unReceivePongCount++;
      _sendPacket(PingPacket());
    });
  }

  _stopHeartTimer() {
    if (heartTimer != null) {
      heartTimer!.cancel();
      heartTimer = null;
    }
  }

  sendMessage(WKMsg wkMsg) {
    SendPacket packet = SendPacket();
    packet.setting = wkMsg.setting;
    packet.header.noPersist = wkMsg.header.noPersist;
    packet.header.showUnread = wkMsg.header.redDot;
    packet.header.syncOnce = wkMsg.header.syncOnce;
    packet.channelID = wkMsg.channelID;
    packet.channelType = wkMsg.channelType;
    packet.clientSeq = wkMsg.clientSeq;
    packet.clientMsgNO = wkMsg.clientMsgNO;
    packet.topic = wkMsg.topicID;
    packet.expire = wkMsg.expireTime;
    packet.payload = wkMsg.content;
    _addSendingMsg(packet);
    _sendPacket(packet);
  }

  _verifyRecvMsg(RecvPacket recvMsg) {
    StringBuffer sb = StringBuffer();
    sb.writeAll([
      recvMsg.messageID,
      recvMsg.messageSeq,
      recvMsg.clientMsgNO,
      recvMsg.messageTime,
      recvMsg.fromUID,
      recvMsg.channelID,
      recvMsg.channelType,
      recvMsg.payload
    ]);
    var encryptContent = sb.toString();
    var result = CryptoUtils.aesEncrypt(encryptContent);
    String localMsgKey = CryptoUtils.generateMD5(result);
    if (recvMsg.msgKey != localMsgKey) {
      Logs.error('非法消息-->期望msgKey：$localMsgKey，实际msgKey：${recvMsg.msgKey}');
      return;
    } else {
      recvMsg.payload = CryptoUtils.aesDecrypt(recvMsg.payload);
      Logs.debug(recvMsg.toString());
      _saveRecvMsg(recvMsg);
    }
  }

  _saveRecvMsg(RecvPacket recvMsg) async {
    WKMsg msg = WKMsg();
    msg.header.redDot = recvMsg.header.showUnread;
    msg.header.noPersist = recvMsg.header.noPersist;
    msg.header.syncOnce = recvMsg.header.syncOnce;
    msg.setting = recvMsg.setting;
    msg.channelType = recvMsg.channelType;
    msg.channelID = recvMsg.channelID;
    msg.content = recvMsg.payload;
    msg.messageID = recvMsg.messageID.toString();
    msg.messageSeq = recvMsg.messageSeq;
    msg.timestamp = recvMsg.messageTime;
    msg.fromUID = recvMsg.fromUID;
    msg.clientMsgNO = recvMsg.clientMsgNO;
    msg.expireTime = recvMsg.expire;
    if (msg.expireTime > 0) {
      msg.expireTimestamp = msg.expireTime + msg.timestamp;
    }
    msg.status = WKSendMsgResult.sendSuccess;
    msg.topicID = recvMsg.topic;
    msg.orderSeq = await WKIM.shared.messageManager
        .getMessageOrderSeq(msg.messageSeq, msg.channelID, msg.channelType);
    dynamic contentJson = jsonDecode(msg.content);
    msg.contentType = WKDBConst.readInt(contentJson, 'type');
    msg.isDeleted = _isDeletedMsg(contentJson);
    msg.messageContent = WKIM.shared.messageManager
        .getMessageModel(msg.contentType, contentJson);
    WKChannel? fromChannel = await WKIM.shared.channelManager
        .getChannel(msg.fromUID, WKChannelType.personal);
    if (fromChannel != null) {
      msg.setFrom(fromChannel);
    }
    if (msg.channelType == WKChannelType.group) {
      WKChannelMember? memberChannel = await WKIM.shared.channelMemberManager
          .getMember(msg.channelID, WKChannelType.group, msg.fromUID);
      if (memberChannel != null) {
        msg.setMemberOfFrom(memberChannel);
      }
    }
    WKIM.shared.messageManager.parsingMsg(msg);
    if (msg.isDeleted == 0 &&
        !msg.header.noPersist &&
        msg.contentType != WkMessageContentType.insideMsg) {
      int row = await WKIM.shared.messageManager.saveMsg(msg);
      msg.clientSeq = row;
      WKUIConversationMsg? uiMsg = await WKIM.shared.conversationManager
          .saveWithLiMMsg(msg, msg.header.redDot ? 1 : 0);
      if (uiMsg != null) {
        List<WKUIConversationMsg> list = [];
        list.add(uiMsg);
        WKIM.shared.conversationManager.setRefreshUIMsgs(list);
      }
    } else {
      Logs.debug(
          '消息不能存库:is_deleted=${msg.isDeleted},no_persist=${msg.header.noPersist},content_type:${msg.contentType}');
    }
    if (msg.contentType != WkMessageContentType.insideMsg) {
      List<WKMsg> list = [];
      list.add(msg);
      WKIM.shared.messageManager.pushNewMsg(list);
    }
  }

  int _isDeletedMsg(dynamic jsonObject) {
    int isDelete = 0;
    if (jsonObject != null) {
      var visibles = jsonObject['visibles'];
      if (visibles != null && visibles is List) {
        bool isIncludeLoginUser = false;
        for (int i = 0, size = visibles.length; i < size; i++) {
          if (visibles[i] == WKIM.shared.options.uid) {
            isIncludeLoginUser = true;
            break;
          }
        }
        isDelete = isIncludeLoginUser ? 0 : 1;
      }
    }
    return isDelete;
  }

  _resendMsg() async {
    _removeSendingMsg();
    if (_sendingMsgMap.isNotEmpty) {
      for (var entry in _sendingMsgMap.entries) {
        if (entry.value.isCanResend) {
          Logs.debug("重发消息：${entry.value.sendPacket.clientSeq}");
          await _sendPacket(entry.value.sendPacket);
        }
      }
    }
  }

  _addSendingMsg(SendPacket sendPacket) {
    _removeSendingMsg();
    _sendingMsgMap[sendPacket.clientSeq] = SendingMsg(sendPacket);
  }

  _removeSendingMsg() {
    if (_sendingMsgMap.isNotEmpty) {
      List<int> ids = [];
      _sendingMsgMap.forEach((key, sendingMsg) {
        if (!sendingMsg.isCanResend) {
          ids.add(key);
        }
      });
      if (ids.isNotEmpty) {
        for (var i = 0; i < ids.length; i++) {
          _sendingMsgMap.remove(ids[i]);
        }
      }
    }
  }

  _checkSedingMsg() {
    if (_sendingMsgMap.isNotEmpty) {
      final it = _sendingMsgMap.entries.iterator;
      while (it.moveNext()) {
        var key = it.current.key;
        var wkSendingMsg = it.current.value;
        if (wkSendingMsg.sendCount == 5 && wkSendingMsg.isCanResend) {
          WKIM.shared.messageManager.updateMsgStatusFail(key);
          wkSendingMsg.isCanResend = false;
        } else {
          var nowTime =
              (DateTime.now().millisecondsSinceEpoch / 1000).truncate();
          if (nowTime - wkSendingMsg.sendTime > 10) {
            wkSendingMsg.sendTime =
                (DateTime.now().millisecondsSinceEpoch / 1000).truncate();
            wkSendingMsg.sendCount++;
            _sendingMsgMap[key] = wkSendingMsg;
            // 使用 Future.microtask 来处理异步发送
            Future.microtask(() async {
              await _sendPacket(wkSendingMsg.sendPacket);
            });
            Logs.debug("消息发送失败，尝试重发中...");
          }
        }
      }

      _removeSendingMsg();
    }
  }
}

Future<String> _getDeviceID() async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  String wkUid = WKIM.shared.options.uid!;
  String key = "${wkUid}_device_id";
  var deviceID = preferences.getString(key);
  if (deviceID == null || deviceID == "") {
    deviceID = const Uuid().v4().toString().replaceAll("-", "");
    preferences.setString(key, deviceID);
  }
  return "${deviceID}F";
}

class SendingMsg {
  SendPacket sendPacket;
  int sendCount = 0;
  int sendTime = 0;
  bool isCanResend = true;
  SendingMsg(this.sendPacket) {
    sendTime = (DateTime.now().millisecondsSinceEpoch / 1000).truncate();
  }
}

class ConnectionInfo {
  int nodeId;
  ConnectionInfo(this.nodeId);
}
