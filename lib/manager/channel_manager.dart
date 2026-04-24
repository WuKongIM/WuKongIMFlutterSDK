import 'dart:collection';

import '../db/channel.dart';
import '../entity/channel.dart';

class WKChannelManager {
  WKChannelManager._privateConstructor() {
    _refreshChannelMap = HashMap<String, Function(WKChannel)>();
    _refreshChannelAvatarMap = HashMap<String, Function(WKChannel)>();
  }
  static final WKChannelManager _instance =
      WKChannelManager._privateConstructor();
  static WKChannelManager get shared => _instance;

  final Map<String, WKChannel> _list = {};
  late final HashMap<String, Function(WKChannel)> _refreshChannelMap;
  late final HashMap<String, Function(WKChannel)> _refreshChannelAvatarMap;
  Function(String channelID, int channelType, Function(WKChannel) back)?
      _getChannelInfoBack;

  fetchChannelInfo(String channelID, int channelType) {
    if (_getChannelInfoBack != null) {
      _getChannelInfoBack!(channelID, channelType, (wkChannel) {
        addOrUpdateChannel(wkChannel);
      });
    }
  }

  Future<List<WKChannel>> getWithFollowAndStatus(
      int channelType, int follow, int status) async {
    return ChannelDB.shared
        .queryWithFollowAndStatus(channelType, follow, status);
  }

  Future<WKChannel?> getChannel(String channelID, int channelType) async {
    String key = _getKey(channelID, channelType);
    WKChannel? channel = _list[key];
    if (channel == null || channel.channelID == '') {
      channel = await ChannelDB.shared.query(channelID, channelType);
      if (channel != null) {
        _list[key] = channel;
      }
    }
    return channel;
  }

  addOrUpdateChannels(List<WKChannel> list) {
    if (list.isEmpty) {
      return;
    }
    for (WKChannel liMChannel in list) {
      _updateChannel(liMChannel);
    }
    ChannelDB.shared.insertOrUpdateList(list);
  }

  // 全局搜索
  Future<List<WKChannelSearchResult>> search(String keyword) {
    return ChannelDB.shared.search(keyword);
  }

  // 搜索已关注channel(好友)
  Future<List<WKChannel>> searchWithChannelTypeAndFollow(
      String searchKey, int channelType, int follow) {
    return ChannelDB.shared
        .searchWithChannelTypeAndFollow(searchKey, channelType, follow);
  }

  // 修改头像
  updateAvatarCacheKey(
      String channelID, int channelType, String avatarCacheKey) async {
    WKChannel? channel = await getChannel(channelID, channelType);
    if (channel == null) {
      return;
    }
    channel.avatarCacheKey = avatarCacheKey;
    _updateChannel(channel);
    ChannelDB.shared.saveOrUpdate(channel);
    _refreshChannelAvatarMap.forEach((key, back) {
      back(channel);
    });
  }

  addOrUpdateChannel(WKChannel channel) {
    _updateChannel(channel);
    _setRefresh(channel);
    ChannelDB.shared.saveOrUpdate(channel);
  }

  _updateChannel(WKChannel channel) {
    String key = _getKey(channel.channelID, channel.channelType);
    WKChannel? exist = _list[key];
    if (exist != null) {
      exist.forbidden = channel.forbidden;
      exist.channelName = channel.channelName;
      exist.avatar = channel.avatar;
      exist.category = channel.category;
      exist.lastOffline = channel.lastOffline;
      exist.online = channel.online;
      exist.follow = channel.follow;
      exist.top = channel.top;
      exist.channelRemark = channel.channelRemark;
      exist.status = channel.status;
      exist.version = channel.version;
      exist.invite = channel.invite;
      exist.localExtra = channel.localExtra;
      exist.mute = channel.mute;
      exist.save = channel.save;
      exist.showNick = channel.showNick;
      exist.isDeleted = channel.isDeleted;
      exist.receipt = channel.receipt;
      exist.robot = channel.robot;
      exist.deviceFlag = channel.deviceFlag;
      exist.parentChannelID = channel.parentChannelID;
      exist.parentChannelType = channel.parentChannelType;
      exist.avatarCacheKey = channel.avatarCacheKey;
      exist.remoteExtraMap = channel.remoteExtraMap;
    } else {
      _list[key] = channel;
    }
  }

  _setRefresh(WKChannel liMChannel) {
    _refreshChannelMap.forEach((key, back) {
      back(liMChannel);
    });
  }

  String _getKey(String channelID, int channelType) {
    return '$channelID:$channelType';
  }

  addOnRefreshListener(String key, Function(WKChannel) back) {
    _refreshChannelMap[key] = back;
  }

  removeOnRefreshListener(String key) {
    _refreshChannelMap.remove(key);
  }

  addOnGetChannelListener(Function(String, int, Function(WKChannel)) back) {
    _getChannelInfoBack = back;
  }

  addOnRefreshAvatarListener(String key, Function(WKChannel) back) {
    _refreshChannelAvatarMap[key] = back;
  }

  removeOnRefreshAvatarListener(String key) {
    _refreshChannelAvatarMap.remove(key);
  }
}
