import 'package:wukongimfluttersdk/model/wk_media_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

class WKVideoContent extends WKMediaMessageContent {
  String cover = '';
  String coverLocalPath = '';
  int second = 0;
  int size = 0;
  int width = 0;
  int height = 0;
  WKVideoContent() {
    contentType = WkMessageContentType.video;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return {
      'cover': cover,
      'coverLocalPath': coverLocalPath,
      'localPath': localPath,
      'size': size,
      'width': width,
      'height': height,
      'second': second,
      'url': url
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    cover = readString(json, 'cover');
    coverLocalPath = readString(json, 'coverLocalPath');
    localPath = readString(json, 'localPath');
    size = readInt(json, 'size');
    width = readInt(json, 'width');
    height = readInt(json, 'height');
    second = readInt(json, 'second');
    url = readString(json, 'url');
    return this;
  }

  @override
  String displayText() {
    return '[视频]';
  }

  @override
  String searchableWord() {
    return '[视频]';
  }
}
