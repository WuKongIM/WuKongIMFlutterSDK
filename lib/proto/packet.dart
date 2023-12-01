import 'package:wukongimfluttersdk/common/crypto_utils.dart';

import 'proto.dart';

class PacketHeader {
  PacketType packetType = PacketType.reserved; // 数据包类型
  bool showUnread = false; // 是否显示未读红点
  bool noPersist = false; // 是否不存储
  bool syncOnce = false; // 是否只同步一次
  int remainingLength = 0;
}

class Packet {
  PacketHeader header = PacketHeader();
}

class ConnectPacket extends Packet {
  int version;
  String clientKey;
  String deviceID;
  int deviceFlag;
  int clientTimestamp;
  String uid;
  String token;
  ConnectPacket(
      {this.version = 0,
      this.clientKey = "",
      this.deviceID = "",
      this.clientTimestamp = 0,
      this.deviceFlag = 0,
      this.uid = "",
      this.token = ""}) {
    header.packetType = PacketType.connect;
  }
  @override
  String toString() {
    return "version:$version，clientKey：$clientKey，deviceID：$deviceID，deviceFlag：$deviceFlag，clientTimestamp:$clientTimestamp，uid：$uid，token：$token";
  }
}

class ConnackPacket extends Packet {
  String serverKey;
  String salt;
  int timeDiff;
  int reasonCode;
  ConnackPacket({
    this.serverKey = "",
    this.salt = "",
    this.timeDiff = 0,
    this.reasonCode = 0,
  });
}

class SendPacket extends Packet {
  Setting setting = Setting();
  int clientSeq;
  String clientMsgNO;
  String streamNo = "";
  String channelID;
  int channelType;
  String? topic;
  String payload = '';
  SendPacket({
    this.clientSeq = 0,
    this.clientMsgNO = "",
    this.channelID = "",
    this.channelType = 1,
    this.topic = "",
  }) {
    header.packetType = PacketType.send;
  }

  String encodeMsgKey() {
    String content = encodeMsgContent();
    StringBuffer sb = StringBuffer();
    sb.write(clientSeq);
    sb.write(clientMsgNO);
    sb.write(channelID);
    sb.write(channelType);
    sb.write(content);
    String msgKey = CryptoUtils.aesEncrypt(sb.toString());
    return CryptoUtils.generateMD5(msgKey);
  }

  String encodeMsgContent() {
    return CryptoUtils.aesEncrypt(payload);
  }
}

class SendAckPacket extends Packet {
  String messageID = "";
  int clientSeq = 0;
  int messageSeq = 0;
  int reasonCode = 0;
  SendAckPacket() {
    header.packetType = PacketType.sendack;
  }
}

class RecvAckPacket extends Packet {
  BigInt messageID = BigInt.from(0);
  int messageSeq;
  RecvAckPacket({
    this.messageSeq = 0,
  }) {
    header.packetType = PacketType.recvack;
  }
}

class RecvPacket extends Packet {
  Setting setting = Setting();
  String msgKey = "";
  String fromUID = "";
  String channelID = "";
  int channelType = 0;
  String clientMsgNO = "";
  String streamNo = "";
  int streamSeq = 0;
  int streamFlag = 0;
  BigInt messageID = BigInt.from(0);
  int messageSeq = 0;
  int messageTime = 0;
  String topic = "";
  String payload = "";
  @override
  String toString() {
    return "msgkey：$msgKey，chanenlID：$channelID，channelType：$channelType，fromUID：$fromUID，clientMsgNO：$clientMsgNO，messageID：$messageID，messageSeq：$messageSeq，messageTime：$messageTime，payload：$payload";
  }
}

class DisconnectPacket extends Packet {
  int reasonCode = 0;
  String reason = "";
  DisconnectPacket() {
    header.packetType = PacketType.disconnect;
  }
}

class PingPacket extends Packet {
  PingPacket() {
    header.packetType = PacketType.ping;
  }
}

class PongPacket extends Packet {
  PongPacket() {
    header.packetType = PacketType.pong;
  }
}
