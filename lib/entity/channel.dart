import '../type/const.dart';

class WKChannel {
  String channelID = "";
  int channelType = WKChannelType.personal;
  String channelName = "";
  //频道备注(频道的备注名称，个人的话就是个人备注，群的话就是群别名)
  String channelRemark = "";
  int showNick = 0;
  //是否置顶
  int top = 0;
  //是否保存在通讯录
  int save = 0;
  //免打扰
  int mute = 0;
  //禁言
  int forbidden = 0;
  //邀请确认
  int invite = 0;
  //频道状态[1：正常2：黑名单]
  int status = 1;
  //是否已关注 0.未关注（陌生人） 1.已关注（好友）
  int follow = 0;
  //是否删除
  int isDeleted = 0;
  //创建时间
  String createdAt = "";
  //修改时间
  String updatedAt = "";
  //频道头像
  String avatar = "";
  //版本
  int version = 0;
  //扩展字段
  dynamic localExtra;
  //是否在线
  int online = 0;
  //最后一次离线时间
  int lastOffline = 0;
  // 最后一次离线设备标识
  int deviceFlag = 0;
  //是否回执消息
  int receipt = 0;
  // 机器人
  int robot = 0;
  //分类[service:客服]
  String category = "";
  String username = "";
  String avatarCacheKey = "";
  dynamic remoteExtraMap;
  String parentChannelID = "";
  int parentChannelType = 0;
  WKChannel(this.channelID, this.channelType);
}
