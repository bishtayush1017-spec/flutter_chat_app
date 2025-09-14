import 'package:chat_app/services/chat_service.dart';
import 'package:flutter/material.dart';

class UserTile extends StatefulWidget {
  const UserTile({
    super.key, 
    required this.text, 
    required this.onTap,
    required this.userID,
    
  });

  final String text;
  final void Function()? onTap;
  final String userID;

  @override
  State<UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<UserTile> {
  final chatService = MyChatService();



  

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: chatService.getUnreadMessageCountStream(widget.userID),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return GestureDetector(
          onTap: () async {
            // Mark messages as read when user taps on the tile
            await chatService.markMessagesAsRead(widget.userID);
            // Execute the original onTap function
            if (widget.onTap != null) widget.onTap!();
          },
          
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(12)
            ),
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 25),
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                // icon
                Icon(Icons.person),

                const SizedBox(width: 20),

                // username
                Expanded(child: Text(widget.text)),

                // unread message count (real-time)
                if (unreadCount > 0)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}