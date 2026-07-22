import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_role.dart';

/// Giriş yapan kullanıcının uygulama içi kimliği: Firebase Auth UID +
/// custom claim'lerden gelen sirketId ve rol.
class AppUser {
  final String uid;
  final String email;
  final String sirketId;
  final UserRole rol;

  AppUser({
    required this.uid,
    required this.email,
    required this.sirketId,
    required this.rol,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// PRD 3.3: Admin, yeni personeli e-posta+ad+şifre ile ekler.
  /// NOT: Bir başka kullanıcı hesabı client SDK ile oluşturmak mevcut
  /// oturumu değiştireceğinden, bu işlem gerçekte bir Cloud Function
  /// (Admin SDK, `createUser`) üzerinden yapılmalı. Aşağıdaki metod
  /// o Cloud Function'ı çağıran arayüzü temsil eder.
  Future<void> personelEkle({
    required String email,
    required String adSoyad,
    required String geciciSifre,
  }) async {
    // TODO: functions.httpsCallable('personelEkle').call({...})
    throw UnimplementedError(
      'Cloud Function bağlantısı Faz 1 tamamlanınca eklenecek.',
    );
  }

  /// Kullanıcının custom claim'lerinden (sirketId, rol) AppUser üretir.
  /// Custom claim'ler, kullanıcı oluşturulduğunda bir Cloud Function
  /// tarafından set edilir (bkz. 01_Yol_Haritasi.md, Faz 1).
  Future<AppUser?> currentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final idTokenResult = await user.getIdTokenResult(true);
    final claims = idTokenResult.claims ?? {};
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      sirketId: claims['sirketId'] ?? '',
      rol: UserRole.fromString(claims['rol'] ?? 'staff'),
    );
  }
}
