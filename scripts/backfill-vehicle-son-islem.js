const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const SIRKET_ID = 'u8kxVLJeSzLO6BVzhz1c';

async function main() {
  const sirketRef = db.collection('companies').doc(SIRKET_ID);
  const vehiclesSnap = await sirketRef.collection('vehicles').get();

  let guncellenen = 0;
  let atlanilan = 0;

  for (const vehicleDoc of vehiclesSnap.docs) {
    const jobsSnap = await vehicleDoc.ref
      .collection('jobs')
      .orderBy('tarih', 'desc')
      .limit(1)
      .get();

    if (jobsSnap.empty) {
      atlanilan++;
      continue;
    }

    const sonIs = jobsSnap.docs[0].data();
    await vehicleDoc.ref.update({
      sonYapilanIs: sonIs.yapilanIs || '',
      sonIslemTarihi: sonIs.tarih,
    });
    guncellenen++;
    console.log(`Güncellendi: ${vehicleDoc.data().plaka || vehicleDoc.id} -> ${sonIs.yapilanIs}`);
  }

  console.log(`\nTamamlandı. Güncellenen araç: ${guncellenen}, işlemi olmayan (atlanan): ${atlanilan}`);
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
