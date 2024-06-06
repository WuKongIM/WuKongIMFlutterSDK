class WKChannelMember {
  String channelID = "";
  //频道类型
  int channelType = 0;
  //成员id
  String memberUID = "";
  //成员名称
  String memberName = "";
  //成员备注
  String memberRemark = "";
  //成员头像
  String memberAvatar = "";
  //成员角色
  int role = 0;
  //成员状态黑名单等1：正常2：黑名单
  int status = 0;
  //是否删除
  int isDeleted = 0;
  //创建时间
  String createdAt = "";
  //修改时间
  String updatedAt = "";
  //版本
  int version = 0;
  // 机器人0否1是
  int robot = 0;
  //扩展字段
  dynamic extraMap;
  // 用户备注
  String remark = "";
  // 邀请者uid
  String memberInviteUID = "";
  // 被禁言到期时间
  int forbiddenExpirationTime = 0;
  String memberAvatarCacheKey = "";
}
