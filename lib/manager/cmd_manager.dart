import 'dart:collection';

import 'package:wukongimfluttersdk/db/const.dart';

import '../entity/cmd.dart';

/// 命令管理器，处理和分发命令
class WKCMDManager {
  WKCMDManager._privateConstructor() {
    _cmdListeners = HashMap<String, Function(WKCMD)>();
  }
  static final WKCMDManager _instance = WKCMDManager._privateConstructor();
  static WKCMDManager get shared => _instance;

  /// 命令监听器集合
  late final HashMap<String, Function(WKCMD)> _cmdListeners;

  /// 处理从服务器接收的命令
  void handleCMD(dynamic json) {
    // 解析命令
    String cmd = WKDBConst.readString(json, 'cmd');
    dynamic param = json['param'];
    
    // 补充频道信息（如果缺失）
    if (param != null && param is Map) {
      if (!param.containsKey('channel_id')) {
        param['channel_id'] = json['channel_id'];
        param['channel_type'] = json['channel_type'];
      }
    }
    
    // 创建命令对象并分发
    WKCMD wkcmd = WKCMD();
    wkcmd.cmd = cmd;
    wkcmd.param = param;
    _notifyListeners(wkcmd);
  }

  /// 分发命令到所有监听器
  void _notifyListeners(WKCMD wkcmd) {
    _cmdListeners.forEach((key, listener) {
      listener(wkcmd);
    });
  }

  /// 添加命令监听器
  /// [key] 监听器唯一标识
  /// [listener] 命令回调函数
  void addOnCmdListener(String key, Function(WKCMD) listener) {
    _cmdListeners[key] = listener;
  }

  /// 移除命令监听器
  /// [key] 监听器唯一标识
  void removeCmdListener(String key) {
    _cmdListeners.remove(key);
  }
}
