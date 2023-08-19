class UserInfo {
  static String uid = '';
  static String token = '';
}

class ChatChannel {
  String channelID;
  int channelType;
  ChatChannel(this.channelID, this.channelType);
}

class CommonUtils {
  static String getAvatar(String channelID) {
    if (channelID == '') {
      return '';
    }
    return channelID.substring(0, 1);
  }

  static String formatDateTime(int timestamp) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return "${dateTime.year}-${dateTime.month}-${dateTime.day} ${dateTime.hour}:${dateTime.minute}:${dateTime.second}";
  }
}
