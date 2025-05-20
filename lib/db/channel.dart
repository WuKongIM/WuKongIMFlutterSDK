import 'dart:async';
import 'dart:collection';

import 'package:sqflite/sqflite.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';

import 'wk_db_helper.dart';

class ChannelDB {
  ChannelDB._privateConstructor();
  static final ChannelDB _instance = ChannelDB._privateConstructor();
  static ChannelDB get shared => _instance;

  Future<WKChannel?> query(String channelID, int channelType) async {
    WKChannel? channel;
    if (WKDBHelper.shared.getDB() == null) {
      return channel;
    }
    List<Map<String, Object?>> list = await WKDBHelper.shared.getDB()!.query(
        WKDBConst.tableChannel,
        where: "channel_id=? and channel_type=?",
        whereArgs: [channelID, channelType]);
    if (list.isNotEmpty) {
      channel = WKDBConst.serializeChannel(list[0]);
    }
    return channel;
  }

  insertOrUpdateList(List<WKChannel> list) async {
    if (WKDBHelper.shared.getDB() == null) {
      return;
    }
    List<Map<String, dynamic>> addList = [];
    for (WKChannel channel in list) {
      if (channel.channelID != '') {
        addList.add(getMap(channel));
      }
    }
    if (addList.isNotEmpty) {
      WKDBHelper.shared.getDB()!.transaction((txn) async {
        if (addList.isNotEmpty) {
          for (Map<String, dynamic> value in addList) {
            txn.insert(WKDBConst.tableChannel, value,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });
    }
  }

  saveOrUpdate(WKChannel channel) async {
    insert(channel);
  }

  insert(WKChannel channel) {
    WKDBHelper.shared.getDB()?.insert(WKDBConst.tableChannel, getMap(channel),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  update(WKChannel channel) {
    WKDBHelper.shared.getDB()?.update(WKDBConst.tableChannel, getMap(channel),
        where: "channel_id=? and channel_type=?",
        whereArgs: [channel.channelID, channel.channelType]);
  }

  Future<bool> isExist(String channelID, int channelType) async {
    bool isExit = false;
    if (WKDBHelper.shared.getDB() == null) {
      return isExit;
    }
    List<Map<String, Object?>> list = await WKDBHelper.shared.getDB()!.query(
        WKDBConst.tableChannel,
        where: "channel_id=? and channel_type=?",
        whereArgs: [channelID, channelType]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      if (data != null) {
        String channelID = WKDBConst.readString(data, 'channel_id');
        if (channelID != '') {
          isExit = true;
        }
      }
    }
    return isExit;
  }

  Future<List<WKChannel>> queryWithChannelIdsAndChannelType(
      List<String> channelIDs, int channelType) async {
    if (channelIDs.isEmpty) {
      return [];
    }
    List<Object> args = [];
    args.addAll(channelIDs);
    args.add(channelType);
    List<WKChannel> list = [];
    if (WKDBHelper.shared.getDB() == null) {
      return list;
    }
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB()!.query(
        WKDBConst.tableChannel,
        where:
            "channel_id in (${WKDBConst.getPlaceholders(channelIDs.length)}) and channel_type=?",
        whereArgs: args);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeChannel(data));
      }
    }
    return list;
  }

  Future<List<WKChannelSearchResult>> search(String keyword) async {
    List<WKChannelSearchResult> list = [];
    var sql =
        "select t.*,cm.member_name,cm.member_remark from (select ${WKDBConst.tableChannel}.*,max(${WKDBConst.tableChannelMember}.id) mid from ${WKDBConst.tableChannel}, ${WKDBConst.tableChannelMember} where ${WKDBConst.tableChannel}.channel_id=${WKDBConst.tableChannelMember}.channel_id and ${WKDBConst.tableChannel}.channel_type=${WKDBConst.tableChannelMember}.channel_type and (${WKDBConst.tableChannel}.channel_name like ? or ${WKDBConst.tableChannel}.channel_remark like ? or ${WKDBConst.tableChannelMember}.member_name like ? or ${WKDBConst.tableChannelMember}.member_remark like ?) group by ${WKDBConst.tableChannel}.channel_id,${WKDBConst.tableChannel}.channel_type) t,${WKDBConst.tableChannelMember} cm where t.channel_id=cm.channel_id and t.channel_type=cm.channel_type and t.mid=cm.id";
    List<Map<String, Object?>> results = await WKDBHelper.shared
        .getDB()!
        .rawQuery(
            sql, ['%$keyword%', '%$keyword%', '%$keyword%', '%$keyword%']);
    for (Map<String, Object?> data in results) {
      var memberName = WKDBConst.readString(data, 'member_name');
      var memberRemark = WKDBConst.readString(data, 'member_remark');
      var channel = WKDBConst.serializeChannel(data);
      var result = WKChannelSearchResult();
      result.channel = channel;
      if (memberRemark != '') {
        if (memberRemark.toUpperCase() == keyword.toUpperCase()) {
          result.containMemberName = memberRemark;
        }
      }
      if (result.containMemberName == '') {
        if (memberName != '') {
          if (memberName.toUpperCase() == keyword.toUpperCase()) {
            result.containMemberName = memberName;
          }
        }
      }
      list.add(result);
    }
    return list;
  }

  Future<List<WKChannel>> queryWithFollowAndStatus(
      int channelType, int follow, int status) async {
    List<WKChannel> list = [];
    var sql =
        "select * from ${WKDBConst.tableChannel} where channel_type=? and follow=? and status=? and is_deleted=0";
    List<Map<String, Object?>> results = await WKDBHelper.shared
        .getDB()!
        .rawQuery(sql, [channelType, follow, status]);
    for (Map<String, Object?> data in results) {
      var channel = WKDBConst.serializeChannel(data);
      list.add(channel);
    }
    return list;
  }

  Future<List<WKChannel>> queryWithMuted() async {
    List<WKChannel> list = [];
    var sql = "select * from ${WKDBConst.tableChannel} where mute=1";
    List<Map<String, Object?>>? results =
        await WKDBHelper.shared.getDB()?.rawQuery(sql);
    if (results == null || results.isEmpty) {
      return list;
    }
    for (Map<String, Object?> data in results) {
      var channel = WKDBConst.serializeChannel(data);
      list.add(channel);
    }
    return list;
  }

  Future<List<WKChannel>> searchWithChannelTypeAndFollow(
      String keyword, int channelType, int follow) async {
    List<WKChannel> list = [];
    var sql =
        "select * from ${WKDBConst.tableChannel} where (channel_name LIKE ? or channel_remark LIKE ?) and channel_type=? and follow=?";
    List<Map<String, Object?>> results = await WKDBHelper.shared
        .getDB()!
        .rawQuery(sql, ['%$keyword%', '%$keyword%', channelType, follow]);
    for (Map<String, Object?> data in results) {
      var channel = WKDBConst.serializeChannel(data);
      list.add(channel);
    }
    return list;
  }

  dynamic getMap(WKChannel channel) {
    var data = HashMap<String, Object>();
    data['channel_id'] = channel.channelID;
    data['channel_type'] = channel.channelType;
    data['channel_name'] = channel.channelName;
    data['channel_remark'] = channel.channelRemark;
    data['avatar'] = channel.avatar;
    data['top'] = channel.top;
    data['save'] = channel.save;
    data['mute'] = channel.mute;
    data['forbidden'] = channel.forbidden;
    data['invite'] = channel.invite;
    data['status'] = channel.status;
    data['is_deleted'] = channel.isDeleted;
    data['follow'] = channel.follow;
    data['version'] = channel.version;
    data['show_nick'] = channel.showNick;
    data['created_at'] = channel.createdAt;
    data['updated_at'] = channel.updatedAt;
    data['online'] = channel.online;
    data['last_offline'] = channel.lastOffline;
    data['receipt'] = channel.receipt;
    data['robot'] = channel.robot;
    data['category'] = channel.category;
    data['username'] = channel.username;
    data['avatar_cache_key'] = channel.avatarCacheKey;
    data['device_flag'] = channel.deviceFlag;
    data['parent_channel_id'] = channel.parentChannelID;
    data['parent_channel_type'] = channel.parentChannelType;
    data['remote_extra'] = channel.remoteExtraMap?.toString() ?? "";
    data['extra'] = channel.localExtra?.toString() ?? "";
    return data;
  }
}
