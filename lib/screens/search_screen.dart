import 'package:chat_app/services/chat_service.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _chatService = MyChatService();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  // Keep track of users being added to prevent multiple taps
  Set<String> _usersBeingAdded = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchUsers() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _usersBeingAdded.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _usersBeingAdded.clear();
    });

    try {
      final results = await _chatService.searchUsersByEmail(query);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _addUserToChat(Map<String, dynamic> user) async {
    final userId = user['uid'];
    
    // Prevent multiple simultaneous additions
    if (_usersBeingAdded.contains(userId)) return;
    
    setState(() {
      _usersBeingAdded.add(userId);
    });

    try {
      await _chatService.addUserToChatList(user['uid'], user['email']);

      if (mounted) {
        setState(() {
          _usersBeingAdded.remove(userId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user['email']} added to your chat list'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _usersBeingAdded.remove(userId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add user to chat list'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching users...'),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search for users by email address',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with a different email',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final userId = user['uid'];
        final isBeingAdded = _usersBeingAdded.contains(userId);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: FutureBuilder<bool>(
            future: _chatService.isUserInChatList(userId),
            builder: (context, snapshot) {
              final isInChatList = snapshot.data ?? false;
              final isLoading = snapshot.connectionState == ConnectionState.waiting;

              // If user is being added, show loading state
              if (isBeingAdded) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      user['email'][0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    user['email'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Adding to chat list...',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    user['email'][0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  user['email'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  isLoading 
                      ? 'Checking status...'
                      : isInChatList 
                          ? 'Already in your chat list' 
                          : 'Tap to add to chat list',
                  style: TextStyle(
                    color: isLoading 
                        ? Colors.grey 
                        : isInChatList 
                            ? Colors.green 
                            : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                trailing: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isInChatList
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.add_circle_outline),
                onTap: (isLoading || isInChatList) 
                    ? null 
                    : () => _addUserToChat(user),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Enter email address...',
                  border: InputBorder.none,
                ),
                controller: _searchController,
                onSubmitted: (_) => _searchUsers(),
                textInputAction: TextInputAction.search,
              ),
            )
          ],
        ),
        actions: [
          IconButton(
            onPressed: _searchUsers,
            icon: const Icon(Icons.search_outlined),
          ),
        ],
      ),
      body: _buildSearchResults(),
    );
  }
}