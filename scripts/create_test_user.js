const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });

const db = getFirestore();
const auth = getAuth();

const EMAIL = 'usta.test@panimocar.com';
const SIFRE = 'Test1234';
const AD_SOYAD = 'Test Usta';
const SIRKET_ID = 'u8kxVLJeSzLO6BVzhz1c';
const ROL = 'usta'; // 'usta' veya 'cirak'

async function main() {
  const userRecord = await auth.createUser({
    email: EMAIL,
    password: SIFRE,
    displayName: AD_SOYAD,
  });

  await auth.setCustomUserClaims(userRecord.uid, {
    sirketId: SIRKET_ID,
    rol: ROL,
  });

  await db
    .collection('companies').doc(SIRKET_ID)
    .collection('users').doc(userRecord.uid)
    .set({
      email: EMAIL,
      adSoyad: AD_SOYAD,
      rol: ROL,
      aktif: true,
      createdAt: FieldValue.serverTimestamp(),
    });

  console.log('Oluşturuldu! uid:', userRecord.uid, 'rol:', ROL);
  process.exit(0);
}

main().catch((e) => { console.error(e); process.exit(1); });
