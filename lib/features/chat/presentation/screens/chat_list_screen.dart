import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/conversation_model.dart';
import '../../data/services/chat_service.dart';
import 'chat_detail_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neon_border_container.dart';

final chatServiceProvider = Provider((ref) => ChatService());

// State for paginated conversations
class ConversationsState {
  final List<Conversation> conversations;
  final String? nextCursor;
  final bool isLoading;

  ConversationsState({
    required this.conversations,
    this.nextCursor,
    required this.isLoading,
  });

  factory ConversationsState.initial() {
    return ConversationsState(
      conversations: [],
      nextCursor: null,
      isLoading: false,
    );
  }

  // Allow loading on first load (empty list) OR if there's a next cursor
  bool get hasMore => conversations.isEmpty || nextCursor != null;

  ConversationsState copyWith({
    List<Conversation>? conversations,
    String? nextCursor,
    bool? isLoading,
    bool clearCursor = false,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ChatService _chatService;

  ConversationsNotifier(this._chatService)
    : super(ConversationsState.initial());

  Future<void> loadConversations() async {
    if (state.isLoading || !state.hasMore) {
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final response = await _chatService.getConversations(
        cursor: state.nextCursor,
      );

      state = state.copyWith(
        conversations: [...state.conversations, ...response.conversations],
        nextCursor: response.nextCursor,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = ConversationsState.initial();
    await loadConversations();
  }
}

final conversationsProvider =
    StateNotifierProvider.autoDispose<
      ConversationsNotifier,
      ConversationsState
    >((ref) {
      final chatService = ref.watch(chatServiceProvider);
      return ConversationsNotifier(chatService);
    });

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    // Trigger initial load after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationsProvider.notifier).loadConversations();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(conversationsProvider.notifier).loadConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationsState = ref.watch(conversationsProvider);
    final conversations = conversationsState.conversations;

    return Scaffold(
      backgroundColor: AppColors.deepVoid,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Text(
                    "INBOX",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(color: AppColors.neonPink, blurRadius: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Conversations list
            Expanded(
              child: conversationsState.isLoading && conversations.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.neonCyan,
                      ),
                    )
                  : conversations.isEmpty
                  ? const Center(
                      child: Text(
                        "No conversations yet",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.neonCyan,
                      onRefresh: () =>
                          ref.read(conversationsProvider.notifier).refresh(),
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount:
                            conversations.length +
                            (conversationsState.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= conversations.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(
                                  color: AppColors.neonCyan,
                                ),
                              ),
                            );
                          }

                          final conversation = conversations[index];
                          return _buildConversationItem(context, conversation);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationItem(
    BuildContext context,
    Conversation conversation,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: NeonBorderContainer(
        borderWidth: 1,
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: () async {
            // Get current user from auth provider
            final currentUser = ref.read(authControllerProvider).value;
            if (currentUser == null) return;

            if (conversation.user != null) {
              // Navigate and refresh when returning
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(
                    user: conversation.user!,
                    currentUserId: currentUser.id,
                  ),
                ),
              );
              // Refresh conversations after returning from chat
              ref.read(conversationsProvider.notifier).refresh();
            }
          },
          leading: CircleAvatar(
            backgroundImage:
                conversation.user?.avatar != null &&
                    conversation.user!.avatar!.isNotEmpty
                ? NetworkImage(conversation.user!.avatar!)
                : null,
            child:
                conversation.user?.avatar == null ||
                    conversation.user!.avatar!.isEmpty
                ? Icon(Icons.person, color: Colors.white.withValues(alpha: 0.7))
                : null,
          ),
          title: Text(
            conversation.user?.name ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            conversation.lastMessage ?? 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                conversation.formattedTime,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              if (conversation.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${conversation.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ), // Close ListTile
      ), // Close NeonBorderContainer
    ); // Close Padding
  }
}
