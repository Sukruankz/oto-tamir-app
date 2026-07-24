const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });

const auth = getAuth();

// Bu bilgilerle giriş yapacaksın. İstersen değiştirebilirsin.
const EMAIL = 'superadmin@panimocar.com';
const SIFRE = 'SuperAdmin1234';
const AD_SOYAD = 'Süper Admin';

async function main() {
  const userRecord = await auth.createUser({
    email: EMAIL,
    password: SIFRE,
    displayName: AD_SOYAD,
  });

  // İKİ claim de gerekli: 'rol' uygulamanın hangi ekranı göstereceğine
  // karar verir, 'superadmin' ise firestore.rules'daki superAdminMi()
  // fonksiyonunun kontrol ettiği ayrı bir bayraktır.
  await auth.setCustomUserClaims(userRecord.uid, {
    rol: 'superadmin',
    superadmin: true,
  });

  console.log('Süper Admin oluşturuldu!');
  console.log('email:', EMAIL);
  console.log('şifre:', SIFRE);
  console.log('uid:', userRecord.uid);
  process.exit(0);
}

main().catch((e) => { console.error(e); process.exit(1); });
