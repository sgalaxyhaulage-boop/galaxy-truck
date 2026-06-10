import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:galaxy_truck/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class AuthService extends ChangeNotifier {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  fb.User? _firebaseUser;
  Stream<fb.User?>? _authStream;
  late final StreamSubscription<fb.User?> _authSub;

  User? get currentUser => _currentUser;
  fb.User? get firebaseUser => _firebaseUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isDriver => _currentUser?.role == UserRole.driver;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _firestore.collection('users').doc(uid);

  Future<void> initialize() async {
    try {
      _authStream ??= _auth.authStateChanges();
      _authSub = _authStream!.listen((u) async {
        _firebaseUser = u;
        if (u == null) {
          _currentUser = null;
          notifyListeners();
          return;
        }

        try {
          _currentUser = await _loadUserProfile(u.uid);
        } catch (e) {
          debugPrint('Failed to load user profile: $e');
          _currentUser = null;
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Failed to initialize Firebase auth: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // auth state listener will populate _currentUser.
      return true;
    } catch (e) {
      debugPrint('Login failed: $e');
      return false;
    }
  }

  /// Reloads the logged-in user's Firestore profile from `users/{uid}`.
  /// Returns the assigned role, or null if the user doc or role is missing.
  Future<UserRole?> refreshCurrentUserFromFirestore() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      final profile = await _loadUserProfile(uid);
      _currentUser = profile;
      notifyListeners();
      return profile?.role;
    } catch (e) {
      debugPrint('Failed to refresh user profile: $e');
      return null;
    }
  }

  Future<bool> register(String email, String fullName, String password, UserRole role, {String? phoneNumber}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final fbUser = cred.user;
      if (fbUser == null) return false;

      final now = DateTime.now();
      final profile = User(
        id: fbUser.uid,
        email: email,
        fullName: fullName,
        role: role,
        phoneNumber: phoneNumber,
        createdAt: now,
        updatedAt: now,
      );
      await _userDoc(fbUser.uid).set(profile.toJson());
      _firebaseUser = fbUser;
      _currentUser = profile;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Registration failed: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
  }

  Future<List<User>> getAllUsers() async {
    try {
      final snap = await _firestore.collection('users').limit(500).get();
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        return User.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Failed to get users: $e');
      return [];
    }
  }

  Future<User?> getUserById(String userId) async {
    try {
      final doc = await _userDoc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      data['id'] ??= doc.id;
      return User.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<void> setUserRole({required String userId, required UserRole role}) async {
    try {
      await _userDoc(userId).set(
        {
          'role': role.name,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Failed to set user role: $e');
      rethrow;
    }
  }

  Future<User?> _loadUserProfile(String uid) async {
    final doc = await _userDoc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    data['id'] ??= doc.id;
    return User.fromJson(data);
  }

  @override
  void dispose() {
    try {
      _authSub.cancel();
    } catch (_) {}
    super.dispose();
  }
}
