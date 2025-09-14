import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReadReceiptWidget extends StatelessWidget {
  final bool isRead;
  final Timestamp? readAt;

  const ReadReceiptWidget({
    Key? key,
    required this.isRead,
    this.readAt,
  }) : super(key: key);

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final readTime = timestamp.toDate();
    final difference = now.difference(readTime);

    if (difference.inMinutes < 1) {
      return "Seen just now";
    } else if (difference.inMinutes < 60) {
      return "Seen ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago";
    } else if (difference.inHours < 24) {
      return "Seen ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago";
    } else if (difference.inDays < 7) {
      return "Seen ${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago";
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return "Seen ${weeks} week${weeks == 1 ? '' : 's'} ago";
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return "Seen ${months} month${months == 1 ? '' : 's'} ago";
    } else {
      final years = (difference.inDays / 365).floor();
      return "Seen ${years} year${years == 1 ? '' : 's'} ago";
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Container(
      padding: const EdgeInsets.only(right: 45, bottom: 8, top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            isRead && readAt != null 
                ? _getTimeAgo(readAt!) 
                : "Delivered",
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.bold, 
            ),
          ),
        ],
      ),
    );
  }
}