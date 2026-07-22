# OtoTamir SaaS — Flutter + Firebase İskeleti

Bu klasör, `01_Yol_Haritasi.md`'deki Faz 2-3'ün başlangıç kodudur. Flutter SDK bu ortamda kurulu olmadığı için `flutter pub get` / `flutter run` çalıştırılmadı — kendi makinenizde şu adımları izleyin.

## Kurulum

```bash
# 1. Flutter kurulu değilse: https://docs.flutter.dev/get-started/install
flutter doctor

# 2. Bağımlılıkları indir
cd oto_tamir_app
flutter pub get

# 3. Firebase CLI + FlutterFire CLI kur (bir kere)
npm install -g firebase-tools
dart pub global activate flutterfire_cli

# 4. Firebase projesini bağla (Firebase Console'da proje oluşturduktan sonra)
firebase login
flutterfire configure
# Bu komut lib/firebase_options.dart dosyasını otomatik üretir ve
# main.dart'taki yorum satırındaki import'u aktif etmeniz gerekir.

# 5. Cloud Functions'ı deploy et
cd functions && npm install firebase-admin firebase-functions && cd ..
firebase deploy --only functions,firestore:rules,firestore:indexes

# 6. Çalıştır
flutter run
```

## Klasör Yapısı

```
lib/
  models/       Vehicle, Expense, UserRole — PRD 4.1-4.2 veri modeli
  services/     AuthService, FirestoreService — Firebase erişim katmanı
  screens/      Login, Dashboard, Vehicle Detail, Admin Panel
  widgets/      FinanceCard, SupportBubbleOverlay (sağ alt sabit destek balonu)
  theme/        Renk paleti ve Material tema
functions/       Cloud Functions: personel ekleme, şirket oluşturma, plaka mükerrer kontrolü
firestore.rules  Multi-tenant izolasyon kuralları (PRD 3.5)
```

## Henüz Yapılmadı (bir sonraki adımlar)

- `firebase_options.dart` — `flutterfire configure` ile otomatik üretilecek, elle yazılmaz.
- SuperAdmin paneli (şirket/abonelik yönetimi) — Cloud Function tarafı (`sirketVeAdminOlustur`) hazır, ekran yok.
- Canlı destek sohbeti — şu an placeholder; Firestore tabanlı mesajlaşma veya Crisp/Intercom entegrasyonu gerekiyor.
- Widget testleri ve Firestore Security Rules testleri.
- App/Play Store görselleri, ikon, splash screen.

Detaylı faz planı için bkz. `01_Yol_Haritasi.md`.
