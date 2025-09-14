import 'package:chat_app/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyChatService {

  // initialize
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // SEARCH USERS BY EMAIL
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    try {
      if (email.trim().isEmpty) return [];
      
      final currentUser = _auth.currentUser;
      
      // Search for users with matching email (case-insensitive)
      final querySnapshot = await _firestore
          .collection('Users')
          .where('email', isGreaterThanOrEqualTo: email.toLowerCase())
          .where('email', isLessThanOrEqualTo: email.toLowerCase() + '\uf8ff')
          .limit(10)
          .get();

      // Filter out current user and return results
      return querySnapshot.docs
          .where((doc) => doc.data()['email'] != currentUser!.email)
          .map((doc) => {
                ...doc.data(),
                'uid': doc.id, // Ensure uid is included
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ADD USER TO CHAT LIST
  Future<void> addUserToChatList(String userID, String userEmail) async {
    try {
      final currentUser = _auth.currentUser;
      
      await _firestore
          .collection('Users')
          .doc(currentUser!.uid)
          .collection('ChatList')
          .doc(userID)
          .set({
            'addedAt': FieldValue.serverTimestamp(),
            'userEmail': userEmail,
            'userID': userID,
          });
    } catch (e) {
      // Handle error silently
    }
  }

  // REMOVE USER FROM CHAT LIST
  Future<void> removeUserFromChatList(String userID) async {
    try {
      final currentUser = _auth.currentUser;
      
      await _firestore
          .collection('Users')
          .doc(currentUser!.uid)
          .collection('ChatList')
          .doc(userID)
          .delete();
    } catch (e) {
      // Handle error silently
    }
  }

  // CHECK IF USER IS IN CHAT LIST
  Future<bool> isUserInChatList(String userID) async {
    try {
      final currentUser = _auth.currentUser;
      
      final doc = await _firestore
          .collection('Users')
          .doc(currentUser!.uid)
          .collection('ChatList')
          .doc(userID)
          .get();
          
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // GET CHAT LIST USERS (UPDATED HOME SCREEN METHOD)
  Stream<List<Map<String, dynamic>>> getChatListUsers() {
    final currentUser = _auth.currentUser;
    
    return _firestore
        .collection('Users')
        .doc(currentUser!.uid)
        .collection('ChatList')
        .snapshots()
        .asyncMap((snapshot) async {
      
      if (snapshot.docs.isEmpty) return [];
      
      // Get user IDs from chat list
      final chatListUserIDs = snapshot.docs.map((doc) => doc.id).toList();
      
      // Get user details for each user in chat list
      final userDocs = await Future.wait(
        chatListUserIDs.map((userID) => 
          _firestore.collection('Users').doc(userID).get()
        )
      );
      
      // Filter out non-existent users and get their latest interaction
      List<Map<String, dynamic>> usersWithTimestamp = [];
      
      for (var doc in userDocs) {
        if (doc.exists) {
          final userData = doc.data()!;
          final latestMessageTimestamp = await _getLatestMessageTimestamp(
            currentUser.uid, 
            userData['uid']
          );
          
          usersWithTimestamp.add({
            ...userData,
            'latestInteraction': latestMessageTimestamp,
          });
        }
      }
      
      // Sort users by latest interaction (most recent first)
      usersWithTimestamp.sort((a, b) {
        Timestamp? timestampA = a['latestInteraction'];
        Timestamp? timestampB = b['latestInteraction'];
        
        if (timestampA != null && timestampB != null) {
          return timestampB.compareTo(timestampA);
        }
        if (timestampA != null) return -1;
        if (timestampB != null) return 1;
        return 0;
      });
      
      // Remove the latestInteraction field before returning
      return usersWithTimestamp.map((user) {
        user.remove('latestInteraction');
        return user;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getUserStream(){
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {

        // go through each user
        final user = doc.data();
        return user;
      }).toList();
    });
  }


  // get all users stream except the blocked users, ordered by latest interaction
  Stream<List<Map<String, dynamic>>> getUsersStreamExcludingBlocked(){
    final currentUser = _auth.currentUser;

    return _firestore
    .collection('Users')
    .doc(currentUser!.uid)
    .collection('BlockedUsers')
    .snapshots().asyncMap((snapshot) async{

      // get blocked users ids
      final blockedUsersIDs = snapshot.docs.map((doc) => doc.id).toList();

      // get all users
      final usersSnapshot = await _firestore.collection('Users').get();

      // get users excluding current user and blocked users
      List<Map<String, dynamic>> users = usersSnapshot
            .docs.where((doc)=> doc.data()['email']
             != currentUser.email && !blockedUsersIDs.contains(doc.id))
             .map((doc) => doc.data()).toList();

      // get latest interaction for each user and sort
      List<Map<String, dynamic>> usersWithTimestamp = await Future.wait(
        users.map((user) async {
          final latestMessageTimestamp = await _getLatestMessageTimestamp(currentUser.uid, user['uid']);
          return {
            ...user,
            'latestInteraction': latestMessageTimestamp,
          };
        })
      );

      // sort users by latest interaction (most recent first)
      usersWithTimestamp.sort((a, b) {
        Timestamp? timestampA = a['latestInteraction'];
        Timestamp? timestampB = b['latestInteraction'];
        
        // if both have timestamps, compare them (newest first)
        if (timestampA != null && timestampB != null) {
          return timestampB.compareTo(timestampA);
        }
        // if only A has timestamp, A comes first
        if (timestampA != null) return -1;
        // if only B has timestamp, B comes first  
        if (timestampB != null) return 1;
        // if neither has timestamp, maintain original order
        return 0;
      });

      // remove the latestInteraction field before returning
      return usersWithTimestamp.map((user) {
        user.remove('latestInteraction');
        return user;
      }).toList();
    });
  }

  // New method: get users with real-time chat updates
  Stream<List<Map<String, dynamic>>> getUsersWithRealTimeOrdering() {
    final currentUser = _auth.currentUser;
    
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      try {
        // get blocked users
        final blockedSnapshot = await _firestore
            .collection('Users')
            .doc(currentUser!.uid)
            .collection('BlockedUsers')
            .get();
        
        final blockedUsersIDs = blockedSnapshot.docs.map((doc) => doc.id).toList();

        // get all users
        final usersSnapshot = await _firestore.collection('Users').get();

        // get users excluding current user and blocked users
        List<Map<String, dynamic>> users = usersSnapshot
              .docs.where((doc)=> doc.data()['email']
               != currentUser.email && !blockedUsersIDs.contains(doc.id))
               .map((doc) => doc.data()).toList();

        // get latest interaction for each user and sort
        List<Map<String, dynamic>> usersWithTimestamp = await Future.wait(
          users.map((user) async {
            final latestMessageTimestamp = await _getLatestMessageTimestamp(currentUser.uid, user['uid']);
            return {
              ...user,
              'latestInteraction': latestMessageTimestamp,
            };
          })
        );

        // sort users by latest interaction (most recent first)
        usersWithTimestamp.sort((a, b) {
          Timestamp? timestampA = a['latestInteraction'];
          Timestamp? timestampB = b['latestInteraction'];
          
          if (timestampA != null && timestampB != null) {
            return timestampB.compareTo(timestampA);
          }
          if (timestampA != null) return -1;
          if (timestampB != null) return 1;
          return 0;
        });

        // remove the latestInteraction field before returning
        return usersWithTimestamp.map((user) {
          user.remove('latestInteraction');
          return user;
        }).toList();
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    }).distinct((previous, current) {
      if (previous.length != current.length) return false;
      for (int i = 0; i < previous.length; i++) {
        if (previous[i]['uid'] != current[i]['uid']) return false;
      }
      return true;
    });
  }

  // helper method to get the latest message timestamp between current user and another user
  Future<Timestamp?> _getLatestMessageTimestamp(String currentUserID, String otherUserID) async {
    try {
      // construct chat room ID
      List<String> ids = [currentUserID, otherUserID];
      ids.sort();
      String chatRoomID = ids.join('_');

      // get the latest message
      final querySnapshot = await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .orderBy("timestamp", descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['timestamp'] as Timestamp;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // get unread message count stream for real-time updates
  Stream<int> getUnreadMessageCountStream(String otherUserID) {
    final String currentUserID = _auth.currentUser!.uid;
    
    // construct chat room ID
    List<String> ids = [currentUserID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .where("receiverID", isEqualTo: currentUserID)
        .where("isRead", isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          // Filter out cleared messages
          final filteredDocs = snapshot.docs.where((doc) {
            Map<String, dynamic> data = doc.data();
            Map<String, dynamic>? clearedFor = data['clearedFor'];
            return clearedFor == null || clearedFor[currentUserID] != true;
          });
          return filteredDocs.length;
        });
  }

  // get unread message count for a specific user
  Future<int> getUnreadMessageCount(String otherUserID) async {
    try {
      final String currentUserID = _auth.currentUser!.uid;
      
      // construct chat room ID
      List<String> ids = [currentUserID, otherUserID];
      ids.sort();
      String chatRoomID = ids.join('_');

      // get messages where receiverID is current user and read status is false
      final querySnapshot = await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .where("receiverID", isEqualTo: currentUserID)
          .where("isRead", isEqualTo: false)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }


  // UPDATED: mark messages as read with timestamp
Future<void> markMessagesAsRead(String otherUserID) async {
  try {
    final String currentUserID = _auth.currentUser!.uid;
    print('Marking messages as read for user: $otherUserID'); // Debug
    
    // construct chat room ID
    List<String> ids = [currentUserID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    // get all unread messages for current user
    final querySnapshot = await _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .where("receiverID", isEqualTo: currentUserID)
        .where("isRead", isEqualTo: false)
        .get();

    print('Found ${querySnapshot.docs.length} unread messages'); // Debug

    // mark all as read with timestamp
    WriteBatch batch = _firestore.batch();
    final readTimestamp = FieldValue.serverTimestamp();
    
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': readTimestamp,
      });
    }
    await batch.commit();
    print('Marked messages as read successfully'); // Debug
  } catch (e) {
    print('Error marking messages as read: $e'); // Debug
  }
}

// GET READ RECEIPT STREAM FOR REAL-TIME UPDATES
Stream<Map<String, dynamic>?> getLastMessageReadReceiptStream(String otherUserID) {
  final String currentUserID = _auth.currentUser!.uid;
  
  // construct chat room ID
  List<String> ids = [currentUserID, otherUserID];
  ids.sort();
  String chatRoomID = ids.join('_');

  print('Getting read receipt stream for chatRoom: $chatRoomID'); // Debug

  return _firestore
      .collection("chat_rooms")
      .doc(chatRoomID)
      .collection("messages")
      .orderBy("timestamp", descending: false)
      .snapshots()
      .map((snapshot) {
    
    print('Got snapshot with ${snapshot.docs.length} messages'); // Debug
    
    if (snapshot.docs.isEmpty) {
      print('No messages found'); // Debug
      return null;
    }

    // Filter out cleared messages for current user
    final filteredDocs = snapshot.docs.where((doc) {
      Map<String, dynamic> data = doc.data();
      Map<String, dynamic>? clearedFor = data['clearedFor'];
      bool isCleared = clearedFor != null && clearedFor[currentUserID] == true;
      return !isCleared;
    }).toList();

    print('After filtering cleared messages: ${filteredDocs.length}'); // Debug

    if (filteredDocs.isEmpty) {
      print('No messages after filtering'); // Debug
      return null;
    }

    // Get the last message overall
    final lastMessage = filteredDocs.last.data();
    print('Last message sender: ${lastMessage['senderID']}, current user: $currentUserID'); // Debug
    
    // If the last message is from the other user, don't show read receipt
    if (lastMessage['senderID'] == otherUserID) {
      print('Last message is from other user, hiding read receipt'); // Debug
      return null;
    }

    // Find the last message sent by current user
    DocumentSnapshot? lastUserMessageDoc;
    for (int i = filteredDocs.length - 1; i >= 0; i--) {
      if (filteredDocs[i].data()['senderID'] == currentUserID) {
        lastUserMessageDoc = filteredDocs[i];
        break;
      }
    }

    if (lastUserMessageDoc == null) {
      print('No messages from current user found'); // Debug
      return null;
    }

    final messageData = lastUserMessageDoc.data() as Map<String, dynamic>;
    
    // Don't show read receipt for unsent messages
    if (messageData['isUnsent'] == true) {
      print('Last message is unsent, hiding read receipt'); // Debug
      return null;
    }

    print('Returning read receipt data: isRead=${messageData['isRead']}, readAt=${messageData['readAt']}'); // Debug

    return {
      'isRead': messageData['isRead'] ?? false,
      'readAt': messageData['readAt'],
      'messageId': lastUserMessageDoc.id,
    };
  });
}
  



  // Send a message
  Future<void> sendMessage(String receiverID, message) async {
  try {
    // get current user info
    final String currentUserID = FirebaseAuth.instance.currentUser!.uid;
    final String currentUserEmail = FirebaseAuth.instance.currentUser!.email!;
    final timeStamp = Timestamp.now();

    print('Sending message from $currentUserID to $receiverID'); // Debug log

    // Get receiver info
    final receiverDoc = await _firestore.collection('Users').doc(receiverID).get();
    
    if (!receiverDoc.exists) {
      print('Receiver document does not exist'); // Debug log
      throw Exception('Receiver not found');
    }
    
    final receiverData = receiverDoc.data()!;
    final String receiverEmail = receiverData['email'] ?? '';
    
    print('Receiver email: $receiverEmail'); // Debug log

    // create a new message
    Message newMessage = Message(
      senderID: currentUserID, 
      senderEmail: currentUserEmail, 
      receiverID: receiverID, 
      message: message, 
      timestamp: timeStamp);

    // construct chat room ID for the 2 users
    List<String> ids = [currentUserID, receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    // add the message to the database with isRead field
    await _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .add({
          ...newMessage.toMap(),
          'isRead': false, // new messages are unread by default
          'isUnsent': false, // new field to track unsent messages
        });


    // Add receiver to current user's chat list
    await _firestore
        .collection('Users')
        .doc(currentUserID)
        .collection('ChatList')
        .doc(receiverID)
        .set({
          'addedAt': FieldValue.serverTimestamp(),
          'userEmail': receiverEmail,
          'userID': receiverID,
        });


    // Add current user to receiver's chat list (THIS IS THE KEY FIX)
    await _firestore
        .collection('Users')
        .doc(receiverID)
        .collection('ChatList')
        .doc(currentUserID)
        .set({
          'addedAt': FieldValue.serverTimestamp(),
          'userEmail': currentUserEmail,
          'userID': currentUserID,
        });

  

  } catch (e) {
    print('Error in sendMessage: $e'); // Debug log
    rethrow;
  }
}



  // UNSEND MESSAGE FEATURE
  Future<void> unsendMessage(String messageID, String otherUserID) async {
    try {
      final String currentUserID = _auth.currentUser!.uid;
      
      // construct chat room ID
      List<String> ids = [currentUserID, otherUserID];
      ids.sort();
      String chatRoomID = ids.join('_');

      // get the message document
      final messageDoc = await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .doc(messageID)
          .get();

      if (messageDoc.exists) {
        final messageData = messageDoc.data() as Map<String, dynamic>;
        
        // check if the current user is the sender
        if (messageData['senderID'] == currentUserID) {
          // mark the message as unsent instead of deleting it
          await _firestore
              .collection("chat_rooms")
              .doc(chatRoomID)
              .collection("messages")
              .doc(messageID)
              .update({
                'isUnsent': true,
                'message': 'This message was unsent',
                'unsentAt': FieldValue.serverTimestamp(),
              });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // check if message can be unsent
  bool canUnsendMessage(Map<String, dynamic> messageData) {
    final String currentUserID = _auth.currentUser!.uid;
    
    // check if current user is the sender
    if (messageData['senderID'] != currentUserID) {
      return false;
    }
    
    // check if message is already unsent
    if (messageData['isUnsent'] == true) {
      return false;
    }
    
    return true;
  }

  // CLEAR CHAT FOR CURRENT USER ONLY
  Future<void> clearChatForUser(String otherUserID) async {
    try {
      final String currentUserID = _auth.currentUser!.uid;
      
      // construct chat room ID
      List<String> ids = [currentUserID, otherUserID];
      ids.sort();
      String chatRoomID = ids.join('_');

      // get all messages in the chat
      final querySnapshot = await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .get();

      // create a batch to update all messages
      WriteBatch batch = _firestore.batch();
      
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> messageData = doc.data();
        
        // create a field to track which users have cleared the chat
        Map<String, dynamic> clearedFor = messageData['clearedFor'] ?? {};
        clearedFor[currentUserID] = true;
        
        batch.update(doc.reference, {'clearedFor': clearedFor});
      }
      
      await batch.commit();
    } catch (e) {
      // Handle error silently
    }
  }

  // get messages (updated to filter out cleared messages)
  Stream<QuerySnapshot> getMessages(String userID, otherUserID) {
    // construct a chatRoom id for the two users
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    return _firestore
    .collection("chat_rooms")
    .doc(chatRoomID)
    .collection("messages")
    .orderBy("timestamp", descending: false)
    .snapshots();
  }



    // Report user
    Future<void> reportUser(String messageID, String userID) async {
      final currentUser = _auth.currentUser;
      final report = {
        'reportedBy': currentUser!.uid,
        'messageID': messageID,
        'messageOwnerID': userID,
        'timestamp': FieldValue.serverTimestamp()
      };
      await _firestore.collection('Reports').add(report);
    }


    // Block user
   Future<void> blockUser(String userID) async {
  final currentUser = _auth.currentUser;
  await _firestore
      .collection('Users')
      .doc(currentUser!.uid)
      .collection('BlockedUsers')
      .doc(userID)
      .set({
        'blockedAt': FieldValue.serverTimestamp(),
      });
}


    // unblock user
    Future<void> unblockUser(String blockedUserID) async{
      final currentUser = _auth.currentUser;
      await _firestore.collection('Users').doc(currentUser!.uid).collection('BlockedUsers').doc(blockedUserID).delete();
    }

    // get blocked user stream
    Stream<List<Map<String, dynamic>>> getBlockedUsersStream(String userID){
      return _firestore
      .collection('Users')
      .doc(userID)
      .collection('BlockedUsers')
      .snapshots()
      .asyncMap((snapshot) async {

        final blockedUserIDs = snapshot.docs.map((doc) => doc.id).toList();

        final userDocs = await Future.wait(
          blockedUserIDs.map((id) => _firestore.collection("Users").doc(id).get())
        );

        return userDocs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      });
    }

    

   
// periodic updates to check both collections

Stream<List<Map<String, dynamic>>> getRealTimeChatListUsers() {
  final currentUser = _auth.currentUser;
  
  return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
    try {
      // Get chat list users
      final chatListSnapshot = await _firestore
          .collection('Users')
          .doc(currentUser!.uid)
          .collection('ChatList')
          .get();
      
      if (chatListSnapshot.docs.isEmpty) return [];
      
      // Get blocked user IDs
      final blockedSnapshot = await _firestore
          .collection('Users')
          .doc(currentUser.uid)
          .collection('BlockedUsers')
          .get();
      
      final blockedUserIDs = blockedSnapshot.docs.map((doc) => doc.id).toList();
      
      // Get user IDs from chat list, excluding blocked users
      final chatListUserIDs = chatListSnapshot.docs
          .map((doc) => doc.id)
          .where((userID) => !blockedUserIDs.contains(userID))
          .toList();
      
      if (chatListUserIDs.isEmpty) return [];
      
      // Get user details for each non-blocked user in chat list
      final userDocs = await Future.wait(
        chatListUserIDs.map((userID) => 
          _firestore.collection('Users').doc(userID).get()
        )
      );
      
      // Filter out non-existent users and get their latest interaction
      List<Map<String, dynamic>> usersWithTimestamp = [];
      
      for (var doc in userDocs) {
        if (doc.exists) {
          final userData = doc.data()!;
          final latestMessageTimestamp = await _getLatestMessageTimestamp(
            currentUser.uid, 
            userData['uid']
          );
          
          usersWithTimestamp.add({
            ...userData,
            'latestInteraction': latestMessageTimestamp,
          });
        }
      }
      
      // Sort users by latest interaction (most recent first)
      usersWithTimestamp.sort((a, b) {
        Timestamp? timestampA = a['latestInteraction'];
        Timestamp? timestampB = b['latestInteraction'];
        
        if (timestampA != null && timestampB != null) {
          return timestampB.compareTo(timestampA);
        }
        if (timestampA != null) return -1;
        if (timestampB != null) return 1;
        return 0;
      });
      
      // Remove the latestInteraction field before returning
      return usersWithTimestamp.map((user) {
        user.remove('latestInteraction');
        return user;
      }).toList();
    } catch (e) {
      return <Map<String, dynamic>>[];
    }
  });
}


}