import 'dart:collection';

import 'package:wukongimfluttersdk/db/const.dart';

import '../entity/cmd.dart';

class WKCMDManager {
  WKCMDManager._privateConstructor();
  static final WKCMDManager _instance = WKCMDManager._privateConstructor();
  static WKCMDManager get shared => _instance;

  HashMap<String, Function(WKCMD)>? _cmdback;
  handleCMD(dynamic json) {
    String cmd = WKDBConst.readString(json, 'cmd');
    dynamic param = json['param'];
    WKCMD wkcmd = WKCMD();
    wkcmd.cmd = cmd;
    wkcmd.param = param;
    pushCMD(wkcmd);
  }

  pushCMD(WKCMD wkcmd) {
    if (_cmdback != null) {
      _cmdback!.forEach((key, back) {
        back(wkcmd);
      });
    }
  }

  addOnCmdListener(String key, Function(WKCMD) back) {
    _cmdback ??= HashMap();
    _cmdback![key] = back;
  }

  removeCmdListener(String key) {
    if (_cmdback != null) {
      _cmdback!.remove(key);
    }
  }
}
