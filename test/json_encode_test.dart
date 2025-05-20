import 'dart:convert';

void main() {
  // 测试 dynamic 类型的空数据
  dynamic emptyList = [];
  print('Empty list: ${jsonEncode(emptyList)}');
  
  dynamic emptyMap = {};
  print('Empty map: ${jsonEncode(emptyMap)}');
  
  // 测试其他类型的空数据
  dynamic emptyInt = 0;
  print('Empty int (0): ${jsonEncode(emptyInt)}');
  
  dynamic emptyDouble = 0.0;
  print('Empty double (0.0): ${jsonEncode(emptyDouble)}');
  
  dynamic emptyBool = false;
  print('Empty bool (false): ${jsonEncode(emptyBool)}');
  
  // 测试 null
  print('Null value: ${jsonEncode(null)}');
  
  // 测试空字符串
  String emptyString = '';
  print('Empty string: ${jsonEncode(emptyString)}');
  
  // 测试普通字符串
  String normalString = 'Hello World';
  print('Normal string: ${jsonEncode(normalString)}');
  
  // 测试包含特殊字符的字符串
  String specialString = 'Hello "World" with \'quotes\' and \\backslash\\';
  print('Special string: ${jsonEncode(specialString)}');
  
  // 测试包含换行符的字符串
  String multilineString = 'Line 1\nLine 2\nLine 3';
  print('Multiline string: ${jsonEncode(multilineString)}');
  
  // 测试包含Unicode字符的字符串
  String unicodeString = '你好，世界！';
  print('Unicode string: ${jsonEncode(unicodeString)}');
} 