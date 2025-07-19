import 'package:flutter/material.dart';
import '../../core/models/meeting_session.dart';

/// Widget for managing user comments on meeting sessions
/// Provides CRUD operations for comments with segment linking support
class CommentsSection extends StatefulWidget {
  final MeetingSession? session;

  const CommentsSection({
    super.key,
    this.session,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _selectedSegmentId;
  Comment? _editingComment;
  bool _isGlobalComment = true;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  /// Add a new comment
  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;

    final newComment = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: _commentController.text.trim(),
      timestamp: DateTime.now(),
      segmentId: _isGlobalComment ? null : _selectedSegmentId,
      isGlobal: _isGlobalComment,
    );

    // TODO: Add comment to session via state management
    print('Adding comment: ${newComment.content}');

    _clearCommentForm();
  }

  /// Edit an existing comment
  void _editComment(Comment comment) {
    setState(() {
      _editingComment = comment;
      _commentController.text = comment.content;
      _isGlobalComment = comment.isGlobal;
      _selectedSegmentId = comment.segmentId;
    });
    _commentFocusNode.requestFocus();
  }

  /// Save edited comment
  void _saveEditedComment() {
    if (_editingComment == null || _commentController.text.trim().isEmpty)
      return;

    final updatedComment = _editingComment!.copyWith(
      content: _commentController.text.trim(),
      segmentId: _isGlobalComment ? null : _selectedSegmentId,
      isGlobal: _isGlobalComment,
    );

    // TODO: Update comment in session via state management
    print('Updating comment: ${updatedComment.content}');

    _clearCommentForm();
  }

  /// Delete a comment
  void _deleteComment(Comment comment) {
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
              // TODO: Delete comment from session via state management
              print('Deleting comment: ${comment.id}');
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Clear the comment form
  void _clearCommentForm() {
    setState(() {
      _commentController.clear();
      _editingComment = null;
      _isGlobalComment = true;
      _selectedSegmentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session == null) {
      return _buildEmptyState(context);
    }

    final session = widget.session!;
    final comments = session.comments;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure we have bounded height constraints
        final hasHeightConstraints = constraints.maxHeight != double.infinity;

        if (!hasHeightConstraints) {
          // If no height constraints, provide a reasonable default height
          return SizedBox(
            height: 400, // Provide a default height
            child: _buildCommentLayout(context, session, comments),
          );
        }

        return _buildCommentLayout(context, session, comments);
      },
    );
  }

