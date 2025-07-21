import 'package:flutter/material.dart';
import '../../core/models/meeting_session.dart';

/// Widget for managing user comments
class CommentsWidget extends StatefulWidget {
  final List<Comment> comments;
  final Function(String, {String? segmentId})? onAddComment;
  final Function(String, String)? onEditComment;
  final Function(String)? onDeleteComment;

  const CommentsWidget({
    super.key,
    required this.comments,
    this.onAddComment,
    this.onEditComment,
    this.onDeleteComment,
  });

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  final TextEditingController _commentController = TextEditingController();
  String? _editingCommentId;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add comment section
        _buildAddCommentSection(),
        const Divider(),

        // Comments list
        Expanded(
          child: widget.comments.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: widget.comments.length,
                  itemBuilder: (context, index) {
                    final comment = widget.comments[index];
                    return _buildCommentCard(comment);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAddCommentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: null,
              onSubmitted: (_) => _addComment(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _addComment,
            icon: const Icon(Icons.send),
            tooltip: 'Add Comment',
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Comment comment) {
    final isEditing = _editingCommentId == comment.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comment header
            Row(
              children: [
                Icon(
                  comment.segmentId != null ? Icons.link : Icons.comment,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(comment.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                // Edit button
                IconButton(
                  onPressed: () => _startEditing(comment),
                  icon: const Icon(Icons.edit, size: 16),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  tooltip: 'Edit',
                ),
                const SizedBox(width: 4),
                // Delete button
                IconButton(
                  onPressed: () => _deleteComment(comment.id),
                  icon: const Icon(Icons.delete, size: 16),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Comment content
            if (isEditing) ...[
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
                maxLines: null,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancelEditing,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _saveEdit(comment.id),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              Text(comment.content),
              if (comment.segmentId != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Linked to segment',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _addComment() {
    final content = _commentController.text.trim();
    if (content.isNotEmpty && widget.onAddComment != null) {
      widget.onAddComment!(content);
      _commentController.clear();
    }
  }

  void _startEditing(Comment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _commentController.text = comment.content;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingCommentId = null;
      _commentController.clear();
    });
  }

  void _saveEdit(String commentId) {
    final newContent = _commentController.text.trim();
    if (newContent.isNotEmpty && widget.onEditComment != null) {
      widget.onEditComment!(commentId, newContent);
      _cancelEditing();
    }
  }

  void _deleteComment(String commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.onDeleteComment != null) {
                widget.onDeleteComment!(commentId);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
