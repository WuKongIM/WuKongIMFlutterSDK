import 'package:wukongimfluttersdk/common/crypto_utils.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/manager/channel_manager.dart';
import 'package:wukongimfluttersdk/manager/channel_member_manager.dart';
import 'package:wukongimfluttersdk/manager/cmd_manager.dart';
import 'package:wukongimfluttersdk/manager/conversation_manager.dart';
import 'package:wukongimfluttersdk/manager/message_manager.dart';
import 'package:wukongimfluttersdk/manager/reminder_manager.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_video_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import 'common/options.dart';
import 'manager/connect_manager.dart';
import 'model/wk_card_content.dart';

class WKIM {
  WKIM._privateConstructor();

  static final WKIM _instance = WKIM._privateConstructor();

  static WKIM get shared => _instance;

  Options options = Options();

  Future<bool> setup(Options opts) async {
    options = opts;
    CryptoUtils.init();
    _initNormalMsgContent();
    bool result = await WKDBHelper.shared.init();
    if (result) {
      messageManager.updateSendingMsgFail();
    }
    return result;
  }

  _initNormalMsgContent() {
    messageManager.registerMsgContent(WkMessageContentType.text,
        (dynamic data) {
      return WKTextContent('').decodeJson(data);
    });
    messageManager.registerMsgContent(WkMessageContentType.card,
        (dynamic data) {
      return WKCardContent('', '').decodeJson(data);
    });
    messageManager.registerMsgContent(WkMessageContentType.image,
        (dynamic data) {
      return WKImageContent(
        0,
        0,
      ).decodeJson(data);
    });
    messageManager.registerMsgContent(WkMessageContentType.voice,
        (dynamic data) {
      return WKVoiceContent(
        0,
      ).decodeJson(data);
    });
    messageManager.registerMsgContent(WkMessageContentType.video,
        (dynamic data) {
      return WKVideoContent().decodeJson(data);
    });
  }

  WKConnectionManager connectionManager = WKConnectionManager();
  WKMessageManager messageManager = WKMessageManager();
  WKConversationManager conversationManager = WKConversationManager();
  WKChannelManager channelManager = WKChannelManager();
  WKChannelMemberManager channelMemberManager = WKChannelMemberManager();
  WKReminderManager reminderManager = WKReminderManager();
  WKCMDManager cmdManager = WKCMDManager();
}
