const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();
const auth = getAuth();

const UID = 'KnqRSfs85hfhIxdHJfMwfT7ApNr2';
const EMAIL = 'sukru.kuzu1906@gmail.com';
const AD_SOYAD = 'Şükrü';
const SIRKET_ADI = 'Test Sanayi Servisi';

async function main() {
  const sirketRef = db.collection('companies').doc();

  await sirketRef.set({
    name: SIRKET_ADI,
    subscriptionStatus: 'active',
    createdAt: FieldValue.serverTimestamp(),
  });

  await auth.setCustomUserClaims(UID, {
    sirketId: sirketRef.id,
    rol: 'admin',
  });

  await sirketRef.collection('users').doc(UID).set({
    email: EMAIL,
    adSoyad: AD_SOYAD,
    rol: 'admin',
    aktif: true,
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log('Tamamlandı! sirketId:', sirketRef.id);
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
