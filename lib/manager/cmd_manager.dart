import 'dart:collection';

import '../entity/cmd.dart';

class WKCMDManager {
  HashMap<String, Function(WKCMD)>? _cmdback;
  handleCMD(dynamic json) {
    String cmd = json['cmd'];
    dynamic param = json['param'];
    WKCMD wkcmd = WKCMD();
    wkcmd.cmd = cmd;
    wkcmd.param = param;
    if (_cmdback != null) {}
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
