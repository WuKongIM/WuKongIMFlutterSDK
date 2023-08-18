import 'dart:collection';

import 'package:wukongimfluttersdk/db/reminder.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';

class WKReminderManager {
  HashMap<String, Function(List<WKReminder>)>? _newReminderback;

  Future<List<WKReminder>> getWithChannel(
      String channelID, int channelType, int done) {
    return ReminderDB.shared.queryWithChannel(channelID, channelType, done);
  }

  addOnNewReminderListener(String key, Function(List<WKReminder>) back) {
    _newReminderback ??= HashMap();
    _newReminderback![key] = back;
  }

  removeOnNewReminderListener(String key) {
    if (_newReminderback != null) {
      _newReminderback!.remove(key);
    }
  }

  setNewReminder(List<WKReminder> list) {
    if (_newReminderback != null) {
      _newReminderback!.forEach((key, back) {
        back(list);
      });
    }
  }

  saveOrUpdateReminders(List<WKReminder> list) async {
    if (list.isNotEmpty) {
      List<WKReminder> wkReminders =
          await ReminderDB.shared.saveReminders(list);
      if (wkReminders.isNotEmpty) {
        setNewReminder(list);
      }
    }
  }

  Future<int> getMaxVersion() async {
    return ReminderDB.shared.getMaxVersion();
  }
}
