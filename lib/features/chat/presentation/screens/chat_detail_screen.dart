import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/broadcasting_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/services/chat_service.dart';
import '../../data/models/chat_model.dart';

class ChatDetailScreen extends StatefulWidget {
  final User user;
  final String currentUserId;
  const ChatDetailScreen({
    super.key,
    required this.user,
    required this.currentUserId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();
  final _broadcastingService = BroadcastingService();

  List<Chat> _chats = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _nextCursor;
  String? _privateChannelName;

  @override
  void initState() {
    super.initState();
    _initializeBroadcasting();
    _loadChats();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    if (_privateChannelName != null) {
      _broadcastingService.unsubscribe(_privateChannelName!);
    }
    super.dispose();
  }

  Future<void> _initializeBroadcasting() async {
    try {
      // Subscribe to the current user's private channel
      _privateChannelName = 'private-chat.user.${widget.currentUserId}';

      await _broadcastingService.subscribeToPrivateChannel(
        _privateChannelName!,
        _onBroadcastEvent,
      );
    } catch (e) {
      print('Broadcasting setup error: $e');
    }
  }

  void _onBroadcastEvent(PusherEvent event) {
    print('Received broadcast event: ${event.eventName}');

    try {
      final data = jsonDecode(event.data);

      if (event.eventName == 'message.sent') {
        _handleNewMessage(data);
      } else if (event.eventName == 'message.read') {
        _handleMessageRead(data);
      }
    } catch (e) {
      print('Error handling broadcast event: $e');
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    // Only add if message is from the other user in this conversation
    if (data['sender_id'] == widget.user.id) {
      final newChat = Chat.fromJson(data);

      setState(() {
        _chats.insert(0, newChat);
      });

      // Mark as read automatically since user is viewing the conversation
      _chatService.markAsRead(newChat.id);

      // Scroll to bottom to show new message
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    // Update the read status of the message in the list
    final chatId = data['id'];
    setState(() {
      final index = _chats.indexWhere((chat) => chat.id == chatId);
      if (index != -1) {
        _chats[index] = _chats[index].copyWith(
          isRead: data['is_read'],
          readAt: data['read_at'] != null
              ? DateTime.parse(data['read_at'])
              : null,
        );
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _nextCursor != null) {
        _loadMore();
      }
    }
  }

  Future<void> _loadChats() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _chatService.getChats(widget.user.id);

      setState(() {
        _chats = response.chats;
        _nextCursor = response.nextCursor;
        _isLoading = false;
      });

      // Mark messages as read
      _markMessagesAsRead();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _nextCursor == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _chatService.getChats(
        widget.user.id,
        cursor: _nextCursor,
      );

      setState(() {
        _chats.addAll(response.chats);
        _nextCursor = response.nextCursor;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _markMessagesAsRead() {
    // Mark unread messages from the other user as read
    for (final chat in _chats) {
      if (chat.receiver.id == widget.currentUserId && !chat.isRead) {
        _chatService.markAsRead(chat.id);
      }
    }
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty || _isSending) return;

    final messageText = _controller.text.trim();
    _controller.clear();

    setState(() {
      _isSending = true;
    });

    try {
      final chatId = await _chatService.sendMessage(
        widget.user.id,
        messageText,
      );

      if (chatId != null) {
        // Reload messages to get the new message with proper data
        await _loadChats();

        // Scroll to bottom
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  bool _isMyMessage(Chat chat) {
    return chat.sender.id == widget.currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepVoid,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Glass Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: widget.user.avatar != null
                        ? NetworkImage(widget.user.avatar!)
                        : null,
                    child: widget.user.avatar == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: AppColors.neonCyan, blurRadius: 10),
                            ],
                          ),
                        ),
                        if (_broadcastingService.isInitialized)
                          Text(
                            'Real-time',
                            style: TextStyle(
                              color: AppColors.neonCyan.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: _isLoading && _chats.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.neonCyan,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      reverse: true, // Show newest at bottom
                      itemCount: _chats.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _chats.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(
                                color: AppColors.neonCyan,
                              ),
                            ),
                          );
                        }

                        final chat = _chats[index];
                        final isMe = _isMyMessage(chat);

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              gradient: isMe ? AppColors.primaryGradient : null,
                              color: isMe
                                  ? null
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: isMe
                                    ? const Radius.circular(20)
                                    : Radius.zero,
                                bottomRight: isMe
                                    ? Radius.zero
                                    : const Radius.circular(20),
                              ),
                              border: isMe
                                  ? null
                                  : Border.all(
                                      color: AppColors.neonCyan.withOpacity(
                                        0.3,
                                      ),
                                    ),
                              boxShadow: isMe
                                  ? [
                                      BoxShadow(
                                        color: AppColors.neonPink.withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chat.message,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      chat.formattedCreatedAt ?? '',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        chat.isRead
                                            ? Icons.done_all
                                            : Icons.done,
                                        size: 16,
                                        color: chat.isRead
                                            ? AppColors.neonCyan
                                            : Colors.white.withOpacity(0.6),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Input Area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isSending
                            ? const LinearGradient(
                                colors: [Colors.grey, Colors.grey],
                              )
                            : AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonPink.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
