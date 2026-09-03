import 'package:flutter/material.dart';

import '../../models/ai/trip_ai_command.dart';
import '../../service/ai/trip_ai_service.dart';

class AiChatWidget extends StatefulWidget {
  const AiChatWidget({
    super.key,
    required this.onPropose,
    required this.onApply,
    this.onUndo,
    this.canUndo,
    required this.liveAiEnabled,
  });

  final Future<TripAiProposal> Function(String instruction) onPropose;
  final Future<String> Function(TripAiCommand command) onApply;
  final Future<String> Function()? onUndo;
  final bool Function()? canUndo;
  final bool liveAiEnabled;

  @override
  State<AiChatWidget> createState() => _AiChatWidgetState();
}

class _AiChatWidgetState extends State<AiChatWidget> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      fromUser: false,
      text:
          'Tell me what you want to change. I will preview safe changes before applying them.',
    ),
  ];
  TripAiProposal? _pendingProposal;
  bool _busy = false;
  bool _canUndo = false;

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
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    if (_busy) return;
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(fromUser: true, text: text));
      _pendingProposal = null;
      _busy = true;
    });
    _controller.clear();
    _scrollToBottom();
    try {
      final proposal = await widget.onPropose(text);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(fromUser: false, text: proposal.summary));
        _pendingProposal = proposal.command.changesTrip ? proposal : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(
            fromUser: false,
            text: error is TripAiException
                ? error.message
                : 'I could not reach the AI service. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToBottom();
    }
  }

  Future<void> _apply() async {
    final proposal = _pendingProposal;
    if (proposal == null || _busy) return;
    setState(() => _busy = true);
    try {
      final response = await widget.onApply(proposal.command);
      if (!mounted) return;
      setState(() {
        _pendingProposal = null;
        _canUndo = widget.onUndo != null && (widget.canUndo?.call() ?? true);
        _messages.add(_ChatMessage(fromUser: false, text: response));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToBottom();
    }
  }

  Future<void> _undo() async {
    final onUndo = widget.onUndo;
    if (onUndo == null || !_canUndo || _busy) return;
    setState(() => _busy = true);
    try {
      final response = await onUndo();
      if (!mounted) return;
      setState(() {
        _canUndo = false;
        _pendingProposal = null;
        _messages.add(_ChatMessage(fromUser: false, text: response));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final undoAvailable = _canUndo && (widget.canUndo?.call() ?? true);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Travel Planner',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      widget.liveAiEnabled
                          ? 'Live AI • preview and validation enabled'
                          : 'Safe local commands • AI gateway not connected',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.liveAiEnabled
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
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
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.fromUser
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_pendingProposal != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _pendingProposal = null),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _apply,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Apply change'),
                    ),
                  ),
                ],
              ),
            ),
          if (_pendingProposal == null && undoAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _undo,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Undo AI change'),
                ),
              ),
            ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, index) => ActionChip(
                label: Text(_quickActions[index]),
                onPressed: _busy ? null : () => _send(_quickActions[index]),
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
                    enabled: !_busy,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask AI to adjust your trip...',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _busy ? null : _send,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
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
  const _ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}
