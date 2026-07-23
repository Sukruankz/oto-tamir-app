import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_role.dart';

/// Giriş yapan kullanıcının uygulama içi kimliği: Firebase Auth UID +
/// custom claim'lerden gelen sirketId ve rol.
class AppUser {
  final String uid;
  final String email;
  final String adSoyad;
  final String sirketId;
  final UserRole rol;
  // companies/{sirketId} dokümanının 'name' alanı — dashboard üstünde ve
  // Profil Düzenle ekranında gösterilir/düzenlenir (sadece Admin düzenleyebilir).
  final String firmaAdi;

  AppUser({
    required this.uid,
    required this.email,
    required this.adSoyad,
    required this.sirketId,
    required this.rol,
    this.firmaAdi = '',
  });

  /// Drawer/AppBar gibi yerlerde gösterilecek isim: adSoyad boşsa
  /// e-postanın @ öncesine düşer.
  String get gorunenAd => adSoyad.isNotEmpty ? adSoyad : email.split('@').first;

  /// Profil düzenleme sonrası, tekrar login olmadan ekranlardaki (AppBar,
  /// Drawer) ismi güncel tutmak için — yeni bir AppUser kopyası üretir.
  AppUser copyWith({String? adSoyad, String? firmaAdi}) {
    return AppUser(
      uid: uid,
      email: email,
      adSoyad: adSoyad ?? this.adSoyad,
      sirketId: sirketId,
      rol: rol,
      firmaAdi: firmaAdi ?? this.firmaAdi,
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// "Profili Düzenle": kullanıcının görünen adını
  /// companies/{sirketId}/users/{uid} dokümanında günceller.
  Future<void> profilGuncelle({
    required String sirketId,
    required String uid,
    required String yeniAdSoyad,
  }) async {
    await FirebaseFirestore.instance
        .collection('companies')
        .doc(sirketId)
        .collection('users')
        .doc(uid)
        .set({'adSoyad': yeniAdSoyad}, SetOptions(merge: true));
  }

  /// Firma adını (companies/{sirketId}.name) günceller — sadece Admin
  /// çağırabilir (bkz. firestore.rules: companies update adminMi).
  Future<void> firmaAdiGuncelle({
    required String sirketId,
    required String yeniFirmaAdi,
  }) async {
    await FirebaseFirestore.instance
        .collection('companies')
        .doc(sirketId)
        .set({'name': yeniFirmaAdi}, SetOptions(merge: true));
  }

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
    final sirketId = claims['sirketId'] ?? '';

    // adSoyad custom claim'de değil, companies/{sirketId}/users/{uid}
    // dokümanında tutuluyor (bkz. FirestoreService / personelEkle).
    // firmaAdi de companies/{sirketId} dokümanının 'name' alanından okunuyor.
    String adSoyad = '';
    String firmaAdi = '';
    if (sirketId.isNotEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(sirketId)
          .collection('users')
          .doc(user.uid)
          .get();
      adSoyad = (userDoc.data()?['adSoyad'] as String?) ?? '';

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(sirketId)
          .get();
      firmaAdi = (companyDoc.data()?['name'] as String?) ?? '';
    }

    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      adSoyad: adSoyad,
      sirketId: sirketId,
      rol: UserRole.fromString(claims['rol'] ?? 'staff'),
      firmaAdi: firmaAdi,
    );
  }
}
