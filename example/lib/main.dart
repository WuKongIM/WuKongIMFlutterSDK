import 'dart:io';

import 'package:example/const.dart';
import 'package:example/http.dart';
import 'package:example/im.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'home.dart';

void main() {
  runApp(const MyApp());
  SystemChannels.lifecycle.setMessageHandler((msg) async {
    // msg是个字符串，是下面的值
    // AppLifecycleState.resumed
    // AppLifecycleState.inactive
    // AppLifecycleState.paused
    // AppLifecycleState.detached
    if (msg == "AppLifecycleState.paused") {
      print("应用在后台");
      WKIM.shared.connectionManager.disconnect(false);
    } else if (msg == "AppLifecycleState.resumed") {
      print("应用在前台");
      WKIM.shared.connectionManager.connect();
    }
    return msg;
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginDemo(),
    );
  }
}

class LoginDemo extends StatefulWidget {
  const LoginDemo({super.key});

  @override
  LoginDemoState createState() => LoginDemoState();
}

class LoginDemoState extends State<LoginDemo> {
  var apiStr = '';
  var uidStr = '';
  var tokenStr = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("登录"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 60.0),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      '悟空IM登录',
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '悟空IM演示程序。当前SDK版本：V1.0.1',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  left: 15.0, right: 15.0, top: 60, bottom: 0),
              child: TextField(
                onChanged: (val) {
                  apiStr = val;
                },
                decoration: const InputDecoration(
                    labelText: 'API基地址',
                    hintText: 'API基地址 默认【https://api.githubim.com】'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  left: 15.0, right: 15.0, top: 10, bottom: 0),
              child: TextField(
                onChanged: (val) {
                  uidStr = val;
                },
                decoration: const InputDecoration(
                    labelText: 'uid', hintText: '登录uid【随意输入】'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  left: 15.0, right: 15.0, top: 10, bottom: 0),
              child: TextField(
                onChanged: (val) {
                  tokenStr = val;
                },
                decoration: const InputDecoration(
                    labelText: 'token', hintText: '登录token【随意输入】'),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 30),
              child: MaterialButton(
                color: Colors.blue,
                height: 45,
                minWidth: 300,
                child: const Text(
                  '登录',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                onPressed: () async {
                  if (apiStr != '') {
                    HttpUtils.apiURL = apiStr;
                  }
                  if (uidStr == '' || tokenStr == '') {
                    showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('提示'),
                            content: const Text('uid和token不能为空'),
                            actions: <Widget>[
                              MaterialButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text("确定"),
                              ),
                            ],
                          );
                        });
                    return;
                  }
                  var status = await HttpUtils.login(uidStr, tokenStr);
                  if (status == HttpStatus.ok) {
                    UserInfo.token = tokenStr;
                    UserInfo.uid = uidStr;
                    IMUtils.initIM().then((result) {
                      if (result) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomePage()));
                      }
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
