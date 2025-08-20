import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/user.dart';

enum SignInProvider { email, google, phone, anonymous }

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb 
      ? '48916413018-fu29vn4jmakkuuog9osc5t7gna3cv04j.apps.googleusercontent.com'
      : null,
  );
  
  // Stream controllers for user state
  static final StreamController<UserModel?> _userController = 
      StreamController<UserModel?>.broadcast();
  
  static UserModel? _currentUser;
  static StreamSubscription<User?>? _authSubscription;

  // Initialize the service - NO automatic anonymous sign-in
  static Future<void> initialize() async {
    // Listen to Firebase Auth state changes
    _authSubscription = _auth.authStateChanges().listen(_handleAuthStateChange);
    
    // Enable auth persistence
    await _auth.setPersistence(Persistence.LOCAL);
    
    // DON'T automatically sign in anonymously
    // Only create anonymous users when they actually complete payment
  }

  // Handle Firebase Auth state changes
  static Future<void> _handleAuthStateChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      _userController.add(null);
      return;
    }

    try {
      UserModel? userModel;

      if (firebaseUser.isAnonymous) {
        // Handle anonymous user
        userModel = UserModel.anonymous(
          id: firebaseUser.uid,
          createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        );
      } else {
        // Handle authenticated user - get from Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (userDoc.exists) {
          userModel = UserModel.fromFirestore(firebaseUser.uid, userDoc.data()!);
        } else {
          // Create user document if it doesn't exist
          userModel = UserModel.fromFirebaseUser(
            firebaseUser.uid,
            firebaseUser.displayName,
            firebaseUser.email,
            firebaseUser.isAnonymous,
          );
          await _createUserDocument(userModel);
        }
        
        // Update last sign-in time
        await _updateLastSignIn(firebaseUser.uid);
      }

      _currentUser = userModel;
      _userController.add(userModel);
      
    } catch (e) {
      print('Error handling auth state change: $e');
      _currentUser = null;
      _userController.add(null);
    }
  }

  // Create anonymous user after successful payment
  static Future<UserModel?> createAnonymousUserAfterPayment({
    required String guestEmail,
    required String guestName,
    String? guestPhone,
  }) async {
    try {
      final credential = await _auth.signInAnonymously();
      
      if (credential.user != null) {
        // Create user document with guest purchase info
        final userModel = UserModel(
          id: credential.user!.uid,
          name: guestName,
          email: guestEmail,
          phoneNumber: guestPhone,
          createdAt: DateTime.now(),
          isActive: true,
          isAdmin: false,
          userType: UserType.guest,
          isAnonymous: true,
          emailVerified: false,
        );
        
        await _createUserDocument(userModel);
        
        print('Created anonymous user after payment: ${credential.user!.uid}');
        return userModel;
      }
      return null;
    } catch (e) {
      print('Error creating anonymous user after payment: $e');
      throw Exception('Failed to create guest account: $e');
    }
  }

  // Sign in anonymously ONLY when needed (like adding to cart) - DEPRECATED
  // This method is kept for backward compatibility but not used in new flow
  static Future<UserModel?> signInAnonymouslyIfNeeded() async {
    if (_auth.currentUser != null) {
      return _currentUser; // Already signed in
    }
    
    try {
      final credential = await _auth.signInAnonymously();
      
      if (credential.user != null) {
        // The auth state listener will handle creating the UserModel
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Error signing in anonymously: $e');
      throw Exception('Failed to sign in as guest: $e');
    }
  }

  // Sign in with email and password
  static Future<UserModel?> signInWithEmailPassword(
    String email, 
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Wait for the user document and create/update UserModel immediately
        final user = credential.user!;
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        UserModel userModel;
        if (userDoc.exists) {
          userModel = UserModel.fromFirestore(user.uid, userDoc.data()!);
        } else {
          // Create user document if it doesn't exist
          userModel = UserModel.fromFirebaseUser(
            user.uid,
            user.displayName,
            user.email,
            user.isAnonymous,
          );
          await _createUserDocument(userModel);
        }
        
        // Update last sign-in time
        await _updateLastSignIn(user.uid);
        
        // Update the current user immediately
        _currentUser = userModel;
        _userController.add(userModel);
        
        return userModel;
      }
      return null;
    } catch (e) {
      print('Error signing in with email: $e');
      rethrow;
    }
  }

  // Sign in with Google using Firebase Auth popup
  static Future<UserModel?> signInWithGoogle() async {
    try {
      // Use Firebase Auth's Google provider directly for web
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      
      // Add any additional scopes if needed
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      // Check if current user is anonymous and link accounts
      final currentUser = _auth.currentUser;
      UserCredential userCredential;
      
      if (currentUser != null && currentUser.isAnonymous) {
        // Link anonymous account with Google
        userCredential = await currentUser.linkWithPopup(googleProvider);
      } else {
        // Sign in with Google using popup
        userCredential = await _auth.signInWithPopup(googleProvider);
      }

      if (userCredential.user != null) {
        // Create or update user document
        final user = userCredential.user!;
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        UserModel userModel;
        if (!userDoc.exists) {
          userModel = UserModel(
            id: user.uid,
            name: user.displayName ?? 'Google User',
            email: user.email ?? '',
            profileImageUrl: user.photoURL,
            createdAt: DateTime.now(),
            isActive: true,
            isAdmin: false,
            userType: UserType.buyer,
            isAnonymous: false,
            emailVerified: user.emailVerified,
          );
          
          await _createUserDocument(userModel);
        } else {
          userModel = UserModel.fromFirestore(user.uid, userDoc.data()!);
        }
        
        // Update last sign-in time
        await _updateLastSignIn(user.uid);
        
        // Update the current user immediately
        _currentUser = userModel;
        _userController.add(userModel);
        
        return userModel;
      }
      return null;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign in with phone number
  static Future<void> signInWithPhone(
    String phoneNumber,
    Function(String) onCodeSent,
    Function(String) onError,
    Function(UserModel?) onSignInComplete,
  ) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            if (userCredential.user != null) {
              await _handlePhoneSignInSuccess(userCredential.user!);
              onSignInComplete(_currentUser);
            }
          } catch (e) {
            onError('Auto-verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError('Phone verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timeout
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError('Phone sign-in error: $e');
    }
  }

  // Verify phone number with SMS code
  static Future<UserModel?> verifyPhoneCode(
    String verificationId,
    String smsCode,
  ) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Check if current user is anonymous and link accounts
      final currentUser = _auth.currentUser;
      UserCredential userCredential;
      
      if (currentUser != null && currentUser.isAnonymous) {
        // Link anonymous account with phone
        userCredential = await currentUser.linkWithCredential(credential);
      } else {
        // Sign in with phone
        userCredential = await _auth.signInWithCredential(credential);
      }

      if (userCredential.user != null) {
        // Handle phone sign-in success and update user state immediately
        final user = userCredential.user!;
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        UserModel userModel;
        if (!userDoc.exists) {
          userModel = UserModel(
            id: user.uid,
            name: 'Phone User',
            email: '',
            phoneNumber: user.phoneNumber,
            createdAt: DateTime.now(),
            isActive: true,
            isAdmin: false,
            userType: UserType.buyer,
            isAnonymous: false,
            emailVerified: false,
          );
          
          await _createUserDocument(userModel);
        } else {
          userModel = UserModel.fromFirestore(user.uid, userDoc.data()!);
        }
        
        // Update last sign-in time
        await _updateLastSignIn(user.uid);
        
        // Update the current user immediately
        _currentUser = userModel;
        _userController.add(userModel);
        
        return userModel;
      }
      return null;
    } catch (e) {
      print('Error verifying phone code: $e');
      rethrow;
    }
  }

  // Handle successful phone sign-in
  static Future<void> _handlePhoneSignInSuccess(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists) {
      final userModel = UserModel(
        id: user.uid,
        name: 'Phone User',
        email: '',
        phoneNumber: user.phoneNumber,
        createdAt: DateTime.now(),
        isActive: true,
        isAdmin: false,
        userType: UserType.buyer,
        isAnonymous: false,
        emailVerified: false,
      );
      
      await _createUserDocument(userModel);
    }
  }

  // Create account with email and password
  static Future<UserModel?> createAccountWithEmailPassword({
    required String email,
    required String password,
    required String name,
    UserType userType = UserType.buyer,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      final wasAnonymous = currentUser?.isAnonymous ?? false;
      
      UserCredential credential;
      
      if (wasAnonymous && currentUser != null) {
        // Link anonymous account to email/password
        final emailCredential = EmailAuthProvider.credential(
          email: email, 
          password: password,
        );
        credential = await currentUser.linkWithCredential(emailCredential);
      } else {
        // Create new account
        credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      
      if (credential.user != null) {
        // Create user document in Firestore
        final userModel = UserModel(
          id: credential.user!.uid,
          name: name,
          email: email,
          createdAt: DateTime.now(),
          isActive: true,
          isAdmin: false,
          userType: userType,
          isAnonymous: false,
          emailVerified: credential.user!.emailVerified,
        );
        
        await _createUserDocument(userModel);
        
        // Send email verification
        if (!credential.user!.emailVerified) {
          await credential.user!.sendEmailVerification();
        }
        
        return userModel;
      }
      return null;
    } catch (e) {
      print('Error creating account: $e');
      rethrow;
    }
  }

  // Convert anonymous user to authenticated user
  static Future<UserModel?> linkAnonymousAccount({
    required String email,
    required String password,
    required String name,
    UserType userType = UserType.buyer,
  }) async {
    final currentUser = _auth.currentUser;
    
    if (currentUser == null || !currentUser.isAnonymous) {
      throw Exception('No anonymous user to link');
    }

    try {
      // Create email credential
      final emailCredential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      
      // Link the credentials
      final credential = await currentUser.linkWithCredential(emailCredential);
      
      if (credential.user != null) {
        // Create user document
        final userModel = UserModel(
          id: credential.user!.uid,
          name: name,
          email: email,
          createdAt: DateTime.now(),
          isActive: true,
          isAdmin: false,
          userType: userType,
          isAnonymous: false,
          emailVerified: credential.user!.emailVerified,
        );
        
        await _createUserDocument(userModel);
        
        // Send email verification
        if (!credential.user!.emailVerified) {
          await credential.user!.sendEmailVerification();
        }
        
        return userModel;
      }
      return null;
    } catch (e) {
      print('Error linking anonymous account: $e');
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      // Sign out from Firebase (this handles Google sign-out automatically)
      await _auth.signOut();
      
      // DON'T automatically sign in anonymously after sign out
      // Let users browse without creating anonymous accounts
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Get current user
  static UserModel? get currentUser => _currentUser;

  // Get user stream
  static Stream<UserModel?> get userStream => _userController.stream;

  // Check if user is authenticated (not anonymous)
  static bool get isAuthenticated => 
      _currentUser != null && !_currentUser!.isAnonymous;

  // Check if user is admin
  static bool get isAdmin => _currentUser?.isAdmin ?? false;

  // Check if user is anonymous
  static bool get isAnonymous => _currentUser?.isAnonymous ?? false;

  // Check if user is signed in (including anonymous)
  static bool get isSignedIn => _currentUser != null;

  // Create user document in Firestore
  static Future<void> _createUserDocument(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toFirestore());
    } catch (e) {
      print('Error creating user document: $e');
      rethrow;
    }
  }

  // Update last sign-in time
  static Future<void> _updateLastSignIn(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastSignIn': DateTime.now(),
      });
    } catch (e) {
      print('Error updating last sign-in: $e');
      // Don't rethrow - this is not critical
    }
  }

  // Update user profile
  static Future<void> updateUserProfile({
    String? name,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    final user = _currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.id).update(updates);
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Set user as admin (would be called by Cloud Function or admin panel)
  static Future<void> setAdminStatus(String userId, bool isAdmin) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isAdmin': isAdmin,
        'userType': isAdmin ? 'admin' : 'buyer',
      });
    } catch (e) {
      print('Error setting admin status: $e');
      rethrow;
    }
  }

  // Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Reload user data from Firestore
  static Future<void> reloadUserData() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      await _handleAuthStateChange(firebaseUser);
    }
  }

  // Get available sign-in providers
  static List<SignInProvider> getAvailableProviders() {
    return [
      SignInProvider.email,
      SignInProvider.google,
      SignInProvider.phone,
      SignInProvider.anonymous,
    ];
  }

  // Dispose resources
  static void dispose() {
    _authSubscription?.cancel();
    _userController.close();
  }
}