import 'package:chat_app/screens/blocked_users.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body:  ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Blocked Users'),
              onTap: (){
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => BlockedUsers()));
              },
            ),
    );
  }
}