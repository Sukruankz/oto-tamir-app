# OtoTamir SaaS Panel — Devam Dokümanı

Bu dosya, projeyi hiç bilmeyen birinin (veya başka bir Claude oturumunun) sıfırdan devam edebilmesi için yazıldı. Eksiksiz oku, sonra kod değiştirmeye başla.

## 1. Proje nedir

Oto tamir dükkanları için çok kiracılı (multi-tenant) B2B SaaS mobil panel. Her dükkan (şirket) kendi araç/işlem/gider verisini görür, dükkanlar birbirinin verisini göremez. Flutter (mobil) + Firebase (backend) ile yazılıyor.

Ana akış: Dükkan sahibi (admin) veya ustası (staff) giriş yapar → plaka arar veya yeni araç ekler → araca "işlem" (yapılan iş + ücret) girer → dashboard'da günlük/aylık gelir-gider-ciro özetini görür → admin panelinden geçmiş işlemleri/giderleri aylık gruplanmış şekilde düzenleyebilir.

## 2. Erişim bilgileri

- Firebase proje ID: `oto-tamir-9d062`
- GitHub repo: `https://github.com/Sukruankz/oto-tamir-app.git`
- Yerel proje klasörü (kullanıcının Mac'inde): `~/dev/oto_tamir_app`
- Test şirket ID (script'lerde hardcoded): `u8kxVLJeSzLO6BVzhz1c`

Bu dosyayı okuyan kişi/Claude, kodu **kullanıcının kendi bilgisayarındaki** `~/dev/oto_tamir_app` klasöründen çalıştırmalı. Değişiklikler oraya yapılmalı, sonra git ile push edilmeli.

## 3. Teknoloji yığını

`pubspec.yaml`'daki bağımlılıklar:

- `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`
- `flutter_riverpod` (state management — şu an çok az kullanılıyor, çoğu ekran hala `StatefulWidget` + `setState`)
- `go_router` (routing — `main.dart`'ta auth state'e göre yönlendirme)
- `intl` (tarih formatlama)

Backend tamamen Firebase: Auth (email/şifre), Firestore (veritabanı), Cloud Functions (henüz deploy edilmedi, sadece kod yazıldı — bkz. bölüm 7), Storage (kullanılmıyor henüz).

## 4. Mimari — Multi-tenant tasarım

### 4.1 Veri yapısı (Firestore)

companies/{sirketId}
  name, subscriptionStatus, createdAt
  users/{uid}            → email, adSoyad, rol (admin/staff), aktif
  vehicles/{vehicleId}   → plaka, sahipAdSoyad, markaModel, sonYapilanIs, sonIslemTarihi
    jobs/{jobId}         → yapilanIs, ucret, tarih, girenKullaniciId, sirketId (denormalize), plaka (denormalize), vehicleId (client-side doldurulur)
  expenses/{expenseId}   → aciklama, tutar, tarih, sirketId
  summary/{yyyy-MM}      → toplamGelir, toplamGider (FieldValue.increment ile güncellenir, aggregate query yerine)

### 4.2 Yetkilendirme (RBAC)

lib/models/user_role.dart — üç rol: superAdmin, admin, staff.

- staff: sadece işlem/araç girer, net kâr/ciro göremez, admin paneline giremez.
- admin: her şeyi görür + admin paneli (işlem/gider düzenleme, aylık gruplanmış Gelir & Gider sekmesi).
- superAdmin: şirket oluşturma yetkisi (Cloud Function sirketVeAdminOlustur hazır ama panel ekranı YOK).

Firebase Auth custom claims ile taşınıyor: {sirketId: "...", rol: "admin"}. Bu claim'ler client SDK ile ATANAMAZ — sadece Cloud Functions (Admin SDK) ile atanabilir. Şu an sadece 1 test kullanıcı/şirket manuel olarak (Firebase Console'dan) kurulmuş durumda; personelEkle fonksiyonu deploy edilmediği için yeni personel/şirket eklemenin gerçek bir yolu yok.

### 4.3 Firestore Security Rules — ONEMLI DERS

firestore.rules, ayniSirket(sirketId) gibi path-bound helper fonksiyonlarla, kullanıcının custom claim'indeki sirketId'nin path'teki {sirketId} ile eşleştiğini kontrol ediyor. Bu güvenilir çalışıyor.

Denenip TERK EDİLEN yaklaşım: Tüm araçların işlemlerini tek sorguda çekmek için collectionGroup('jobs') kullanmayı denedik. Bu, dokümantasyonda önerilen resource.data.sirketId == request.auth.token.sirketId kuralıyla bile, kurallar doğru deploy olduğu ve cache temizlendiği (full flutter run restart) doğrulanmasına rağmen ısrarla permission-denied verdi. Kök neden tam netleşmedi ama collectionGroup sorgusu bu projede güvenilir çalışmadı.

Çözüm: collectionGroup tamamen terk edildi. FirestoreService.tumIslemlerGetir(sirketId) şu an önce vehicles koleksiyonunu çekiyor, sonra her aracın jobs alt koleksiyonunu ayrı ayrı okuyup client-side birleştiriyor/sıralıyor. Bu yavaş ölçeklenir (araç sayısı arttıkça N+1 okuma) ama küçük/orta ölçekte çalışıyor ve güvenlik kuralı basit kalıyor.

Eğer ileride collectionGroup tekrar denenirse: dikkatli ol, aynı permission-denied sorununa tekrar düşebilirsin. Önce küçük bir izole test projesinde doğrulamadan production'da denemeyin.

### 4.4 Tema — ONEMLI DERS (Material3 pink tint)

ColorScheme.fromSeed(seedColor: kırmızı) sadece surface/Card rengini değil, surfaceContainer, surfaceContainerLow/High/Highest gibi tonal rolleri de otomatik pembe/kırmızıya çekiyor. Bu roller ExpansionTile, AlertDialog gibi widget'larda kullanılıyor — sadece cardTheme.color set etmek yetmiyor.

Çözüm lib/theme/app_theme.dart'ta: ColorScheme.fromSeed(...) çağrısında TÜM surfaceContainer* rollerini elle beyaz/gri'ye override et, surfaceTint: Colors.transparent ekle, ayrıca expansionTileTheme ve dialogTheme'i de elle beyaz yap. Yeni bir widget'ta beklenmedik pembe/kırmızı görürsen muhtemelen aynı sorun — o widget'ın kendi *Theme override'ını eklemen gerekir.

## 5. Dosya haritası

lib/
  main.dart                          — go_router + authStateChanges yönlendirmesi
  models/
    vehicle.dart                     — Vehicle, VehicleJob modelleri
    expense.dart                     — Expense modeli
    user_role.dart                   — UserRole enum + RBAC yardımcı getter'ları
  services/
    auth_service.dart                — AppUser modeli, signIn/signOut, profilGuncelle
    firestore_service.dart           — TÜM Firestore okuma/yazma mantığı (bkz. bölüm 5.1)
  screens/
    auth/login_screen.dart           — basit email/şifre giriş formu
    dashboard/dashboard_screen.dart  — ana ekran: plaka arama, yeni araç, gelir/gider/ciro kartları, hızlı gider ekle, son işlem gören araçlar
    vehicles/vehicle_detail_screen.dart — araç kimlik kartı + işlem geçmişi + yeni işlem/işlem düzenleme
    admin/admin_panel_screen.dart    — 3 sekme: Eleman Ekle (UI var, backend'e bağlı değil), Plaka Düzeltme, Gelir & Gider (aylık gruplanmış, düzenlenebilir)
    profile/profil_duzenle_screen.dart — ad soyad düzenleme
  widgets/
    app_drawer.dart                  — hamburger menü (profil, eleman ekle, admin paneli, çıkış)
    finance_card.dart                — Gelir/Gider/Ciro kartı (düz, pembesiz tasarım)
    support_bubble.dart              — sağ altta sabit "Canlı Destek" balonu (şu an placeholder sheet, gerçek mesajlaşma yok)
  theme/app_theme.dart               — renk paleti + Material tema (bkz. bölüm 4.4)

functions/index.js                   — 3 Cloud Function: personelEkle, sirketVeAdminOlustur, aracEkle (HİÇBİRİ DEPLOY EDİLMEDİ — Blaze plan gerekiyor)
firestore.rules                      — güvenlik kuralları
firestore.indexes.json               — şu an boş ({"indexes": [], "fieldOverrides": []}) — collectionGroup terk edildiği için composite index gerekmiyor
scripts/
  recalculate-summary.js             — summary/{yyyy-MM} dökümanlarını sıfırdan yeniden hesaplayan Admin SDK script'i
  backfill-vehicle-son-islem.js      — eski araçlara sonYapilanIs/sonIslemTarihi alanlarını dolduran tek seferlik script

### 5.1 firestore_service.dart — kritik metodlar

- islemEkle / giderEkle — yeni kayıt + ilgili ayın summary dökümanını increment() ile günceller.
- islemGuncelle / giderGuncelle — düzenlemede, kaydın KENDİ tarihine göre doğru ayın summary'sini delta kadar düzeltir (bugünün tarihine göre değil — geçmiş ay kaydı düzenlenirse o ayın özeti bozulmasın diye).
- tumIslemlerGetir(sirketId) — collectionGroup yerine kullanılan, vehicles → her aracın jobs'ını çeken N+1 yaklaşım (bkz. bölüm 4.3).
- tumGiderler(sirketId) — basit expenses stream'i, sorunsuz çalışıyor (collectionGroup değil, tek koleksiyon).
- _summary / _summaryForDate — ay anahtarını (yyyy-MM) hesaplayan yardımcılar.

## 6. Faz durumu (01_Yol_Haritasi.md'ye göre, ~%35-40 tamamlandı)

- Faz 0 (Firebase kurulumu): Tamamlandı. Proje var, Auth+Firestore çalışıyor.
- Faz 1 (Cloud Functions iskeleti): Kod yazıldı, DEPLOY EDİLMEDİ (Blaze plan gerekiyor — kullanıcı henüz yükseltmedi). Yani şu an personel ekleme, yeni şirket oluşturma, sunucu taraflı plaka mükerrer kontrolü ÇALIŞMIYOR.
- Faz 2-3 (Flutter iskelet + ekranlar): Büyük ölçüde tamamlandı. Login, Dashboard, Araç Detay, Admin Paneli (kısmi), Profil Düzenle var.
- Faz 4 (veri modeli): Tamamlandı (Vehicle, VehicleJob, Expense, UserRole).
- Faz 5+ (test, mağaza hazırlığı, yayınlama, abonelik/ödeme, push bildirim, SuperAdmin paneli, gerçek canlı destek): BAŞLANMADI.

## 7. Sırada ne var (öncelik sırasıyla)

1. Firebase Blaze plana geçiş + Cloud Functions deploy — bu olmadan gerçek personel eklenemez, gerçek şirket oluşturulamaz. Şu an tek şirket/kullanıcı Firebase Console'dan elle kurulmuş durumda.
2. Admin Panelinde "Eleman Ekle" sekmesini personelEkle fonksiyonuna bağlamak — UI muhtemelen zaten var, backend çağrısı eksik olabilir (deploy edilmediği için test edilmedi).
3. SuperAdmin paneli — sirketVeAdminOlustur fonksiyonu hazır ama hiçbir ekran onu çağırmıyor.
4. Gerçek Canlı Destek — şu an support_bubble.dart sadece placeholder bir sheet açıyor. Firestore tabanlı mesajlaşma ya da üçüncü parti (Crisp/Intercom) entegrasyonu gerekiyor.
5. Testler — hiç widget testi veya Firestore Rules testi yok.
6. Mağaza hazırlığı — ikon, splash screen, gizlilik politikası, imzalama, yayınlama hiç yapılmadı.
7. Abonelik/ödeme entegrasyonu — subscriptionStatus alanı var ama hiçbir ödeme akışı yok.

## 8. Bilinen sınırlamalar / dikkat edilmesi gerekenler

- tumIslemlerGetir N+1 okuma yapıyor — araç sayısı çok artarsa (yüzlerce) performans sorunu olabilir. O zaman collectionGroup'u TEKRAR DENEMEDEN önce bölüm 4.3'ü oku.
- firestore.indexes.json şu an boş — yeni bir composite sorgu eklenirse (örn. collectionGroup denenirse) tekrar index tanımlamak gerekebilir, ama tekli alan indexlerini (plaka, tarih gibi) ASLA elle ekleme, Firestore otomatik yönetiyor ve elle eklersen deploy hata verir ("this index is not necessary").
- firebase deploy --only firestore:rules bazen "already up to date, skipping upload" diyor — bu genelde LOKAL dosyanın değişmediği anlamına gelir, deploy'dan önce dosyanın gerçekten güncellendiğini kontrol et.
- Kullanıcının Mac'inde Terminal bazen eski bash kabuğuna düşüyordu (flutter/firebase PATH kayboluyordu) — chsh -s /bin/zsh ile kalıcı çözüldü, tekrar olursa echo $SHELL ile kontrol et.
- functions/index.js'teki 3 fonksiyon hiç test edilmedi (deploy edilmediği için) — deploy sonrası dikkatli test gerekir, özellikle custom claims atama kısmı (kullanıcı token'ını yenilemesi gerekebilir, getIdToken(true) ile).

## 9. Nasıl devam edilir (ortam kurulumu)

README.md'de detaylı var, özet:

cd ~/dev/oto_tamir_app
flutter pub get
firebase login
flutterfire configure
flutter run

Kod değişikliği yaptıktan sonra Firestore rules/index değiştiyse:
firebase deploy --only firestore:rules,firestore:indexes

Cloud Functions deploy etmeden önce Blaze plana geçmek gerekiyor (Firebase Console → Kullanım ve fatura).

## 10. Git

cd ~/dev/oto_tamir_app
git add -A
git commit -m "..."
git push
