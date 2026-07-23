import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class ChatBookingScreen extends StatefulWidget {
  final String? initialService;

  const ChatBookingScreen({Key? key, this.initialService}) : super(key: key);

  @override
  State<ChatBookingScreen> createState() => _ChatBookingScreenState();
}

class _ChatBookingScreenState extends State<ChatBookingScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final String _threadId = "thread-${DateTime.now().millisecondsSinceEpoch}";
  final AgentApiService _agentApi = AgentApiService();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        id: 'msg-welcome',
        sender: 'agent',
        text: widget.initialService != null
            ? "Hello! I would love to help you book a ${widget.initialService}. What day or time window works best for you?"
            : "Welcome to Luxe Aura Salon! I am your AI assistant. Tell me what service you'd like to book (e.g., haircut Saturday afternoon, facial tomorrow).",
        timestamp: DateTime.now(),
      ),
    );
  }

  void _sendMessage({String? messageText, String? selectedSlotId}) async {
    final text = messageText ?? _textController.text.trim();
    if (text.isEmpty && selectedSlotId == null) return;

    if (messageText == null) {
      _textController.clear();
    }

    setState(() {
      _messages.add(
        ChatMessage(
          id: 'user-${DateTime.now().millisecondsSinceEpoch}',
          sender: 'user',
          text: text,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });

    final response = await _agentApi.sendChatMessage(
      threadId: _threadId,
      customerId: 'cust-demo-1',
      message: text,
      selectedSlotId: selectedSlotId,
    );

    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _messages.add(
        ChatMessage(
          id: 'agent-${DateTime.now().millisecondsSinceEpoch}',
          sender: 'agent',
          text: response.message,
          timestamp: DateTime.now(),
          proposedSlots: response.proposedSlots,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('AI Booking Assistant'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.sender == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    maxConstraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                        bottomLeft: !isUser ? Radius.zero : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: isUser ? Colors.white : AppColors.lightTextPrimary,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                        if (msg.proposedSlots.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            "Tap a slot below to reserve:",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: msg.proposedSlots.map((slot) {
                              return ActionChip(
                                avatar: const Icon(Icons.access_time_filled_rounded, size: 14, color: AppColors.primary),
                                label: Text("${slot.date} @ ${slot.startTime.substring(0, 5)} (${slot.staffName})"),
                                backgroundColor: AppColors.primaryContainer,
                                side: const BorderSide(color: AppColors.primary),
                                onPressed: () {
                                  _sendMessage(
                                    messageText: "I'd like to book ${slot.date} at ${slot.startTime.substring(0, 5)}",
                                    selectedSlotId: slot.id,
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  SizedBox(width: 8),
                  Text("AI Agent is thinking...", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),

          // INPUT BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: "Type e.g., 'Haircut Saturday 2 PM'...",
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                  onPressed: () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
