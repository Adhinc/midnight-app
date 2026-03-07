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
      print("AGORA ERROR: App ID is missing in constants.dart");
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
        const RtcEngineContext(
          appId: AppConstants.agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      if (onLog != null) onLog!("AgoraService: Engine initialize() returned.");
    } catch (e) {
      if (onLog != null) onLog!("AgoraService: CRITICAL INIT ERROR: $e");
      print("Agora Critical Error: $e");
      return;
    }

    print("AgoraService: Registering event handler...");
    if (onLog != null) onLog!("AgoraService: Registering event handler...");
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print(
            "✅ AGORA: local user ${connection.localUid} joined channel ${connection.channelId}",
          );
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
          print("Agora: remote user $remoteUid joined");
          if (onLog != null) onLog!("Agora Event: User $remoteUid Joined");
          if (onUserJoined != null) onUserJoined!(remoteUid, elapsed);
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              print("Agora: remote user $remoteUid left channel");
              if (onLog != null) onLog!("Agora Event: User $remoteUid Offline");
              if (onUserOffline != null) onUserOffline!(remoteUid);
            },
        onError: (ErrorCodeType err, String msg) {
          print("❌ AGORA ERROR CODE: $err, MSG: $msg");
          if (onLog != null) onLog!("❌ ERROR: $err - $msg");
        },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              print("🔄 Agora Connection State: $state, Reason: $reason");
              if (onLog != null) {
                onLog!("🔄 State: ${state.name}, Reason: ${reason.name}");
              }
            },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          print("⚠️ LEFT CHANNEL: ${connection.channelId}");
          if (onLog != null) onLog!("⚠️ Left channel unexpectedly!");
        },
        onRequestToken: (RtcConnection connection) {
          print("🔑 TOKEN REQUESTED");
          if (onLog != null) onLog!("🔑 Token requested - check App ID config");
        },
      ),
    );

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.enableAudio();

    _isInitialized = true;
    if (onLog != null) onLog!("AgoraService: Engine initialized successfully");
  }

  Future<void> joinChannel({
    required String channelId,
    required int uid,
  }) async {
    print("AgoraService: Attempting to join channel $channelId as $uid");
    if (onLog != null) onLog!("AgoraService: Joining channel $channelId...");

    if (!_isInitialized) await initialize();

    // For testing we use a null token (requires App Config to allow App ID only auth)
    // In production, you should use a token server
    try {
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

      // Skip preview for web - it's not supported -> Wait, let's TRY it to see if it triggers permissions
      // await _engine!.startPreview(); // DISABLED: We only want Audio, don't ask for Camera!

      print("✅ AgoraService: joinChannel command sent successfully");
      if (onLog != null) {
        onLog!(
          "✅ joinChannel sent! App ID: ${AppConstants.agoraAppId.substring(0, 8)}...",
        );
      }

      // Give it a moment then check connection state
      await Future.delayed(const Duration(milliseconds: 500));
      if (onLog != null) onLog!("⏳ Waiting for Agora callback...");
    } catch (e) {
      print("AGORA JOIN EXCEPTION: $e");
      if (onLog != null) onLog!("AGORA JOIN EXCEPTION: $e");
    }
  }

  Future<void> muteLocalAudio(bool mute) async {
    if (mute) {
      await _engine?.disableAudio();
    } else {
      await _engine?.enableAudio();
    }
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  Future<void> dispose() async {
    await _engine?.release();
    _isInitialized = false;
  }
}
