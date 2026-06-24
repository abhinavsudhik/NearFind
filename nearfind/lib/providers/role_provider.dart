import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The four roles a user can assume in NearFind.
enum UserRole { customer, retailer, delivery, admin }

/// Holds the currently selected [UserRole] and the anonymous Firebase UID.
///
/// When [selectRole] is called the provider will:
///  1. Sign in anonymously (if not already signed in).
///  2. Store the UID and role.
///  3. Notify listeners so the UI can react.
class RoleProvider extends ChangeNotifier {
  UserRole? _role;
  String? _uid;
  bool _isLoading = false;

  UserRole? get role => _role;
  String? get uid => _uid;
  bool get isLoading => _isLoading;

  /// Sign in anonymously and persist the chosen role.
  Future<void> selectRole(UserRole role) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Re-use existing anonymous session if one exists.
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _uid = currentUser.uid;
      } else {
        final credential =
            await FirebaseAuth.instance.signInAnonymously();
        _uid = credential.user?.uid;
      }

      _role = role;
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset state (e.g. when the user returns to role selection).
  void clearRole() {
    _role = null;
    notifyListeners();
  }
}
