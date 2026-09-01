import 'package:flutter/material.dart';

class AiChatWidget extends StatefulWidget {
  final Future<String> Function(String instruction)? onRefinePlan;

  const AiChatWidget({super.key, this.onRefinePlan});

  @override
  State<AiChatWidget> createState() => _AiChatWidgetState();
}

class _AiChatWidgetState extends State<AiChatWidget> {
  final _controller = TextEditingController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      fromUser: false,
      text:
          'Tell me what you want to change. I can make the trip cheaper, calmer, more food-focused, or reduce travel time.',
    ),
  ];

  static const _quickActions = [
    'Make it cheaper',
    'Less walking',
    'More food',
    'Remove museums',
    'Relax schedule',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() => _messages.add(_ChatMessage(fromUser: true, text: text)));
    _controller.clear();
    final response =
        await widget.onRefinePlan?.call(text) ??
        'Generate a plan first, then ask me to refine it.';
    if (!mounted) return;
    setState(
      () => _messages.add(_ChatMessage(fromUser: false, text: response)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E8F0)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFEAF2FF),
                  foregroundColor: Color(0xFF2C7BE5),
                  child: Icon(Icons.auto_awesome_rounded),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Travel Planner',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Safe refinement • validation enabled',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7A8499)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: _messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.fromUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: message.fromUser
                          ? const Color(0xFF2C7BE5)
                          : const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.fromUser
                            ? Colors.white
                            : const Color(0xFF344054),
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, index) => ActionChip(
                label: Text(_quickActions[index]),
                onPressed: () async => _send(_quickActions[index]),
              ),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: _quickActions.length,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) async => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask AI to adjust your trip...',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: () async => _send(),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool fromUser;
  final String text;
  const _ChatMessage({required this.fromUser, required this.text});
}
