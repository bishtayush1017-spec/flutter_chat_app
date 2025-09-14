import 'package:chat_app/screens/chat_screen.dart';
import 'package:chat_app/screens/search_screen.dart';
import 'package:chat_app/services/chat_service.dart';
import 'package:chat_app/widgets/drawer.dart';
import 'package:chat_app/widgets/user_tile.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // build individual list tile for user
  Widget _buildUserListItem(Map<String, dynamic> userData, BuildContext context) {
    return UserTile(
      text: userData['email'],
      userID: userData['uid'], // Pass the user ID
      onTap: (){
        // tapped on a user, go to chat screen
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ChatScreen(
            receiverEmail: userData['email'], 
            receiverID: userData['uid'],)));
      },
      
    );
  }


  Widget _buildUserList() {
    return StreamBuilder(
      stream: MyChatService().getRealTimeChatListUsers(), // Real-time ChatList updates with blocked user filtering
      builder: (context, snapshot) {
        // error 
        if(snapshot.hasError) {
          return const Text("Error");
        }

        // loading
        if(snapshot.connectionState == ConnectionState.waiting){
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Check if chat list is empty
        final chatListUsers = snapshot.data as List<Map<String, dynamic>>;
        
        if (chatListUsers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No chats yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Use the search feature to find and add users to chat with',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        // return the listview with chat list users
        return ListView(
          children: chatListUsers
              .map((userData) => _buildUserListItem(userData, context))
              .toList(),
        );
      },
    );
  }





  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Chats"),
          actions: [
            // Quick access to search
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      
        drawer: const MyDrawer(),
      
        body: _buildUserList(),
      ),
    );
  }
}
