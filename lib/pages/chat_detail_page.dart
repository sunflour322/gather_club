import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../auth_service/auth_provider.dart';

class ChatDetailPage extends StatefulWidget {
  final Chat chat;

  const ChatDetailPage({super.key, required this.chat});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  ChatMessage? _replyTo;
  bool _isLoading = true;
  bool _isTyping = false;
  late final ChatService _chatService;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _chatService =
        ChatService(Provider.of<AuthProvider>(context, listen: false));
    _loadMessages();
    _initWebSocket();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = await authProvider.getUserId();
  }

  Future<void> _initWebSocket() async {
    try {
      await _chatService.connectToWebSocket();
      await _chatService.subscribeToChat(
        widget.chat.chatId,
        onMessage: _handleMessageReceived,
        onTyping: _handleTyping,
        onRead: _handleRead,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подключения к чату: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatService.unsubscribeFromChat(widget.chat.chatId);
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getChatMessages(widget.chat.chatId);
      if (mounted) {
        setState(() {
          _messages.addAll(messages.reversed);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки сообщений: $e')),
        );
      }
    }
  }

  void _handleMessageReceived(ChatMessage message) {
    if (mounted) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    }
  }

  void _handleTyping(int userId) {
    if (userId != _currentUserId && mounted) {
      setState(() {
        _isTyping = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
          });
        }
      });
    }
  }

  void _handleRead(int userId) {
    if (userId != _currentUserId && mounted) {
      setState(() {
        for (var message in _messages) {
          if (message.senderId == _currentUserId && message.readAt == null) {
            message = ChatMessage(
              messageId: message.messageId,
              chatId: message.chatId,
              senderId: message.senderId,
              senderName: message.senderName,
              senderAvatar: message.senderAvatar,
              content: message.content,
              sentAt: message.sentAt,
              readAt: DateTime.now(),
              isSystem: message.isSystem,
              replyToId: message.replyToId,
            );
          }
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await _chatService.sendMessage(
        widget.chat.chatId,
        _messageController.text,
        replyToId: _replyTo?.messageId,
      );
      _messageController.clear();
      setState(() {
        _replyTo = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки сообщения: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeParticipants =
        widget.chat.participants.where((p) => p.leftAt == null).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chat.name),
            Text(
              '${activeParticipants.length} участников',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isCurrentUser = message.senderId == _currentUserId;
                      final showAvatar =
                          !isCurrentUser && message.senderAvatar != null;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: isCurrentUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isCurrentUser && showAvatar)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundImage:
                                      NetworkImage(message.senderAvatar!),
                                ),
                              ),
                            if (!isCurrentUser && !showAvatar)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey[300],
                                  child: Text(
                                    message.senderName[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: isCurrentUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (!isCurrentUser)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          message.senderName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      message.content,
                                      style: TextStyle(
                                        color: isCurrentUser
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      _formatTime(message.sentAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isCurrentUser
                                            ? Colors.white.withOpacity(0.7)
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Печатает...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_replyTo != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ответ на: ${_replyTo!.content}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) =>
                        _chatService.notifyTyping(widget.chat.chatId),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'вчера';
    } else {
      return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}';
    }
  }
}
