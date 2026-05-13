import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream controller to broadcast request IDs for navigation
  final _requestNavigationController = StreamController<String>.broadcast();
  Stream<String> get requestNavigationStream => _requestNavigationController.stream;

  Future<void> initialize() async {
    // 1. Request Permission from User
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted push notification permission');
      }
      
      // 2. Get the FCM token for this device
      try {
        String? token = await _fcm.getToken();
        if (token != null) {
          await _saveTokenToDatabase(token);
        }
      } catch (e) {
        if (kDebugMode) print('Error getting FCM token: $e');
      }

      // 3. Listen for token refreshes
      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);

      // 4. Handle Notification Clicks (Background -> Active)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      // 5. Handle Initial Notification (Terminated -> Active)
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }
    }
  }

  void _handleMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Handling notification click: ${message.data}');
    }
    final requestId = message.data['requestId'];
    if (requestId != null) {
      _requestNavigationController.add(requestId);
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).update({
          'fcmToken': token,
        });
        if (kDebugMode) {
          print('FCM Token successfully saved to user document');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to save FCM token: $e');
        }
      }
    }
  }

  void dispose() {
    _requestNavigationController.close();
  }
}
