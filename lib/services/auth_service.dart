import 'package:firebase_auth/firebase_auth.dart';

import 'user_service.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

class RegisteredAuthUser {
  const RegisteredAuthUser({
    required this.uid,
    required this.email,
    required this.delete,
  });

  final String uid;
  final String? email;
  final Future<void> Function() delete;
}

typedef RegistrationUserCreator =
    Future<RegisteredAuthUser> Function({
      required String email,
      required String password,
    });

class AuthService {
  AuthService([
    this._firebaseAuth,
    this._userService,
    this._registrationUserCreator,
  ]);

  final FirebaseAuth? _firebaseAuth;
  final UserService? _userService;
  final RegistrationUserCreator? _registrationUserCreator;
  UserService? _defaultUserService;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;
  UserService get _users =>
      _userService ?? (_defaultUserService ??= UserService());

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    late final RegisteredAuthUser user;
    try {
      user = await (_registrationUserCreator ?? _createRegistrationUser)(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(messageForCode(error.code));
    }

    try {
      await _users.createStudentProfile(
        uid: user.uid,
        name: name,
        email: user.email ?? email,
      );
    } on UserProfileFailure {
      await _handleIncompleteRegistration(user);
    }
  }

  Future<RegisteredAuthUser> _createRegistrationUser({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const AuthFailure(
        'تم إنشاء حساب الدخول، لكن تعذر إكمال ملف الطالب.',
      );
    }
    return RegisteredAuthUser(
      uid: user.uid,
      email: user.email,
      delete: user.delete,
    );
  }

  // Compensating deletion is an implementation consistency decision, not an
  // SRS requirement. It stays isolated here and reports both outcomes safely.
  Future<Never> _handleIncompleteRegistration(RegisteredAuthUser user) async {
    try {
      await user.delete();
    } catch (_) {
      throw const AuthFailure(
        'تم إنشاء حساب الدخول، لكن تعذر حفظ ملف الطالب. '
        'لا تعِد التسجيل بنفس البريد وتواصل مع إدارة التطبيق.',
      );
    }

    throw const AuthFailure(
      'تعذر حفظ ملف الطالب، لذلك لم يكتمل إنشاء الحساب. حاول مرة أخرى.',
    );
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
