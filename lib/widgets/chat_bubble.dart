import 'package:chat_app/services/chat_service.dart';
import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key, 
    required this.message, 
    required this.isCurrentUser, 
    required this.messageID, 
    required this.userID,
    required this.receiverID, // Added receiverID parameter
    this.messageData, // Added messageData parameter for unsend checks
  });

  final String message;
  final bool isCurrentUser;
  final String messageID;
  final String userID;
  final String receiverID; // Added to know who to pass to unsend function
  final Map<String, dynamic>? messageData; // Added for unsend checks

  // report message
  void _reportMessage(BuildContext context, String messageID, String userID){
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('Report Message'),
        content: const Text("Are you sure you want to report this message"),
        actions: [
          // cancel button
          TextButton(
            onPressed: () => Navigator.of(context).pop(), 
            child: const Text('Cancel')),

          // Report button
          TextButton(
            onPressed: () {
              MyChatService().reportUser(messageID, userID);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Message has been Reported")));
            }, 
            child: const Text('Report'))
        ],
      )
    );
  }

  // UNSEND MESSAGE FEATURE
  void _unsendMessage(BuildContext context, String messageID, String receiverID) {
    showDialog(
      context: context,
      builder: (context) {
        return  AlertDialog(
        title: const Text('Unsend Message'),
        content: const Text("Are you sure you want to unsend this message? This action cannot be undone."),
        actions: [
          // cancel button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')
          ),
          
          // Unsend button
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await MyChatService().unsendMessage(messageID, receiverID);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Message has been unsent"))
              );
            },
            child: const Text('Unsend', style: TextStyle(color: Colors.red))
          )
        ],
      );
      }
    );
  }

  // show options for other users' messages (removed block functionality)
  void _showOtherUserOptions(BuildContext context, String messageID, String userID){
    showModalBottomSheet(
      context: context, 
      builder: (context){
        return SafeArea(child: Wrap(
          children: [
            // report button
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('Report'),
              onTap: (){
                Navigator.of(context).pop();
                _reportMessage(context, messageID, userID);
              },
            ),

            // cancel button
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: (){
                Navigator.pop(context);
              },
            )
          ],
        ));
      }
    );
  }

  // show options for current user's messages
  void _showCurrentUserOptions(BuildContext context, String messageID, String receiverID) {
    // Check if message can be unsent
    bool canUnsend = messageData != null ? 
        MyChatService().canUnsendMessage(messageData!) : true;
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              // unsend message option (only show if message can be unsent)
              if (canUnsend)
                ListTile(
                  leading: const Icon(Icons.undo, color: Colors.red),
                  title: const Text('Unsend Message', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _unsendMessage(context, messageID, receiverID);
                  },
                ),
              
              // cancel button
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () {
                  Navigator.pop(context);
                },
              )
            ],
          )
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if message is unsent
    bool isUnsent = messageData?['isUnsent'] == true;
    
    return GestureDetector(
      onLongPress: (){
        if (isCurrentUser) {
          // Show options for current user (unsend)
          _showCurrentUserOptions(context, messageID, receiverID);
        } else {
          // Show options for other users 
          _showOtherUserOptions(context, messageID, userID);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 45),
        decoration: BoxDecoration(
          color: isUnsent 
              ? Colors.grey.shade300 
              : (isCurrentUser ? Colors.green : Colors.grey.shade500),
          borderRadius: BorderRadius.circular(12)
        ),
        child: Text(
          message, 
          style: TextStyle(
            color: isUnsent ? Colors.grey.shade600 : Colors.white,
            fontStyle: isUnsent ? FontStyle.italic : FontStyle.normal,
          )
        ),
      ),
    );
  }
}