### 1.0.0
 * first commint
### 1.0.1
 * update connection
### 1.0.2
 * Reconnect when handling connection errors
### 1.0.3
 * update sync channel msgs
### 1.0.4
 * update manager method of obtaining
### 1.0.5
 * Optimize processing of incorrect data
### 1.0.6
 * Update sending messages without notification to refresh conversation messsage
### 1.0.7
 * Support message receipts
 ### 1.0.8
 * Modify Query History Message
 ### 1.0.9
 * Optimize Query History Message
 ### 1.1.0
 * Update query conversation all record
 ### 1.1.1
 * Update online cmd messages
 ### 1.1.2
 * Optimize connections
 ### 1.1.3
 * Add some methods
 ### 1.1.4
 * update set reddot method
 ### 1.1.5
 * update connnection device id with uid
 ### 1.1.6
 * New features such as message likes and replies added
 ### 1.1.7
 * Modifying message parsing errors with reminder itemss
 ### 1.1.8
 * Update message reactions
 ### 1.1.9
 * Modify message reply to ack issue and Add protocol device flag field 
 ### 1.2.0
 * Modify query channel message error issue 
 ### 1.2.1
 * Update channel info refresh listener and optimize data insertion issues
 ### 1.2.2
 * Modifying the issue of reconnecting disconnected objects without destroying them
 ### 1.2.3
 * Optimize message queries
 ### 1.2.4
 * Optimize connection
 ### 1.2.5
 * Modifying the issue of disconnected sockets not being destroyed
 ### 1.2.6
 * update query message extra data
 ### 1.2.7
 * update query channel member avatar 
 ### 1.2.8
 * Modify the editing message method parameters
 ### 1.2.9
 * Modification of sending messages containing replies or tag class message parsing errors
 ### 1.3.0
 * Modification of sending messages containing replies error
 ### 1.3.1
 * fix: synchronization channel message multiple synchronization issue
 ### 1.3.2
 * fix: Optimization of loading channel messages without the latest messages and multiple synchronization issues
 ### 1.3.3
 * fix: Optimization of loading channel messages without the latest messages and multiple synchronization issues
 ### 1.3.4
 * fix: Optimize connections
 ### 1.3.5
 * fix: Add clear channel messages method
 ### 1.3.6
 * fix: Add clear all channel red dots method
 ### 1.3.7
 * fix: Add send message can reminder member method
 ### 1.3.8
 * fix: Update message save remote extra method
 ### 1.3.9
 * fix: Update RecvAckPacket header encode method
 ### 1.4.0
 * fix: Optimize JSON storage for channel, conversation, message, reminder extra fields and harden sync parsing
 ### 1.4.0
 * fix: Modifying the issue of a large number of offline messages getting stuck during synchronization
 ### 1.4.1
 * fix: Modifying non JSON serialization errors in extended fields
 ### 1.4.2
 * fix: Optimize synchronization channel messages
 ### 1.4.3
 * fix: Modifying messages sent by oneself will increase the issue of unread quantity
 ### 1.4.4
 * fix: Update parsing channel member extension data
 ### 1.4.5
 * fix: Update send & recv message No fromChannel information added
 ### 1.4.6
 * fix: Update send message fromChannel information is Null
 ### 1.4.7
 * fix: Upgrade message protocol, add message extension topping function and the ability to send expired messages
### 1.4.8
 * fix: Upgrade send message api
 ### 1.4.9
 * fix: Upgrade save channel member extra data api
 ### 1.5.0
 * fix: Upgrade send noPersist message
### 1.5.1
 * fix: Add connection ack and return nodeId
### 1.5.2
 * fix: Add search channel and message method
### 1.5.3
 * fix: Compatibility message extension editing content is empty, parsing error issue
### 1.5.4
 * fix: Update sync channel message
 ### 1.5.5
 * fix: After successfully modifying the synchronization channel message, no problem was returned
 ### 1.5.6
 * fix: Optimize reconnection and resend messages
 ### 1.5.7
 * fix: Optimize channel fields in cmd messages
 ### 1.5.8
 * fix: Add query total unread quantity and query followed channels
 ### 1.5.9
 * fix: Modify network monitoring
 ### 1.6.0
 * fix: Error in modifying the channel extension data synchronized to the most recent session
 ### 1.6.1
 * fix: 修复网络切换时有时无法连接问题
### 1.6.2
 * fix: 修改数据库解码错误数据导致oom
### 1.6.3
 * fix: 优化在未收到服务端心跳消息时主动断开重连
### 1.6.4
 * fix: 新增监听头像改变事件###
### 1.6.5
 * fix: 修改频道和频道成员及提醒项扩展字段保存错误问题
### 1.6.6
 * fix: 修改协议编码字符串错误问题
### 1.6.7
 * fix: 修改协议编码字符串错误问题
### 1.6.8
 * fix: 升级一些库
### 1.6.9
 * bugfix: 修改修改提醒项无效问题
### 1.7.0
 * fix: 向下兼容一些第三方库
### 1.7.1
 * fix: 提醒项支持按类型查询
### 1.7.3
 * fix: 优化扩展字段 JSON 存储与会话同步解析错误
### 1.7.4
 * fix: 修复消息本地扩展字段更新时类型不一致问题，统一使用 Map<String, dynamic> 类型
### 1.7.5
 * fix: 修复 reaction.dart 中 insertReaction 方法缺少返回值导致调用失败的问题
 * fix: 修复 reaction.dart 中 getReactionMap 方法缺少 return 语句的问题
 * fix: 修复 reaction.dart 中 channel_id 字段重复赋值的问题
### 1.7.6
 * fix: 修复 message.dart 中批量更新消息扩展数据时使用错误数组索引导致数据更新错误的严重问题
 * fix: 修复 message.dart 中空 clientMsgNO 被添加到查询列表的逻辑错误
 * fix: 修复 channel_member.dart 中冗余的条件检查
 * fix: 修复 channel.dart 中 insert 和 update 方法缺少返回类型和返回值的问题
### 1.7.7
 * fix: 调整消息回应限制同一个频道同一条消息只能有一次回应
### 1.7.8
 * fix: 新增查询频道最大回应编号
### 1.7.9
 * fix: 补全 queryAll 会话查询结果中的最后一条消息、消息扩展和发送者信息
