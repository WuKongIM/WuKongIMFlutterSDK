import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/type/const.dart';

class InputDialog extends StatefulWidget {
  const InputDialog(
      {Key? key,
      this.isOnlyText = false,
      this.hintText = "请输入对方uid...",
      this.title,
      this.back})
      : super(key: key);
  final Function(String channelID, int channelType)? back;
  final Widget? title; // Text('New nickname'.tr)
  final String? hintText;
  final bool isOnlyText;
  @override
  State<InputDialog> createState() => _InputDialogState(
      title: title, hintText: hintText, back: back);
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
      title: title != null
          ? DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D1D1F),
              ),
              child: title!,
            )
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      backgroundColor: Colors.white,
      content: SizedBox(
        height: widget.isOnlyText ? 80 : 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                  controller: _textEditingController,
                  maxLength: 120,
                  onChanged: (v) {
                    channelID = v;
                  },
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    counterText: "",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 15),
                  autofocus: true),
            ),
            if (!widget.isOnlyText) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Radio<RadioValue>(
                      value: RadioValue.personal,
                      groupValue: _radioValue,
                      activeColor: const Color(0xFF0584FE),
                      onChanged: (value) {
                        setState(() {
                          hintText = '请输入对方UID';
                          _radioValue = value!;
                        });
                      }),
                  const Text(
                    '单聊',
                    style: TextStyle(fontSize: 15.0, color: Color(0xFF1D1D1F)),
                  ),
                  const SizedBox(width: 10),
                  Radio<RadioValue>(
                      value: RadioValue.group,
                      groupValue: _radioValue,
                      activeColor: const Color(0xFF0584FE),
                      onChanged: (value) {
                        setState(() {
                          hintText = '请输入群ID';
                          _radioValue = value!;
                        });
                      }),
                  const Text(
                    '群聊',
                    style: TextStyle(fontSize: 15.0, color: Color(0xFF1D1D1F)),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            '取消',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0584FE), Color(0xFF00C6FF)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
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
            child: const Text('确定',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
