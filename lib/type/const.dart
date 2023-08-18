class WkMessageContentType {
  static const unknown = -1;
  static const text = 1;
  static const image = 2;
  static const gif = 3;
  static const voice = 4;
  static const video = 5;
  static const location = 6;
  static const card = 7;
  static const file = 8;
  static const contentFormatError = 97;
  static const insideMsg = 99;
}

class WKChannelType {
  static const personal = 1;
  static const group = 2;
  static const customerService = 3;
  static const community = 4;
  static const communityTopic = 5;
}

class WKSendMsgResult {
  //不在白名单内
  static const int notOnWhiteList = 13;
  //黑名单
  static const int blackList = 4;
  //不是好友或不在群内
  static const int noRelation = 3;
  //发送失败
  static const int sendFail = 2;
  //成功
  static const int sendSuccess = 1;
  //发送中
  static const int sendLoading = 0;
}

class WKConnectStatus {
  //失败
  static const int fail = 0;
  //登录或者发送消息回执返回状态成功
  static const int success = 1;
  //被踢（其他设备登录）
  static const int kicked = 2;
  //同步消息中
  static const int syncMsg = 3;
  //连接中
  static const int connecting = 4;
  //无网络
  static const int noNetwork = 5;
}
