import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/type/const.dart';

class InputDialog extends StatefulWidget {
  const InputDialog(
      {Key? key, this.hintText = "请输入对方uid...", this.title, this.back})
      : super(key: key);
  final Function(String channelID, int channelType)? back;
  final Widget? title; // Text('New nickname'.tr)
  final String? hintText;

  @override
  State<InputDialog> createState() => _InputDialogState(
      title: this.title, hintText: this.hintText, back: this.back);
}

enum RadioValue { personal, group }

RadioValue _radioValue = RadioValue.personal;

class _InputDialogState extends State<InputDialog> {
  final Function(String channelID, int channelType)? back;
  final TextEditingController _textEditingController = TextEditingController();
  var channelID = '';
  final Widget? title; // Text('New nickname'.tr)
  String? hintText;
  _InputDialogState(
      {required this.title, required this.hintText, required this.back});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title,
      content: SizedBox(
        height: 125,
        child: Column(
          children: [
            TextField(
                controller: _textEditingController,
                maxLength: 120,
                onChanged: (v) {
                  channelID = v;
                },
                decoration: InputDecoration(hintText: hintText),
                autofocus: true),
            Row(
              children: [
                Radio<RadioValue>(
                    value: RadioValue.personal,
                    groupValue: _radioValue,
                    onChanged: (value) {
                      setState(() {
                        hintText = '请输入对方uid';
                        _radioValue = value!;
                      });
                    }),
                const Text(
                  '单聊',
                  style: TextStyle(fontSize: 18.0),
                ),
                Radio<RadioValue>(
                    value: RadioValue.group,
                    groupValue: _radioValue,
                    onChanged: (value) {
                      setState(() {
                        hintText = '请输入群Id';
                        _radioValue = value!;
                      });
                    }),
                const Text(
                  '群聊',
                  style: TextStyle(fontSize: 18.0),
                ),
              ],
            )
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.green)),
          onPressed: () {
            int channelType = WKChannelType.personal;
            if (_radioValue == RadioValue.group) {
              channelType = WKChannelType.group;
            }
            if (channelID == '') {
              return;
            }
            Navigator.pop(context);
            back!(channelID, channelType);
          },
          child: const Text('确定', style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.transparent),
              elevation: MaterialStateProperty.all(0)),
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('取消', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
