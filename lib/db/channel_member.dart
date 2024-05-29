import 'package:sqflite/sqflite.dart';

import '../entity/channel_member.dart';
import 'const.dart';
import 'wk_db_helper.dart';

class ChannelMemberDB {
  ChannelMemberDB._privateConstructor();
  static final ChannelMemberDB _instance =
      ChannelMemberDB._privateConstructor();
  static ChannelMemberDB get shared => _instance;
  final String channelCols =
      "${WKDBConst.tableChannel}.channel_remark,${WKDBConst.tableChannel}.channel_name,${WKDBConst.tableChannel}.avatar,${WKDBConst.tableChannel}.avatar_cache_key";

  Future<List<WKChannelMember>> queryMemberWithUIDs(
      String channelID, int channelType, List<String> uidList) async {
    List<Object> args = [];
    args.add(channelID);
    args.add(channelType);
    args.addAll(uidList);
    List<WKChannelMember> list = [];
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableChannelMember,
        where:
            "channel_id=? and channel_type=? and member_uid in (${WKDBConst.getPlaceholders(uidList.length)})",
        whereArgs: args);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeChannelMember(data));
      }
    }
    return list;
  }

  Future<int> getMaxVersion(String channelID, int channelType) async {
    String sql =
        "select max(version) version from ${WKDBConst.tableChannelMember} where channel_id =? and channel_type=? limit 0, 1";
    int version = 0;

    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql, [channelID, channelType]);
    if (results.isNotEmpty) {
      dynamic data = results[0];
      version = WKDBConst.readInt(data, 'version');
    }
    return version;
  }

  Future<WKChannelMember?> queryWithUID(
      String channelId, int channelType, String memberUID) async {
    String sql =
        "select ${WKDBConst.tableChannelMember}.*,$channelCols from ${WKDBConst.tableChannelMember} left join ${WKDBConst.tableChannel} on ${WKDBConst.tableChannelMember}.member_uid = ${WKDBConst.tableChannel}.channel_id AND ${WKDBConst.tableChannel}.channel_type=1 where (${WKDBConst.tableChannelMember}.channel_id=? and ${WKDBConst.tableChannelMember}.channel_type=? and ${WKDBConst.tableChannelMember}.member_uid=?)";
    WKChannelMember? channelMember;
    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()
        .rawQuery(sql, [channelId, channelType, memberUID]);
    if (list.isNotEmpty) {
      channelMember = WKDBConst.serializeChannelMember(list[0]);
    }
    return channelMember;
  }

  Future<List<WKChannelMember>?> queryWithChannel(
      String channelId, int channelType) async {
    String sql =
        "select ${WKDBConst.tableChannelMember}.*,$channelCols from ${WKDBConst.tableChannelMember} LEFT JOIN ${WKDBConst.tableChannel} on ${WKDBConst.tableChannelMember}.member_uid=${WKDBConst.tableChannel}.channel_id and ${WKDBConst.tableChannel}.channel_type=1 where ${WKDBConst.tableChannelMember}.channel_id=? and ${WKDBConst.tableChannelMember}.channel_type=? and ${WKDBConst.tableChannelMember}.is_deleted=0 and ${WKDBConst.tableChannelMember}.status=1 order by ${WKDBConst.tableChannelMember}.role=1 desc,${WKDBConst.tableChannelMember}.role=2 desc,${WKDBConst.tableChannelMember}.created_at asc";
    List<WKChannelMember> list = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB().rawQuery(sql, [channelId, channelType]);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeChannelMember(data));
      }
    }
    return list;
  }

  Future<List<WKChannelMember>> queryWithUIDs(
      String channelID, int channelType, List<String> uidList) async {
    List<Object> args = [];
    args.add(channelID);
    args.add(channelType);
    args.addAll(uidList);

    List<WKChannelMember> list = [];
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB().query(
        WKDBConst.tableChannelMember,
        where:
            "channel_id=? and channel_type=? and member_uid in (${WKDBConst.getPlaceholders(uidList.length)}) ",
        whereArgs: args);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeChannelMember(data));
      }
    }
    return list;
  }

  insertList(List<WKChannelMember> allMemberList) {
    List<Map<String, Object>> insertCVList = [];
    for (WKChannelMember channelMember in allMemberList) {
      insertCVList.add(getMap(channelMember));
    }
    if (insertCVList.isNotEmpty) {
      WKDBHelper.shared.getDB().transaction((txn) async {
        if (insertCVList.isNotEmpty) {
          for (Map<String, dynamic> value in insertCVList) {
            txn.insert(WKDBConst.tableChannelMember, value,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });
    }
  }

  dynamic getMap(WKChannelMember member) {
    var map = <String, Object>{};
    map['channel_id'] = member.channelID;
    map['channel_type'] = member.channelType;
    map['member_invite_uid'] = member.memberInviteUID;
    map['member_uid'] = member.memberUID;
    map['member_name'] = member.memberName;
    map['member_remark'] = member.memberRemark;
    map['member_avatar'] = member.memberAvatar;
    map['member_avatar_cache_key'] = member.memberAvatarCacheKey;
    map['role'] = member.role;
    map['is_deleted'] = member.isDeleted;
    map['version'] = member.version;
    map['status'] = member.status;
    map['robot'] = member.robot;
    map['forbidden_expiration_time'] = member.forbiddenExpirationTime;
    map['created_at'] = member.createdAt;
    map['updated_at'] = member.updatedAt;
    return map;
  }
}
