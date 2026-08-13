import 'package:firebase_auth/firebase_auth.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

class AuthService {
  AuthService([this._firebaseAuth]);

  final FirebaseAuth? _firebaseAuth;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(messageForCode(error.code));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(messageForCode(error.code));
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(messageForCode(error.code));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(messageForCode(error.code));
    }
  }

  static String messageForCode(String code) {
    return switch (code) {
      'invalid-email' => 'البريد الإلكتروني غير صالح.',
      'user-not-found' => 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.',
      'wrong-password' ||
      'invalid-credential' => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'email-already-in-use' => 'يوجد حساب مسجل بهذا البريد الإلكتروني بالفعل.',
      'weak-password' => 'كلمة المرور ضعيفة. اختر كلمة مرور أقوى.',
      'too-many-requests' => 'تم إجراء محاولات كثيرة. حاول مرة أخرى لاحقاً.',
      'network-request-failed' =>
        'تعذر الاتصال بالشبكة. تحقق من اتصالك بالإنترنت.',
      'user-disabled' => 'تم تعطيل هذا الحساب.',
      'operation-not-allowed' =>
        'تسجيل الدخول بالبريد الإلكتروني غير متاح حالياً.',
      _ => 'تعذر إكمال العملية. حاول مرة أخرى.',
    };
  }
}
