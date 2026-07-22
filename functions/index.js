/**
 * Faz 1 — Cloud Functions iskeleti.
 * Bunlar client SDK ile YAPILAMAYACAK, mutlaka sunucu tarafında (Admin SDK
 * ile) çalışması gereken işlemlerdir:
 *   1) Kullanıcıya sirketId + rol custom claim atama
 *   2) Admin'in başka bir kullanıcı hesabı oluşturması (client SDK bunu
 *      yaparsa mevcut oturumu değiştirir — bu yüzden Admin SDK şart)
 *   3) Plaka mükerrer kontrolünü transaction içinde sunucu tarafında
 *      kesinleştirme (PRD 3.5)
 *
 * Kurulum: `firebase init functions` sonrası bu dosyayı functions/index.js
 * olarak kullanın, `npm install firebase-admin firebase-functions` çalıştırın.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

/**
 * PRD 3.3.1 — Admin, yeni personeli e-posta+ad+geçici şifre ile ekler.
 * Sadece çağıran kullanıcının custom claim'i rol=='admin' ise çalışır.
 */
exports.personelEkle = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.rol !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Sadece Admin rolündeki kullanıcılar personel ekleyebilir.'
    );
  }

  const sirketId = context.auth.token.sirketId;
  const { email, adSoyad, geciciSifre } = data;

  const userRecord = await auth.createUser({
    email,
    password: geciciSifre,
    displayName: adSoyad,
  });

  // Yeni personele custom claim ata: aynı şirket, rol=staff
  await auth.setCustomUserClaims(userRecord.uid, {
    sirketId,
    rol: 'staff',
  });

  await db
    .collection('companies')
    .doc(sirketId)
    .collection('users')
    .doc(userRecord.uid)
    .set({
      email,
      adSoyad,
      rol: 'staff',
      aktif: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  return { uid: userRecord.uid };
});

/**
 * SuperAdmin yeni bir şirket (kiracı) tanımladığında, o şirketin ilk
 * Admin kullanıcısını oluşturur ve custom claim atar.
 */
exports.sirketVeAdminOlustur = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.superadmin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Sadece SuperAdmin yeni şirket tanımlayabilir.'
    );
  }

  const { sirketAdi, adminEmail, adminSifre, adminAdSoyad } = data;

  const sirketRef = db.collection('companies').doc();
  await sirketRef.set({
    name: sirketAdi,
    subscriptionStatus: 'active',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const userRecord = await auth.createUser({
    email: adminEmail,
    password: adminSifre,
    displayName: adminAdSoyad,
  });

  await auth.setCustomUserClaims(userRecord.uid, {
    sirketId: sirketRef.id,
    rol: 'admin',
  });

  await sirketRef.collection('users').doc(userRecord.uid).set({
    email: adminEmail,
    adSoyad: adminAdSoyad,
    rol: 'admin',
    aktif: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { sirketId: sirketRef.id, uid: userRecord.uid };
});

/**
 * PRD 3.5 — Şirket bazlı mükerrer plaka kontrolü, transaction ile
 * sunucu tarafında kesinleştirilir (client tarafındaki ön kontrol
 * sadece UX içindir, race condition'a karşı garanti değildir).
 */
exports.aracEkle = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Giriş yapmalısınız.');
  }
  const sirketId = context.auth.token.sirketId;
  const plaka = String(data.plaka || '').toUpperCase().replace(/[^A-Z0-9]/g, '');

  const vehiclesRef = db.collection('companies').doc(sirketId).collection('vehicles');

  return db.runTransaction(async (tx) => {
    const existing = await tx.get(vehiclesRef.where('plaka', '==', plaka).limit(1));
    if (!existing.empty) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Bu plaka bu şirkette zaten kayıtlı.'
      );
    }
    const newRef = vehiclesRef.doc();
    tx.set(newRef, {
      sirketId,
      plaka,
      sahipAdSoyad: data.sahipAdSoyad,
      markaModel: data.markaModel,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { id: newRef.id };
  });
});
