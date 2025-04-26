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

  final List<WKChannel> _list = [];
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
    WKChannel? channel;
    if (_list.isNotEmpty) {
      for (int i = 0; i < _list.length; i++) {
        if (_list[i].channelID == channelID &&
            _list[i].channelType == channelType) {
          channel = _list[i];
          break;
        }
      }
    }
    if (channel == null || channel.channelID == '') {
      channel = await ChannelDB.shared.query(channelID, channelType);
      if (channel != null) {
        _list.add(channel);
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
    bool isAdd = true;
    for (int i = 0, size = _list.length; i < size; i++) {
      if (_list[i].channelID == channel.channelID &&
          _list[i].channelType == channel.channelType) {
        isAdd = false;
        _list[i].forbidden = channel.forbidden;
        _list[i].channelName = channel.channelName;
        _list[i].avatar = channel.avatar;
        _list[i].category = channel.category;
        _list[i].lastOffline = channel.lastOffline;
        _list[i].online = channel.online;
        _list[i].follow = channel.follow;
        _list[i].top = channel.top;
        _list[i].channelRemark = channel.channelRemark;
        _list[i].status = channel.status;
        _list[i].version = channel.version;
        _list[i].invite = channel.invite;
        _list[i].localExtra = channel.localExtra;
        _list[i].mute = channel.mute;
        _list[i].save = channel.save;
        _list[i].showNick = channel.showNick;
        _list[i].isDeleted = channel.isDeleted;
        _list[i].receipt = channel.receipt;
        _list[i].robot = channel.robot;
        _list[i].deviceFlag = channel.deviceFlag;
        _list[i].parentChannelID = channel.parentChannelID;
        _list[i].parentChannelType = channel.parentChannelType;
        _list[i].avatarCacheKey = channel.avatarCacheKey;
        _list[i].remoteExtraMap = channel.remoteExtraMap;
        break;
      }
    }
    if (isAdd) {
      _list.add(channel);
    }
  }

  _setRefresh(WKChannel liMChannel) {
    _refreshChannelMap.forEach((key, back) {
      back(liMChannel);
    });
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
