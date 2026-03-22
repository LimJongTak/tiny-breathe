import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class GuestbookScreen extends ConsumerStatefulWidget {
  final AppUser owner;
  final bool isOwner; // viewing your own guestbook

  const GuestbookScreen({
    super.key,
    required this.owner,
    required this.isOwner,
  });

  @override
  ConsumerState<GuestbookScreen> createState() =>
      _GuestbookScreenState();
}

class _GuestbookScreenState extends ConsumerState<GuestbookScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _error = false;
  bool _sending = false;

  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final msgs =
          await FirestoreService.getGuestbookMessages(widget.owner.uid);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final me = ref.read(authProvider);
    if (me == null) return;

    setState(() => _sending = true);
    try {
      await FirestoreService.addGuestbookMessage(
        ownerUid: widget.owner.uid,
        fromUid: me.uid,
        fromNickname: me.nickname ?? me.displayName,
        message: text,
      );
      _ctrl.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메시지 전송 실패')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String msgId) async {
    try {
      await FirestoreService.deleteGuestbookMessage(
          widget.owner.uid, msgId);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider);
    final ownerName =
        widget.owner.nickname ?? widget.owner.displayName;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$ownerName의 방명록',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            Text('메시지 ${_messages.length}개',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.greenAccent))
          : _error
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white38, size: 48),
                      const SizedBox(height: 12),
                      const Text('불러오기 실패',
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white),
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _messages.isEmpty
                          ? const Center(
                              child: Text(
                                '아직 방명록이 비었어요 ✏️\n첫 번째 메시지를 남겨보세요!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white38,
                                    height: 1.6),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (_, i) {
                                final msg = _messages[i];
                                final canDelete =
                                    widget.isOwner ||
                                        msg['fromUid'] == me?.uid;
                                return _MessageCard(
                                  msg: msg,
                                  canDelete: canDelete,
                                  onDelete: canDelete
                                      ? () => _delete(
                                          msg['id'] as String)
                                      : null,
                                );
                              },
                            ),
                    ),

                    // Input bar (not shown on own guestbook)
                    if (!widget.isOwner)
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          MediaQuery.of(context).viewInsets.bottom +
                              16,
                        ),
                        color: const Color(0xFF1A2E1A),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              style: const TextStyle(
                                  color: Colors.white),
                              maxLength: 80,
                              maxLines: 1,
                              decoration: InputDecoration(
                                counterStyle: const TextStyle(
                                    color: Colors.white38),
                                hintText: '메시지를 남겨보세요 (최대 80자)',
                                hintStyle: const TextStyle(
                                    color: Colors.white38),
                                filled: true,
                                fillColor:
                                    const Color(0xFF0D1B0D),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _sending ? null : _send,
                            icon: _sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.greenAccent,
                                        strokeWidth: 2))
                                : const Icon(Icons.send_rounded,
                                    color: Colors.greenAccent),
                          ),
                        ]),
                      ),
                  ],
                ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool canDelete;
  final VoidCallback? onDelete;

  const _MessageCard({
    required this.msg,
    required this.canDelete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nick = msg['fromNickname'] as String? ?? '익명';
    final text = msg['message'] as String? ?? '';
    final ts = msg['createdAt'];
    String timeStr = '';
    if (ts is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      timeStr =
          '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('@$nick',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            if (timeStr.isNotEmpty)
              Text(timeStr,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10)),
            if (canDelete) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.close_rounded,
                    color: Colors.white38, size: 16),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}
