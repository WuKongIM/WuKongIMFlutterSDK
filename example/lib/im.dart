import 'dart:ffi';

import 'package:example/const.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
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
    var imgs = [
      "https://lmg.jj20.com/up/allimg/tx29/06052048151752929.png",
      "https://pic.imeitou.com/uploads/allimg/2021061715/aqg1wx3nsds.jpg",
      "https://lmg.jj20.com/up/allimg/tx30/10121138219844229.jpg",
      "https://lmg.jj20.com/up/allimg/tx30/10121138219844229.jpg",
      "https://lmg.jj20.com/up/allimg/tx28/430423183653303.jpg",
      "https://lmg.jj20.com/up/allimg/tx23/520420024834916.jpg"
    ];

    WKIM.shared.messageManager.addOnSyncChannelMsgListener((channelID,
        channelType, startMessageSeq, endMessageSeq, limit, pullMode, back) {
      // 同步某个频道的消息
      HttpUtils.syncChannelMsg(channelID, channelType, startMessageSeq,
          endMessageSeq, limit, pullMode, (p0) => back(p0));
    });
    // 获取channel资料
    WKIM.shared.channelManager
        .addOnGetChannelListener((channelId, channelType, back) {
      if (channelType == WKChannelType.personal) {
        // 获取个人资料
        // 这里直接返回了。实际情况可通过API请求后返回
        var channel = WKChannel(channelId, channelType);
        channel.channelName = "单聊${channel.channelID.hashCode}";
        var index = channel.channelID.hashCode % imgs.length;
        channel.avatar = imgs[index];
        back(channel);
      } else if (channelType == WKChannelType.group) {
        // 获取群资料
        var channel = WKChannel(channelId, channelType);
        channel.channelName = "群聊${channel.channelID.hashCode}";
        var index = channel.channelID.hashCode % imgs.length;
        channel.avatar = imgs[index];
        back(channel);
      }
    });
    // 监听同步最近会话
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
