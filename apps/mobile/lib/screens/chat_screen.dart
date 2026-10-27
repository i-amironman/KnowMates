import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../chat/e2e_crypto.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.auth,
    required this.threadId,
    required this.counterpartName,
  });

  final AuthController auth;
  final String threadId;
  final String counterpartName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _crypto = E2eCrypto();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatBubble>[];
  String? _theirPublicKey;
  String? _myUserId;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  ApiClient get _client => widget.auth.client;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final me = await _client.get('/v1/me');
    if (me.statusCode == 200) {
      _myUserId = (jsonDecode(me.body) as Map<String, dynamic>)['id'] as String?;
    }
    final pub = await _crypto.myPublicKeyBase64();
    await _client.put('/v1/chats/${widget.threadId}/key', body: {'publicKey': pub});
    final thread = await _client.get('/v1/chats/${widget.threadId}');
    if (thread.statusCode == 200) {
      final map = jsonDecode(thread.body) as Map<String, dynamic>;
      _theirPublicKey = map['theirPublicKey'] as String?;
    }
    await _fetchMessages(initial: true);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    if (_theirPublicKey == null || _theirPublicKey!.isEmpty) {
      final thread = await _client.get('/v1/chats/${widget.threadId}');
      if (thread.statusCode == 200) {
        final map = jsonDecode(thread.body) as Map<String, dynamic>;
        _theirPublicKey = map['theirPublicKey'] as String?;
      }
    }
    if (_theirPublicKey == null || _theirPublicKey!.isEmpty) {
      return;
    }
    final resp = await _client.get('/v1/chats/${widget.threadId}/messages');
    if (resp.statusCode != 200) {
      return;
    }
    final list = (jsonDecode(resp.body) as Map<String, dynamic>)['messages'] as List;
    final decoded = <_ChatBubble>[];
    for (final raw in list) {
      final m = raw as Map<String, dynamic>;
      final id = m['id'] as String;
      final senderId = m['senderId'] as String;
      try {
        final text = await _crypto.decrypt(
          ciphertextBase64: m['ciphertext'] as String,
          nonceBase64: m['nonce'] as String,
          theirPublicKeyBase64: _theirPublicKey!,
        );
        decoded.add(_ChatBubble(id: id, mine: senderId == _myUserId, text: text));
      } catch (_) {
        decoded.add(_ChatBubble(id: id, mine: senderId == _myUserId, text: '🔒 Encrypted message'));
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _messages
        ..clear()
        ..addAll(decoded);
    });
    if (initial && _scroll.hasClients) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _theirPublicKey == null || _theirPublicKey!.isEmpty) {
      setState(() => _error = 'Waiting for your partner to open secure chat.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final sealed = await _crypto.encrypt(text, _theirPublicKey!);
    final resp = await _client.post(
      '/v1/chats/${widget.threadId}/messages',
      body: {'ciphertext': sealed.ciphertext, 'nonce': sealed.nonce},
    );
    if (!mounted) {
      return;
    }
    if (resp.statusCode == 201) {
      _input.clear();
      await _fetchMessages();
    } else {
      _error = apiErrorMessage(resp) ?? 'Could not send.';
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.counterpartName, style: const TextStyle(fontSize: 17)),
            const Text(
              'End-to-end encrypted',
              style: TextStyle(color: AppColors.online, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.magenta))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      return Align(
                        alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                          decoration: BoxDecoration(
                            color: m.mine ? AppColors.magenta.withValues(alpha: 0.35) : AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Text(m.text, style: const TextStyle(color: AppColors.text)),
                        ),
                      );
                    },
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: AppColors.pink)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      style: const TextStyle(color: AppColors.text),
                      decoration: appInputDecoration(label: 'Message', hint: 'Type securely…'),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text),
                          )
                        : const Icon(Icons.lock_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble {
  _ChatBubble({required this.id, required this.mine, required this.text});

  final String id;
  final bool mine;
  final String text;
}
