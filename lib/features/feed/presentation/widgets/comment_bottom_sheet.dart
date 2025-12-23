import 'package:flutter/material.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/comment_model.dart';
import '../providers/feed_provider.dart';

class CommentBottomSheet extends ConsumerStatefulWidget {
  final String videoId;

  const CommentBottomSheet({super.key, required this.videoId});

  @override
  ConsumerState<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends ConsumerState<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Comment> _comments = [];
  String? _nextCursor;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreComments();
    }
  }

  Future<void> _loadComments() async {
    try {
      final response = await ref
          .read(videoServiceProvider)
          .getComments(widget.videoId);
      if (mounted) {
        setState(() {
          _comments = response.comments;
          _nextCursor = response.nextCursor;
          _hasMore = response.nextCursor != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await ref
          .read(videoServiceProvider)
          .getComments(widget.videoId, cursor: _nextCursor);

      if (mounted) {
        setState(() {
          _comments.addAll(response.comments);
          _nextCursor = response.nextCursor;
          _hasMore = response.nextCursor != null;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      final newComment = await ref
          .read(videoServiceProvider)
          .postComment(widget.videoId, _commentController.text);

      if (mounted) {
        setState(() {
          _comments.insert(0, newComment);
          _commentController.clear();
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _comments.isEmpty
                  ? "Comments"
                  : "${_comments.length} comments", // TODO: Use total count from API if available
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const Divider(color: Colors.grey, thickness: 0.5),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey[600],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No comments yet",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Be the first to comment!",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _comments.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _comments.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final comment = _comments[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                            comment.user.avatar ?? '',
                          ),
                          radius: 16,
                          backgroundColor: Colors.grey[800],
                        ),
                        title: Text(
                          comment.user.name,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              comment.formattedCreatedAt,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                comment.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              comment.isReactedByUser
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: comment.isReactedByUser
                                  ? AppColors.neonPink
                                  : Colors.grey[600],
                              size: 16,
                            ),
                            if (comment.reactionsCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                comment.reactionsCount.toString(),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Input
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
              left: 16,
              right: 16,
              top: 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Add comment...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.neonPink),
                  onPressed: _postComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
