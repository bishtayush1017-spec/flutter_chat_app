import 'package:chat_app/services/chat_service.dart';
import 'package:chat_app/widgets/user_tile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BlockedUsers extends StatelessWidget {
  const BlockedUsers({super.key});

void _showUnblockBox(BuildContext context, String userID){
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unblock User'),
      content: const Text('Do you want to unblock this user'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('Cancel')),

          TextButton(
          onPressed: () {
            MyChatService().unblockUser(userID);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User has been unblocked")));
          }, 
          child: const Text('Unblock'))

      ],
    ));
}

  @override
  Widget build(BuildContext context) {
    String userID = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Blocked Users'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: MyChatService().getBlockedUsersStream(userID),
        builder: (context, snapshot){
          if(snapshot.hasError){
            return const Center(child: Text('Error'),);
          }
          if(snapshot.connectionState == ConnectionState.waiting){
            return const Center(child: CircularProgressIndicator(),);
          }
          
          final blockedUsers = snapshot.data ?? [];

          if (blockedUsers.isEmpty){
            return const Center(child: Text("No blocked users"),);
          }
          return ListView.builder(
            itemCount: blockedUsers.length,
            itemBuilder: (context, index) {
            final user = blockedUsers[index];
            return UserTile(
              userID: userID,
              text: user['email'], 
              onTap: () => _showUnblockBox(context, user['uid']));
          });

        }
      ),
    );
  }
}