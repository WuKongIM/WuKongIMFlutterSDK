import 'dart:collection';

import 'package:wukongimfluttersdk/db/channel_member.dart';

import '../entity/channel_member.dart';

class WKChannelMemberManager {
  WKChannelMemberManager._privateConstructor() {
    _newMembersBack = HashMap<String, Function(List<WKChannelMember>)>();
    _refreshMembersBack = HashMap<String, Function(WKChannelMember, bool)>();
    _deleteMembersBack = HashMap<String, Function(List<WKChannelMember>)>();
  }
  static final WKChannelMemberManager _instance =
      WKChannelMemberManager._privateConstructor();
  static WKChannelMemberManager get shared => _instance;

  late final HashMap<String, Function(List<WKChannelMember>)> _newMembersBack;
  late final HashMap<String, Function(WKChannelMember, bool)> _refreshMembersBack;
  late final HashMap<String, Function(List<WKChannelMember>)> _deleteMembersBack;

  Future<int> getMaxVersion(String channelID, int channelType) async {
    return ChannelMemberDB.shared.getMaxVersion(channelID, channelType);
  }

  Future<List<WKChannelMember>?> getMembers(
      String channelID, int channelType) async {
    return ChannelMemberDB.shared.queryWithChannel(channelID, channelType);
  }

  Future<WKChannelMember?> getMember(
      String channelID, int channelType, String memberUID) {
    return ChannelMemberDB.shared
        .queryWithUID(channelID, channelType, memberUID);
  }

  Future<void> saveOrUpdateList(List<WKChannelMember> list) async {
    if (list.isEmpty) return;
    
    String channelID = list[0].channelID;
    int channelType = list[0].channelType;

    List<WKChannelMember> addList = [];
    List<WKChannelMember> deleteList = [];
    List<WKChannelMember> updateList = [];

    List<WKChannelMember> existList = [];
    List<String> uidList = [];
    
    for (WKChannelMember channelMember in list) {
      // 分批处理，每200个UID查询一次数据库
      if (uidList.length == 200) {
        List<WKChannelMember> tempList = await ChannelMemberDB.shared
            .queryWithUIDs(
                channelMember.channelID, channelMember.channelType, uidList);
        if (tempList.isNotEmpty) {
          existList.addAll(tempList);
        }

        uidList.clear();
      }
      uidList.add(channelMember.memberUID);
    }

    // 处理剩余的UID
    if (uidList.isNotEmpty) {
      List<WKChannelMember> tempList = await ChannelMemberDB.shared
          .queryWithUIDs(channelID, channelType, uidList);
      if (tempList.isNotEmpty) {
        existList.addAll(tempList);
      }
    }

    // 分类处理成员：新增、更新或删除
    for (WKChannelMember channelMember in list) {
      bool isNewMember = true;
      for (int i = 0, size = existList.length; i < size; i++) {
        if (channelMember.memberUID == existList[i].memberUID) {
          isNewMember = false;
          if (channelMember.isDeleted == 1) {
            deleteList.add(channelMember);
          } else {
            if (existList[i].isDeleted == 1) {
              isNewMember = true;
            } else {
              updateList.add(channelMember);
            }
          }
          break;
        }
      }
      if (isNewMember) {
        addList.add(channelMember);
      }
    }

    // 保存或修改成员
    await ChannelMemberDB.shared.insertList(list);

    // 触发回调通知
    if (addList.isNotEmpty) {
      _notifyNewChannelMembers(addList);
    }
    if (deleteList.isNotEmpty) {
      _notifyDeleteChannelMembers(deleteList);
    }
    if (updateList.isNotEmpty) {
      for (int i = 0, size = updateList.length; i < size; i++) {
        _notifyRefreshChannelMember(updateList[i], i == updateList.length - 1);
      }
    }
  }

  void _notifyRefreshChannelMember(WKChannelMember member, bool isEnd) {
    _refreshMembersBack.forEach((key, back) {
      back(member, isEnd);
    });
  }

  void addOnRefreshMemberListener(String key, Function(WKChannelMember, bool) back) {
    _refreshMembersBack[key] = back;
  }

  void removeRefreshMemberListener(String key) {
    _refreshMembersBack.remove(key);
  }

  void _notifyDeleteChannelMembers(List<WKChannelMember> list) {
    _deleteMembersBack.forEach((key, back) {
      back(list);
    });
  }

  void addOnDeleteMemberListener(String key, Function(List<WKChannelMember>) back) {
    _deleteMembersBack[key] = back;
  }

  void removeDeleteMemberListener(String key) {
    _deleteMembersBack.remove(key);
  }

  void _notifyNewChannelMembers(List<WKChannelMember> list) {
    _newMembersBack.forEach((key, back) {
      back(list);
    });
  }

  void addOnNewMemberListener(String key, Function(List<WKChannelMember>) back) {
    _newMembersBack[key] = back;
  }

  void removeNewMemberListener(String key) {
    _newMembersBack.remove(key);
  }
}
