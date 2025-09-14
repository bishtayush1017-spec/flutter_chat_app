import 'package:chat_app/screens/search_screen.dart';
import 'package:chat_app/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  void logout() async{
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [

              // Logo
              DrawerHeader(
            child: Center(
              child: Icon(
                Icons.message, 
                color: Theme.of(context).colorScheme.primary,
                size: 67),
            ),
          ),

          // home tile
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: ListTile(
              title: const Text("HOME"),
              leading: const Icon(Icons.home),
              onTap: (){
                // pop this
                Navigator.of(context).pop();
              },
            ),
          ),

          // Search User
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: ListTile(
              title: const Text("SEARCH USERS"),
              leading: const Icon(Icons.search),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => SearchScreen()));
              },
            ),
          ),

          // Settings
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: ListTile(
              title: const Text("SETTINGS"),
              leading: const Icon(Icons.settings),
              onTap: (){
                Navigator.of(context).pop();
                // push To settings page
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => SettingsScreen()));
              },
            ),
          ),
            ],
          ),
         

          // Logout
          Padding(
            padding: const EdgeInsets.only(left: 25, bottom: 26),
            child: ListTile(
              title: Text("LOGOUT"),
              leading: Icon(Icons.logout),
              onTap: logout,
            ),
          ),
        ],
      ),
    );
  }
}