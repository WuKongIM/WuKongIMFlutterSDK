import 'package:wukongimfluttersdk/model/wk_media_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

class WKImageContent extends WKMediaMessageContent {
  int width;
  int height;
  WKImageContent(this.width, this.height) {
    contentType = WkMessageContentType.image;
  }
  @override
  Map<String, dynamic> encodeJson() {
    return {
      'width': width,
      'height': height,
      'url': url,
      'localPath': localPath
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    width = readInt(json, 'width');
    height = readInt(json, 'height');
    url = readString(json, 'url');
    localPath = readString(json, 'localPath');
    return this;
  }

  @override
  String displayText() {
    return '[图片]';
  }

  @override
  String searchableWord() {
    return '[图片]';
  }
}
