import 'package:example/const.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_video_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'http.dart';

class IMUtils {
  static Future<bool> initIM() async {
    bool result = await WKIM.shared
        .setup(Options.newDefault(UserInfo.uid, UserInfo.token));
    WKIM.shared.options.getAddr = (Function(String address) complete) async {
      String ip = await HttpUtils.getIP();
      complete(ip);
    };

    WKIM.shared.connectionManager.connect();
    initListener();
    return result;
  }

  static initListener() {
    WKIM.shared.messageManager.addOnSyncChannelMsgListener((channelID,
        channelType, startMessageSeq, endMessageSeq, limit, pullMode, back) {
      print('回掉接口');
      // 同步某个频道的消息
      HttpUtils.syncChannelMsg(channelID, channelType, startMessageSeq,
          endMessageSeq, limit, pullMode, (p0) => back(p0));
    });

    WKIM.shared.conversationManager
        .addOnSyncConversationListener((lastSsgSeqs, msgCount, version, back) {
      HttpUtils.syncConversation(lastSsgSeqs, msgCount, version, back);
    });
    // 监听上传消息附件
    WKIM.shared.messageManager.addOnUploadAttachmentListener((wkMsg, back) {
      if (wkMsg.contentType == WkMessageContentType.image) {
        // todo 上传附件
        WKImageContent imageContent = wkMsg.messageContent! as WKImageContent;
        imageContent.url = 'xxxxxx';
        wkMsg.messageContent = imageContent;
        back(true, wkMsg);
      }
      if (wkMsg.contentType == WkMessageContentType.voice) {
        // todo 上传语音
        WKVoiceContent voiceContent = wkMsg.messageContent! as WKVoiceContent;
        voiceContent.url = 'xxxxxx';
        wkMsg.messageContent = voiceContent;
        back(true, wkMsg);
      } else if (wkMsg.contentType == WkMessageContentType.video) {
        WKVideoContent videoContent = wkMsg.messageContent! as WKVideoContent;
        // todo 上传封面及视频
        videoContent.cover = 'xxxxxx';
        videoContent.url = 'ssssss';
        wkMsg.messageContent = videoContent;
        back(true, wkMsg);
      }
    });
  }
}
