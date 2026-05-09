import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/constants.dart';

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();

  factory AgoraService() {
    return _instance;
  }

  AgoraService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false;

  // callbacks
  Function(int uid, int elapsed)? onUserJoined;
  Function(int uid)? onUserOffline;
  Function(RtcConnection connection, int elapsed)? onJoinChannelSuccess;
  Function(ErrorCodeType err, String msg)? onError; // Existing
  Function(String message)? onLog; // Debug logger
  int? currentUid; // Expose current UID

  Future<void> requestPermissions() async {
    if (kIsWeb) {
      // On web, permissions are requested by the browser when the stream starts
      return;
    }
    await [Permission.microphone].request();
  }

  Future<void> initialize() async {
    if (onLog != null) onLog!("AgoraService: initialize() called");
    if (_isInitialized) return;

    if (onLog != null) {
      onLog!("AgoraService: Requesting microphone permission...");
    }
    await requestPermissions();
    if (onLog != null) onLog!("AgoraService: Permission request completed");

    if (AppConstants.agoraAppId == "YOUR_AGORA_APP_ID") {
      if (onLog != null) onLog!("AGORA ERROR: App ID missing");
      return;
    }

    try {
      if (onLog != null) onLog!("AgoraService: Creating RTC Engine...");
      _engine = createAgoraRtcEngine();

      if (onLog != null) {
        onLog!("AgoraService: Engine created. Initializing...");
      }
      await _engine!.initialize(
        RtcEngineContext(
          appId: AppConstants.agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      if (onLog != null) onLog!("AgoraService: Engine initialize() returned.");
    } catch (e) {
      if (onLog != null) onLog!("AgoraService: CRITICAL INIT ERROR: $e");
      return;
    }

    if (onLog != null) onLog!("AgoraService: Registering event handler...");
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          currentUid = connection.localUid; // Capture UID
          if (onLog != null) {
            onLog!(
              "✅ JOINED! Channel: ${connection.channelId}, UID: ${connection.localUid}",
            );
          }
          if (onJoinChannelSuccess != null) {
            onJoinChannelSuccess!(connection, elapsed);
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (onLog != null) onLog!("Agora Event: User $remoteUid Joined");
          if (onUserJoined != null) onUserJoined!(remoteUid, elapsed);
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              if (onLog != null) onLog!("Agora Event: User $remoteUid Offline");
              if (onUserOffline != null) onUserOffline!(remoteUid);
            },
        onError: (ErrorCodeType err, String msg) {
          if (onLog != null) onLog!("❌ ERROR: $err - $msg");
        },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              if (onLog != null) {
                onLog!("🔄 State: ${state.name}, Reason: ${reason.name}");
              }
            },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          if (onLog != null) onLog!("⚠️ Left channel unexpectedly!");
        },
        onRequestToken: (RtcConnection connection) {
          if (onLog != null) onLog!("🔑 Token requested - check App ID config");
        },
      ),
    );

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );
    // NOTE: Do NOT call enableAudio/enableLocalAudio here.
    // On web, getUserMedia requires HTTPS or localhost + user gesture.
    // These calls are deferred to joinChannel() which runs after user action.
    if (!kIsWeb) {
      await _engine!.enableAudio();
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(false);
    }

    _isInitialized = true;
    if (onLog != null) onLog!("AgoraService: Engine initialized successfully");
  }

  Future<void> joinChannel({
    required String channelId,
    required int uid,
  }) async {
    if (onLog != null) onLog!("AgoraService: Joining channel $channelId...");

    if (!_isInitialized) await initialize();

    try {
      // On web, enable audio here (after user gesture) to avoid getUserMedia block
      if (kIsWeb) {
        if (onLog != null) onLog!("AgoraService: Enabling audio (web)...");
        await _engine!.enableAudio();
        await _engine!.enableLocalAudio(true);
        await _engine!.muteLocalAudioStream(false);
      }

      await _engine!.joinChannel(
        token: '', // Use null for App ID only mode
        channelId: channelId,
        uid: uid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      if (onLog != null) {
        onLog!(
          "✅ joinChannel sent! App ID: ${AppConstants.agoraAppId.substring(0, 8)}...",
        );
      }

      // Ensure remote audio is not muted
      await _engine!.muteAllRemoteAudioStreams(false);

      // Give it a moment then check connection state
      await Future.delayed(const Duration(milliseconds: 500));
      if (onLog != null) onLog!("⏳ Waiting for Agora callback...");
    } catch (e) {
      if (onLog != null) onLog!("AGORA JOIN EXCEPTION: $e");
    }
  }

  Future<void> muteLocalAudio(bool mute) async {
    await _engine?.muteLocalAudioStream(mute);
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  Future<void> dispose() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    _isInitialized = false;
    currentUid = null;
  }
}
