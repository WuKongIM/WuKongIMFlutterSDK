import 'dart:typed_data';

class ReadData {
  final Uint8List _data;
  ByteData? _byteData;
  int offset = 0;

  ReadData(this._data) {
    _byteData = ByteData.view(_data.buffer);
  }

  int readByte() {
    var d = _data[offset];
    offset++;
    return d;
  }

  int readUint8() {
    var v = _byteData!.getUint8(offset);
    offset++;
    return v;
  }

  int readUint16() {
    var v = _byteData!.getUint16(offset);
    offset += 2;
    return v;
  }

  Uint8List readRemaining() {
    var data = _data.sublist(offset);
    offset = _data.length;
    return data;
  }

  String readString() {
    var len = readUint16();
    if (len <= 0) {
      return "";
    }
    var d = _data.sublist(offset, offset + len);
    offset += len;
    return String.fromCharCodes(d);
  }

  int readUint32() {
    var v = _byteData!.getUint32(offset);
    offset += 4;
    return v;
  }

  BigInt readUint64() {
    var data = _data.sublist(offset, offset + 8);
    offset += 8;
    var n = BigInt.from(0);
    for (var i = 0; i < data.length; i++) {
      var d = BigInt.from(2).pow((data.length - i - 1) * 8);
      n = n + BigInt.from(data[i]) * d;
    }
    return n;
  }

  int readVariableLength() {
    var multiplier = 0;
    var rLength = 0;
    while (multiplier < 27) {
      var b = readUint8();
      /* tslint:disable */
      rLength = rLength | ((b & 127) << multiplier);
      if ((b & 128) == 0) {
        break;
      }
      multiplier += 7;
    }
    return rLength;
  }
}

class WriteData {
  List<int> data = [];
  writeUint8(int v) {
    data.add(v & 0xff);
  }

  writeUint16(int v) {
    data.add((v >> 8) & 0xff);
    data.add(v & 0xff);
  }

  writeUint32(int v) {
    data.add((v >> 24) & 0xff);
    data.add((v >> 16) & 0xff);
    data.add((v >> 8) & 0xff);
    data.add((v) & 0xff);
  }

  var d32 = BigInt.from(4294967296);
  writeUint64(BigInt b) {
    var b1 = (b ~/ d32).toInt();
    var b2 = (b % d32).toInt();
    writeUint32(b1);
    writeUint32(b2);
  }

  writeBytes(List<int> bytes) {
    data.addAll(bytes);
  }

  writeString(String v) {
    if (v.isNotEmpty) {
      var wdata = v.codeUnits;
      writeUint16(wdata.length);
      data.addAll(wdata);
    } else {
      writeUint16(0x00);
    }
  }

  toUint8List() {
    return Uint8List.fromList(data);
  }
}
