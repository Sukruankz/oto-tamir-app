const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const SIRKET_ID = 'u8kxVLJeSzLO6BVzhz1c';

function ayBaslangicTarihi() {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), 1);
}

function ayId() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

async function main() {
  const ayBaslangic = Timestamp.fromDate(ayBaslangicTarihi());
  const sirketRef = db.collection('companies').doc(SIRKET_ID);

  const expensesSnap = await sirketRef.collection('expenses').get();
  let toplamGider = 0;
  expensesSnap.forEach((doc) => {
    const data = doc.data();
    if (data.tarih && data.tarih.toMillis() >= ayBaslangic.toMillis()) {
      toplamGider += Number(data.tutar || 0);
    }
  });

  const vehiclesSnap = await sirketRef.collection('vehicles').get();
  let toplamGelir = 0;
  for (const vehicleDoc of vehiclesSnap.docs) {
    const jobsSnap = await vehicleDoc.ref.collection('jobs').get();
    jobsSnap.forEach((jobDoc) => {
      const data = jobDoc.data();
      if (data.tarih && data.tarih.toMillis() >= ayBaslangic.toMillis()) {
        toplamGelir += Number(data.ucret || 0);
      }
    });
  }

  await sirketRef.collection('summary').doc(ayId()).set({
    toplamGelir,
    toplamGider,
  });

  console.log(`Tamamlandı. Ay: ${ayId()} — Toplam Gelir: ${toplamGelir} TL, Toplam Gider: ${toplamGider} TL`);
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
