import 'dart:io';

import 'package:example/const.dart';
import 'package:example/http.dart';
import 'package:example/im.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'ui_conversation.dart';

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
  LoginDemoState() {
    WKIM.shared.connectionManager.disconnect(false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0584FE), Color(0xFFF5F5F7)],
              stops: [0.0, 0.4],
            ),
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 100.0),
                child: Center(
                  child: Column(
                    children: [
                      const Text(
                        '悟空IM',
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2),
                      ),
                      const SizedBox(height: 10),
                      Image.network(
                        'https://img.shields.io/pub/v/wukongimfluttersdk.svg',
                        height: 25,
                        errorBuilder: (context, error, stackTrace) => const Text(
                          'V1.6.7',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (val) {
                          apiStr = val;
                        },
                        decoration: InputDecoration(
                          labelText: 'API基地址',
                          hintText: '默认 http://62.234.8.38:7090/v1',
                          prefixIcon: const Icon(Icons.link, color: Color(0xFF0584FE)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        onChanged: (val) {
                          uidStr = val;
                        },
                        decoration: InputDecoration(
                          labelText: 'UID',
                          hintText: '随意输入',
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF0584FE)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        onChanged: (val) {
                          tokenStr = val;
                        },
                        decoration: InputDecoration(
                          labelText: 'Token',
                          hintText: '随意输入',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0584FE)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0584FE), Color(0xFF00C6FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0584FE).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: MaterialButton(
                          onPressed: () async {
                            if (apiStr != '') {
                              HttpUtils.apiURL = apiStr;
                            }
                            if (uidStr == '' || tokenStr == '') {
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16)),
                                      title: const Text('提示'),
                                      content: const Text('UID和Token不能为空'),
                                      actions: <Widget>[
                                        TextButton(
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
                                  Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(builder: (_) => const HomePage()),
                                      (Route<dynamic> route) => false);
                                }
                              });
                            }
                          },
                          child: const Text(
                            '登 录',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
