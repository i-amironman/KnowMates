import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.auth, required this.sessionId});

  final AuthController auth;
  final String sessionId;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _ChatLine {
  _ChatLine({required this.from, required this.body, this.id, this.createdAt});

  final String from;
  final String body;
  final String? id;
  final String? createdAt;
}

class _CallScreenState extends State<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _chatCtrl = TextEditingController();

  WebSocket? _ws;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _cameraStream;
  RTCRtpSender? _videoSender;
  String? _myId;
  bool _isTeacher = false;
  String _backupUrl = '';
  bool _peerJoined = false;
  bool _offerStarted = false;

  bool _permissionDenied = false;
  bool _callClosed = false;
  bool _hasRemoteVideo = false;
  bool _micMuted = false;
  bool _cameraOff = false;
  bool _sharing = false;
  bool _chatOpen = false;
  final List<_ChatLine> _chat = [];

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (!mounted) {
      return;
    }

    try {
      _cameraStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      _localStream = _cameraStream;
      _localRenderer.srcObject = _localStream;
    } catch (_) {
      if (mounted) {
        setState(() => _permissionDenied = true);
      }
      return;
    }

    final meResp = await widget.auth.client.get('/v1/me');
    if (meResp.statusCode != 200) {
      _showClosed();
      return;
    }
    final me = jsonDecode(meResp.body) as Map<String, dynamic>;
    _myId = me['id'] as String?;

    final sessResp = await widget.auth.client.get('/v1/sessions');
    if (sessResp.statusCode != 200) {
      _showClosed();
      return;
    }
    final sessions = (jsonDecode(sessResp.body) as Map<String, dynamic>)['sessions'] as List?;
    Map<String, dynamic>? row;
    if (sessions != null) {
      for (final raw in sessions) {
        final m = raw as Map<String, dynamic>;
        if (m['id'] == widget.sessionId) {
          row = m;
          break;
        }
      }
    }
    if (row == null) {
      _showClosed();
      return;
    }
    _isTeacher = row['teacherId'] == _myId;
    _backupUrl = row['meetingUrl'] as String? ?? '';

    final ticketResp =
        await widget.auth.client.post('/v1/sessions/${widget.sessionId}/call/ticket');
    if (ticketResp.statusCode != 200) {
      _showClosed();
      return;
    }
    final ticket = jsonDecode(ticketResp.body) as Map<String, dynamic>;

    final token = widget.auth.accessToken;
    if (token == null || token.isEmpty) {
      _showClosed();
      return;
    }

    try {
      final wsUri = _callWsUri(widget.auth.client.baseUrl, widget.sessionId);
      _ws = await WebSocket.connect(
        wsUri.toString(),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {
      _showClosed();
      return;
    }

    _ws!.listen(_onWsFrame, onError: (_) => _showClosed(), onDone: () {
      if (!_callClosed && mounted) {
        _showClosed();
      }
    });

    await _startPeer(ticket);
    if (mounted) {
      setState(() {});
    }
  }

  Uri _callWsUri(String baseUrl, String sessionId) {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(scheme: scheme, path: '/v1/sessions/$sessionId/call', query: null);
  }

  Future<void> _startPeer(Map<String, dynamic> ticket) async {
    final stun = (ticket['stun'] as List?)?.cast<String>() ?? const [];
    final turn = (ticket['turn'] as List?)?.cast<String>() ?? const [];
    final username = ticket['username'] as String? ?? '';
    final password = ticket['password'] as String? ?? '';

    final servers = <Map<String, dynamic>>[
      for (final u in stun) {'urls': u},
    ];
    if (turn.isNotEmpty) {
      servers.add({'urls': turn, 'username': username, 'credential': password});
    }

    _pc = await createPeerConnection({
      'iceServers': servers,
      'iceTransportPolicy': 'all',
    });

    _pc!.onIceCandidate = (c) {
      if (c.candidate == null || c.candidate!.isEmpty) {
        return;
      }
      _sendSignal({'type': 'ice', ...c.toMap()});
    };

    _pc!.onTrack = (event) {
      if (event.streams.isEmpty) {
        return;
      }
      _remoteRenderer.srcObject = event.streams.first;
      if (mounted) {
        setState(() => _hasRemoteVideo = true);
      }
    };

    final stream = _localStream!;
    for (final track in stream.getTracks()) {
      final sender = await _pc!.addTrack(track, stream);
      if (track.kind == 'video') {
        _videoSender = sender;
        await _setVideoBitrate(500000);
      }
    }
  }

  Future<void> _setVideoBitrate(int max) async {
    final sender = _videoSender;
    if (sender == null) {
      return;
    }
    final params = sender.parameters;
    final encodings = params.encodings;
    if (encodings != null && encodings.isNotEmpty) {
      encodings[0].maxBitrate = max;
      await sender.setParameters(params);
    }
  }

  void _onWsFrame(dynamic raw) {
    Map<String, dynamic> frame;
    try {
      frame = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = frame['type'] as String?;
    if (type == 'history') {
      final msgs = frame['messages'] as List? ?? const [];
      for (final m in msgs) {
        final map = m as Map<String, dynamic>;
        _chat.add(_ChatLine(
          from: map['from']?.toString() ?? '',
          body: map['body'] as String? ?? '',
          id: map['id']?.toString(),
          createdAt: map['createdAt']?.toString(),
        ));
      }
      if (mounted) {
        setState(() {});
      }
    } else if (type == 'chat') {
      _chat.add(_ChatLine(
        from: frame['from']?.toString() ?? '',
        body: frame['body'] as String? ?? '',
        id: frame['id']?.toString(),
        createdAt: frame['createdAt']?.toString(),
      ));
      if (mounted) {
        setState(() {});
      }
    } else if (type == 'peer') {
      final from = frame['from'] as String?;
      final joined = frame['joined'] == true;
      if (from != null && from != _myId && joined) {
        _peerJoined = true;
        unawaited(_maybeOffer());
      }
    } else if (type == 'offer') {
      unawaited(_handleOffer(frame['sdp'] as String?));
    } else if (type == 'answer') {
      unawaited(_handleAnswer(frame['sdp'] as String?));
    } else if (type == 'ice') {
      unawaited(_handleIce(frame));
    } else if (type == 'hangup') {
      if (mounted) {
        context.pop();
      }
    } else if (type == 'error' && frame['error'] == 'call_closed') {
      _showClosed();
    }
  }

  Future<void> _maybeOffer() async {
    if (!_isTeacher || !_peerJoined || _offerStarted || _pc == null) {
      return;
    }
    _offerStarted = true;
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _sendSignal({'type': 'offer', 'sdp': offer.sdp});
  }

  Future<void> _handleOffer(String? sdp) async {
    if (_pc == null || sdp == null || _isTeacher) {
      return;
    }
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _sendSignal({'type': 'answer', 'sdp': answer.sdp});
  }

  Future<void> _handleAnswer(String? sdp) async {
    if (_pc == null || sdp == null) {
      return;
    }
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> _handleIce(Map<String, dynamic> frame) async {
    if (_pc == null) {
      return;
    }
    final candidate = frame['candidate'] as String?;
    if (candidate == null || candidate.isEmpty) {
      return;
    }
    await _pc!.addCandidate(
      RTCIceCandidate(
        candidate,
        frame['sdpMid'] as String?,
        frame['sdpMLineIndex'] as int?,
      ),
    );
  }

  void _sendSignal(Map<String, dynamic> frame) {
    final socket = _ws;
    if (socket == null) {
      return;
    }
    socket.add(jsonEncode(frame));
  }

  void _showClosed() {
    if (!mounted) {
      return;
    }
    setState(() => _callClosed = true);
  }

  Future<void> _toggleMute() async {
    final audioTracks = _localStream?.getAudioTracks() ?? const [];
    final track = audioTracks.isEmpty ? null : audioTracks.first;
    if (track == null) {
      return;
    }
    _micMuted = !_micMuted;
    track.enabled = !_micMuted;
    setState(() {});
  }

  Future<void> _toggleCamera() async {
    final videoTracks = _localStream?.getVideoTracks() ?? const [];
    final track = videoTracks.isEmpty ? null : videoTracks.first;
    if (track == null) {
      return;
    }
    _cameraOff = !_cameraOff;
    track.enabled = !_cameraOff;
    setState(() {});
  }

  Future<void> _toggleShare() async {
    if (_sharing) {
      await _stopShare();
      return;
    }
    try {
      final screen = await navigator.mediaDevices.getDisplayMedia({'video': true});
      final screenV = screen.getVideoTracks();
      final cameraV = _cameraStream?.getVideoTracks() ?? const [];
      final screenTrack = screenV.isEmpty ? null : screenV.first;
      final cameraTrack = cameraV.isEmpty ? null : cameraV.first;
      if (screenTrack == null || _videoSender == null || cameraTrack == null) {
        return;
      }
      await _videoSender!.replaceTrack(screenTrack);
      _localStream = screen;
      _localRenderer.srcObject = screen;
      await _setVideoBitrate(800000);
      _sendSignal({'type': 'share', 'on': true});
      _sharing = true;
      setState(() {});
    } catch (_) {
      // User cancelled screen picker.
    }
  }

  Future<void> _stopShare() async {
    final cameraV = _cameraStream?.getVideoTracks() ?? const [];
    final cameraTrack = cameraV.isEmpty ? null : cameraV.first;
    if (cameraTrack == null || _videoSender == null) {
      return;
    }
    await _videoSender!.replaceTrack(cameraTrack);
    _localStream = _cameraStream;
    _localRenderer.srcObject = _cameraStream;
    await _setVideoBitrate(500000);
    _sendSignal({'type': 'share', 'on': false});
    _sharing = false;
    setState(() {});
  }

  void _sendChat() {
    final body = _chatCtrl.text.trim();
    if (body.isEmpty || body.length > 500) {
      return;
    }
    _sendSignal({'type': 'chat', 'body': body});
    _chatCtrl.clear();
  }

  Future<void> _hangUp() async {
    _sendSignal({'type': 'hangup'});
    await _teardown();
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _teardown() async {
    await _ws?.close();
    _ws = null;
    await _pc?.close();
    _pc = null;
    await _localStream?.dispose();
    await _cameraStream?.dispose();
    _localStream = null;
    _cameraStream = null;
  }

  Future<void> _openBackup() async {
    if (_backupUrl.isEmpty) {
      return;
    }
    final uri = Uri.parse(_backupUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    unawaited(_teardown());
    _chatCtrl.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'KnowMates needs the camera and microphone for this session.',
                style: TextStyle(color: AppColors.text),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.magenta),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_callClosed) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This session is not open for a call.',
                style: TextStyle(color: AppColors.text),
              ),
              if (_backupUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: _openBackup, child: const Text('Open backup link')),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.magenta),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_hasRemoteVideo)
            RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
          else
            const Center(
              child: Text('Waiting for your mate.', style: TextStyle(color: AppColors.muted)),
            ),
          Positioned(
            left: 12,
            bottom: 100,
            child: SizedBox(
              width: 96,
              height: 144,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RTCVideoView(_localRenderer, mirror: true),
              ),
            ),
          ),
          if (_chatOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 72,
              top: 80,
              child: Material(
                color: AppColors.card.withValues(alpha: 0.95),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _chat.length,
                        itemBuilder: (context, i) {
                          final line = _chat[i];
                          final mine = line.from == _myId;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: mine ? AppColors.magenta : AppColors.cardEdge,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(line.body, style: const TextStyle(color: AppColors.text)),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatCtrl,
                              style: const TextStyle(color: AppColors.text),
                              maxLength: 500,
                              decoration: const InputDecoration(hintText: 'Message'),
                              onSubmitted: (_) => _sendChat(),
                            ),
                          ),
                          IconButton(
                            onPressed: _sendChat,
                            icon: const Icon(Icons.send, color: AppColors.magenta),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _toggleMute,
                    icon: Icon(_micMuted ? Icons.mic_off : Icons.mic, color: AppColors.text),
                  ),
                  IconButton(
                    onPressed: _toggleCamera,
                    icon: Icon(
                      _cameraOff ? Icons.videocam_off : Icons.videocam,
                      color: AppColors.text,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleShare,
                    icon: Icon(
                      _sharing ? Icons.stop_screen_share : Icons.screen_share,
                      color: AppColors.text,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _chatOpen = !_chatOpen),
                    icon: const Icon(Icons.chat, color: AppColors.text),
                  ),
                  IconButton(
                    onPressed: _hangUp,
                    icon: const Icon(Icons.call_end, color: AppColors.pink),
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