  /// Build the main comment layout
  Widget _buildCommentLayout(
      BuildContext context, MeetingSession session, List<Comment> comments) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasHeightConstraints = constraints.maxHeight != double.infinity;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Ultra compact
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.comment,
                    color: Theme.of(context).colorScheme.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Comments',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '${comments.length} comment${comments.length != 1 ? 's' : ''}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),

            // Comment input form - Fixed height
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: _buildCommentForm(context, session),
            ),

            // Comments list - Use Flexible when no height constraints, Expanded when bounded
            if (hasHeightConstraints)
              Expanded(
                child: _buildCommentsListContainer(context, session, comments),
              )
            else
              Flexible(
                child: _buildCommentsListContainer(context, session, comments),
              ),
          ],
        );
      },
    );
  }

  /// Build the comments list container
  Widget _buildCommentsListContainer(
      BuildContext context, MeetingSession session, List<Comment> comments) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: comments.isEmpty
              ? _buildNoCommentsState(context)
              : Builder(
                  builder: (context) {
                    // Sort comments once, outside the ListView.builder
                    final sortedComments = List<Comment>.from(comments)
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      shrinkWrap: constraints.maxHeight <
                          200, // Use shrinkWrap for small spaces
                      itemCount: sortedComments.length,
                      itemBuilder: (context, index) {
                        final comment = sortedComments[index];
                        final linkedSegment = comment.segmentId != null
                            ? session.segments
                                .where((s) => s.id == comment.segmentId)
                                .firstOrNull
                            : null;

                        return _buildCommentCard(
                            context, comment, linkedSegment);
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  /// Build empty state when no session
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.comment_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Session Available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a meeting to add comments',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  /// Build state when no comments exist
  Widget _buildNoCommentsState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust sizes based on available space
        final isVeryCompact = constraints.maxHeight < 120;
        final isCompact = constraints.maxHeight < 150;

        if (isVeryCompact) {
          // Ultra compact version for very small spaces
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 24,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 4),
                Text(
                  'No Comments Yet',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'Add comment above',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 8,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: isCompact ? 32 : 48,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: isCompact ? 6 : 16),
              Text(
                'No Comments Yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: isCompact ? 12 : null,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isCompact ? 3 : 8),
              Text(
                'Add your first comment above',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                      fontSize: isCompact ? 10 : null,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build comment input form
  Widget _buildCommentForm(BuildContext context, MeetingSession session) {
    return Container(
      height: 32, // Fixed height for the entire form
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Comment text field - takes most space
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              decoration: InputDecoration(
                hintText: _editingComment != null
                    ? 'Edit comment...'
                    : 'Add comment...',
                hintStyle: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                isDense: true,
              ),
              maxLines: 1,
              style: const TextStyle(fontSize: 10),
              onSubmitted: (_) => _editingComment != null
                  ? _saveEditedComment()
                  : _addComment(),
            ),
          ),

          // Action button - compact
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(left: 2),
            child: _editingComment != null
                ? IconButton(
                    onPressed: _saveEditedComment,
                    icon: const Icon(Icons.save, size: 12),
                    tooltip: 'Save',
                    padding: EdgeInsets.zero,
                  )
                : IconButton(
                    onPressed: _addComment,
                    icon: const Icon(Icons.add, size: 12),
                    tooltip: 'Add',
                    padding: EdgeInsets.zero,
                  ),
          ),

          // Cancel button when editing
          if (_editingComment != null)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(left: 1),
              child: IconButton(
                onPressed: _clearCommentForm,
                icon: const Icon(Icons.clear, size: 12),
                tooltip: 'Cancel',
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }

  /// Build a single comment card widget
  Widget _buildCommentCard(
      BuildContext context, Comment comment, SummarySegment? linkedSegment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Comment header - ultra compact
              SizedBox(
                height: 16,
                child: Row(
                  children: [
                    // Comment type indicator - micro
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: comment.isGlobal
                            ? Colors.blue.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        comment.isGlobal ? 'GEN' : 'SEG',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: comment.isGlobal
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Timestamp - micro
                    Text(
                      _formatTimestamp(comment.timestamp),
                      style: const TextStyle(fontSize: 7, color: Colors.grey),
                    ),

                    // Actions - micro
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 10,
                        onSelected: (action) {
                          switch (action) {
                            case 'edit':
                              _editComment(comment);
                              break;
                            case 'delete':
                              _deleteComment(comment);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 10),
                                SizedBox(width: 3),
                                Text('Edit', style: TextStyle(fontSize: 9)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 10),
                                SizedBox(width: 3),
                                Text('Delete', style: TextStyle(fontSize: 9)),
                              ],
                            ),
                          ),
                        ],
                        child: const Icon(Icons.more_vert, size: 10),
                      ),
                    ),
                  ],
                ),
              ),

              // Linked segment info - micro compact
              if (linkedSegment != null) ...[
                const SizedBox(height: 1),
                Container(
                  height: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(3),
                    border:
                        Border.all(color: Colors.green.shade200, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 8, color: Colors.green.shade700),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          linkedSegment.timeRange,
                          style: TextStyle(
                            fontSize: 7,
                            color: Colors.green.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 2),

              // Comment content - compact with overflow protection
              Text(
                comment.content,
                style: const TextStyle(fontSize: 9),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format timestamp for display
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
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
