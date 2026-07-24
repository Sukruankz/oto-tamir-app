const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });

const UID = 'KnqRSfs85hfhIxdHJfMwfT7ApNr2';

getAuth().getUser(UID).then((user) => {
  console.log('sirketId:', user.customClaims?.sirketId);
  console.log('rol:', user.customClaims?.rol);
  process.exit(0);
}).catch((e) => { console.error(e); process.exit(1); });
