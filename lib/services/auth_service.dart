import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Future<String?> signUpWithEmail(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return 'Sign-in cancelled.';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        return 'Google sign-in failed: missing ID token. Please make sure SHA-1 fingerprint is added in Firebase Console.';
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      await _auth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('10') || errStr.contains('DEVELOPER_ERROR')) {
        return 'Google sign-in configuration error: SHA-1 fingerprint needs to be added in Firebase Console.';
      }
      return 'Google sign-in failed: $e';
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    } catch (e) {
      return 'Failed to send password reset email: $e';
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered. Please click "Sign In" below to log in.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email/password or try again.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled in Firebase Console.';
      case 'API_NOT_CONNECTED':
        return 'Google Play services not available. Please update Google Play services.';
      case 'SIGN_IN_FAILED':
        return 'Google sign-in failed. Please try again.';
      case 'SIGN_IN_CANCELLED':
        return 'Sign-in cancelled.';
      case 'NETWORK_ERROR':
        return 'Network error. Please check your internet connection.';
      case 'DEVELOPER_ERROR':
        return 'Developer error: SHA-1 fingerprint missing in Firebase Console.';
      default:
        if (code.contains('10')) {
          return 'Configuration error: Please add SHA-1 fingerprint in Firebase Console and download updated google-services.json.';
        }
        return 'Authentication error: $code';
    }
  }
}
