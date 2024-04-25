class WKReminder {
  int reminderID = 0;
  String messageID = '';
  String channelID = '';
  int channelType = 0;
  int messageSeq = 0;
  int type = 0;
  int isLocate = 0;
  String uid = '';
  String text = '';
  dynamic data;
  int version = 0;
  int done = 0;
  int needUpload = 0;
  String publisher = '';
}

class WKMentionType {
  //有人@我
  static const int wkReminderTypeMentionMe = 1;
  //申请加群
  static const int wkApplyJoinGroupApprove = 2;
}
