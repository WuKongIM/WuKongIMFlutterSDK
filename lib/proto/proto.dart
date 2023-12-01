import 'dart:typed_data';

import '../common/logs.dart';
import 'packet.dart';
import 'write_read.dart';

enum PacketType {
  reserved, // 保留位
  connect, // 客户端请求连接到服务器(c2s)
  connack,
  send,
  sendack,
  recv,
  recvack,
  ping,
  pong,
  disconnect,
}

class Setting {
  int receipt = 0;
  int topic = 0;
  int stream = 0;
  Setting decode(int v) {
    receipt = (v >> 7 & 0x01);
    topic = (v >> 3 & 0x01);
    stream = (v >> 2 & 0x001);
    return this;
  }

  int encode() {
    return receipt << 7 | topic << 3 | stream << 2;
  }
}

class Proto {
  Map<PacketType, Function> packetEncodeMap = {
    PacketType.connect: encodeConnect,
    PacketType.send: encodeSend,
    PacketType.recvack: encodeRecvAck,
  };
  Map packetDecodeMap = {
    PacketType.connack: decodeConnack,
    PacketType.recv: decodeRecv,
    PacketType.sendack: decodeSendAck,
    PacketType.disconnect: decodeDisconnect
  };

  Uint8List encode(Packet packet) {
    var write = WriteData();
    if (packet.header.packetType != PacketType.ping &&
        packet.header.packetType != PacketType.pong) {
      var packetEncodeFunc = packetEncodeMap[packet.header.packetType];
      var body = packetEncodeFunc!(packet);
      var header = encodeHeader(packet, body.length);
      write.writeBytes(header);
      write.writeBytes(body);
    } else {
      var header = encodeHeader(packet, 0);
      write.writeBytes(header);
    }
    return write.toUint8List();
  }

  Packet decode(Uint8List data) {
    var reader = ReadData(data);
    var header = decodeHeader(reader);
    if (header.packetType == PacketType.ping) {
      return PingPacket();
    }
    if (header.packetType == PacketType.pong) {
      return PongPacket();
    }
    var packetDecodeFunc = packetDecodeMap[header.packetType];
    if (packetDecodeFunc == null) {
      Logs.error("不支持的协议包->${header.packetType}");
    }
    return packetDecodeFunc(header, reader);
  }
}

Uint8List encodeConnect(ConnectPacket packet) {
  WriteData write = WriteData();
  write.writeUint8(packet.version);
  write.writeUint8(packet.deviceFlag);
  write.writeString(packet.deviceID);
  write.writeString(packet.uid);
  write.writeString(packet.token);
  write.writeUint64(BigInt.from(packet.clientTimestamp));
  write.writeString(packet.clientKey);
  return write.toUint8List();
}

decodeConnack(PacketHeader header, ReadData reader) {
  var p = ConnackPacket();
  p.header = header;
  p.timeDiff = reader.readUint64().toInt();
  p.reasonCode = reader.readUint8();
  p.serverKey = reader.readString();
  p.salt = reader.readString();
  return p;
}

PacketHeader decodeHeader(ReadData reader) {
  var b = reader.readUint8();
  var header = PacketHeader();
  header.noPersist = (b & 0x01) > 0;
  header.showUnread = ((b >> 1) & 0x01) > 0;
  header.syncOnce = ((b >> 2) & 0x01) > 0;
  header.packetType = PacketType.values[(b >> 4)];
  if (header.packetType != PacketType.ping &&
      header.packetType != PacketType.pong) {
    header.remainingLength = reader.readVariableLength();
  }
  return header;
}

encodeHeader(Packet packet, int remainingLength) {
  if (packet.header.packetType == PacketType.ping ||
      packet.header.packetType == PacketType.pong) {
    return [(packet.header.packetType.index << 4) | 0];
  }
  List<int> headers = [];

  var typeAndFlags = (encodeBool(false) << 3) |
      (encodeBool(packet.header.syncOnce) << 2) |
      (encodeBool(packet.header.showUnread) << 1) |
      encodeBool(packet.header.noPersist);

  headers.add(packet.header.packetType.index << 4 | 0 | typeAndFlags);
  var vLen = encodeVariableLength(remainingLength);
  headers.addAll(vLen);

  return headers;
}

encodeBool(bool b) {
  return b ? 1 : 0;
}

List<int> encodeVariableLength(int len) {
  List<int> ret = [];
  while (len > 0) {
    var digit = len % 0x80;
    len = (len / 0x80).floor();
    if (len > 0) {
      digit |= 0x80;
    }
    ret.add(digit);
  }
  return ret;
}

Uint8List encodeSend(SendPacket packet) {
  WriteData write = WriteData();
  write.writeUint8(packet.setting.encode());
  write.writeUint32(packet.clientSeq);
  write.writeString(packet.clientMsgNO);
  if (packet.setting.stream == 1) {
    write.writeString(packet.streamNo);
  }
  write.writeString(packet.channelID);
  write.writeUint8(packet.channelType);
  write.writeString(packet.encodeMsgKey());
  if (packet.setting.topic == 1) {
    write.writeString(packet.topic == null ? "" : packet.topic!);
  }
  write.writeBytes(packet.encodeMsgContent().codeUnits);
  return write.toUint8List();
}

Uint8List encodeRecvAck(RecvAckPacket packet) {
  WriteData write = WriteData();
  write.writeUint64(packet.messageID);
  write.writeUint32(packet.messageSeq);
  return write.toUint8List();
}

SendAckPacket decodeSendAck(PacketHeader header, ReadData reader) {
  var sendack = SendAckPacket();
  sendack.messageID = reader.readUint64().toString();
  sendack.clientSeq = reader.readUint32();
  sendack.messageSeq = reader.readUint32();
  sendack.reasonCode = reader.readUint8();
  return sendack;
}

RecvPacket decodeRecv(PacketHeader header, ReadData reader) {
  var recv = RecvPacket();
  recv.header = header;
  int setting = reader.readUint8();
  recv.setting = Setting().decode(setting);
  recv.msgKey = reader.readString();
  recv.fromUID = reader.readString();
  recv.channelID = reader.readString();
  recv.channelType = reader.readUint8().toInt();
  recv.clientMsgNO = reader.readString();
  if (recv.setting.stream == 1) {
    recv.streamNo = reader.readString();
    recv.streamSeq = reader.readUint32().toInt();
    recv.streamFlag = reader.readByte();
  }
  recv.messageID = reader.readUint64();
  recv.messageSeq = reader.readUint32().toInt();
  recv.messageTime = reader.readUint32().toInt();
  if (recv.setting.topic == 1) {
    recv.topic = reader.readString();
  }
  var payload = reader.readRemaining();
  recv.payload = String.fromCharCodes(payload);
  return recv;
}

DisconnectPacket decodeDisconnect(PacketHeader header, ReadData reader) {
  var disconnect = DisconnectPacket();
  disconnect.reasonCode = reader.readUint8();
  disconnect.reason = reader.readString();
  return disconnect;
}
