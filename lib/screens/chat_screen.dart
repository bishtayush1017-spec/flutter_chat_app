import 'package:chat_app/services/chat_service.dart';
import 'package:chat_app/widgets/chat_bubble.dart';
import 'package:chat_app/widgets/read_receipt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.receiverEmail, required this.receiverID});

  final String receiverEmail;
  final String receiverID;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final myFocusNode = FocusNode();

  bool _isBlocked = false;

  void scrollDown() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 500), () => scrollDown());
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () => scrollDown());

    _checkIfBlocked();
    _markMessagesAsRead(); // Mark messages as read when screen opens
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead(); // Mark messages as read when app comes to foreground
    }
  }

  void _markMessagesAsRead() {
    MyChatService().markMessagesAsRead(widget.receiverID);
  }

  void _checkIfBlocked() async {
    final currentUserID = FirebaseAuth.instance.currentUser!.uid;
    final blockedDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.receiverID)
        .collection('BlockedUsers')
        .doc(currentUserID)
        .get();

    if (blockedDoc.exists) {
      setState(() {
        _isBlocked = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    myFocusNode.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void sendMessage() async {
    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You cannot message this user. They have blocked you.")),
      );
      return;
    }

    if (_messageController.text.isNotEmpty) {
      final temp = _messageController.text;
      _messageController.clear();
      await MyChatService().sendMessage(widget.receiverID, temp);
    }
    scrollDown();
  }

  // Clear chat for current user only
  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear this chat? This action cannot be undone. The chat will only be cleared for you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await MyChatService().clearChatForUser(widget.receiverID);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat has been cleared'))
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red))
          )
        ],
      )
    );
  }

  // Block user function (moved from UserTile)
  void _blockUser() {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text("Do you want to block this user? This will prevent them from sending you messages."),
        actions: [
          // cancel button
          TextButton(
            onPressed: () => Navigator.of(context).pop(), 
            child: const Text('Cancel')),

          // Block button
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
               Navigator.of(context).pop(); // Go back to home screen after blocking
              await MyChatService().blockUser(widget.receiverID);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("User has been blocked")));
            }, 
            child: const Text('Block', style: TextStyle(color: Colors.red)))
        ],
      )
    );
  }

  Widget _buildMessageList() {
  String senderID = FirebaseAuth.instance.currentUser!.uid;
  return StreamBuilder(
    stream: MyChatService().getMessages(widget.receiverID, senderID),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text("Error");
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Text('Loading...');
      }
      
      // Filter out messages that have been cleared by the current user
      final currentUserID = FirebaseAuth.instance.currentUser!.uid;
      final filteredDocs = snapshot.data!.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic>? clearedFor = data['clearedFor'];
        return clearedFor == null || clearedFor[currentUserID] != true;
      }).toList();
      
      
      
      // Auto-scroll to bottom when new messages are received
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          scrollDown();
        }
        // Mark messages as read after building
        _markMessagesAsRead();
      });
      
      return ListView.builder(
        controller: _scrollController,
        itemCount: filteredDocs.length,
        itemBuilder: (context, index) {
          final doc = filteredDocs[index];
          final isLastMessage = index == filteredDocs.length - 1;
          
          return Column(
            children: [
              _buildMessageItem(doc),
              // Show read receipt only for the last message sent by current user
              if (isLastMessage) _buildReadReceipt(),
            ],
          );
        },
      );
    },
  );
}

Widget _buildReadReceipt() {
  return StreamBuilder<Map<String, dynamic>?>(
    stream: MyChatService().getLastMessageReadReceiptStream(widget.receiverID),
    builder: (context, snapshot) {
      
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Container(
          padding: EdgeInsets.only(right: 45, bottom: 8, top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Loading...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      }
      
      if (!snapshot.hasData || snapshot.data == null) {
        return Container(
          padding: EdgeInsets.only(right: 45, bottom: 8, top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            
          ),
        );
      }

      final receiptData = snapshot.data!;
      return ReadReceiptWidget(
        isRead: receiptData['isRead'] ?? false,
        readAt: receiptData['readAt'],
      );
    },
  );
}

  

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isCurrentUser = data['senderID'] == FirebaseAuth.instance.currentUser!.uid;
    var alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    return Container(
      alignment: alignment,
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message: data['message'],
            isCurrentUser: isCurrentUser,
            messageID: doc.id,
            userID: data['senderID'],
            receiverID: widget.receiverID, // Pass receiverID for unsend functionality
            messageData: data, // Pass full message data for unsend checks
          )
        ],
      ),
    );
  }

  Widget _buildUserInput() {
    if (_isBlocked) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          "You cannot send messages. This user has blocked you.",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 50, left: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(hintText: "Type a message"),
              focusNode: myFocusNode,
            ),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            margin: EdgeInsets.only(right: 25),
            child: IconButton(
              onPressed: sendMessage,
              icon: Icon(Icons.send, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverEmail),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert), // 3-dot menu icon
            onSelected: (value) {
              if (value == 'clear_chat') {
                _clearChat();
              } else if (value == 'block_user') {
                _blockUser();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'clear_chat',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear Chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'block_user',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Block User', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildUserInput(),
        ],
      ),
    );
  }
}