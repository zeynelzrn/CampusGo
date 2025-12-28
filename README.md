# CampusGo

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/Firebase-Backend-FFCA28?style=for-the-badge&logo=firebase" alt="Firebase"/>
  <img src="https://img.shields.io/badge/iOS-Ready-000000?style=for-the-badge&logo=apple" alt="iOS"/>
  <img src="https://img.shields.io/badge/Android-Ready-3DDC84?style=for-the-badge&logo=android" alt="Android"/>
</p>

<p align="center">
  <b>Universite ogrencileri icin modern bir arkadaslik uygulamasi</b>
</p>

---

## Ekran Goruntusu

Uygulama 5 ana sekmeden olusmaktadir:
- **Profil** - Kendi profilini goruntule ve duzenle
- **Begeniler** - Seni begenen kisileri gor
- **Kesif** - Yeni insanlar kesfet (Swipe)
- **Sohbet** - Eslesmelerinle mesajlas
- **Ayarlar** - Uygulama ayarlari

---

## Ozellikler

### Kimlik Dogrulama
- Email/sifre ile kayit ve giris
- Sifre sifirlama (email ile)
- "Beni hatirla" ozelligi
- Guvenli oturum yonetimi
- Otomatik giris (hatirla seciliyse)

### Profil Yonetimi
- Coklu fotograf yukleme (6 adete kadar)
- 183+ Turk universitesi ve 300+ bolum secenegi
- Otomatik tamamlamali arama
- Ilgi alanlari secimi
- Biyografi ve kisisel bilgiler
- Profil tamamlanma kontrolu

### Arkadas Bulma Sistemi (Swipe)
- **Saga kaydir** - Arkadas ol (LIKE)
- **Sola kaydir** - Gec (NOPE)
- **Yukari kaydir** - Cok begendim (SUPER LIKE)
- Fotograflar arasi gecis (sag/sol tiklama)
- Gorsel swipe overlay'leri (animasyonlu)
- Haptic feedback
- Akilli kullanici filtreleme

### Modern Navigation Bar
- 5 sekmeli alt navigation
- Animasyonlu yüzen baloncuk efekti
- Neon gradient tasarim
- Sayfa gecislerinde swipe destegi
- Dikey scroll sirasinda yatay kilit

### Arkadaslik Deneyimi
- Animasyonlu "Yeni Arkadas!" ekrani
- Cift profil fotografi gorunumu
- Confetti animasyonlari
- Mesaj gonderme secenegi

### Bildirim Sistemi
- **Push Notifications** - Firebase Cloud Messaging (FCM)
- **In-App Overlay** - Foreground'da renkli banner bildirimleri
- **Firestore Stream** - iOS fallback (ucresiz hesap destegi)
- **Cloud Functions** - Sunucu tarafli bildirim tetikleme
- Begeni bildirimi (pembe gradient)
- Mesaj bildirimi (mor gradient)
- Eslesme bildirimi (pembe-turuncu gradient)
- Haptic feedback
- Bildirime tiklayinca ilgili ekrana yonlendirme

### Hesap Yonetimi
- Profil duzenleme
- Hesap silme (sifre dogrulamali)
- Guvenli cikis
- Tum verilerin guvenli silinmesi

---

## Teknolojiler

| Kategori | Teknoloji |
|----------|-----------|
| **Framework** | Flutter 3.x |
| **Dil** | Dart 3.x |
| **State Management** | Riverpod |
| **Backend** | Firebase |
| **Authentication** | Firebase Auth |
| **Database** | Cloud Firestore |
| **Storage** | Firebase Storage |
| **Push Notifications** | Firebase Cloud Messaging (FCM) |
| **Cloud Functions** | Firebase Functions (TypeScript) |
| **In-App Notifications** | overlay_support |
| **UI/UX** | Material Design, Google Fonts |
| **Animasyonlar** | Custom Animations, Shimmer |

---

## Kurulum

### Gereksinimler
- Flutter SDK 3.x
- Dart SDK 3.x
- Firebase projesi
- Xcode 15+ (iOS icin)
- Android Studio (Android icin)
- CocoaPods (iOS icin)

### Adimlar

1. **Repoyu klonla**
```bash
git clone https://github.com/zeynelzrn/CampusGo.git
cd campusgo_project
```

2. **Bagimliliklari yukle**
```bash
flutter pub get
```

3. **iOS icin Pod'lari yukle**
```bash
cd ios
pod install
cd ..
```

4. **Firebase yapilandirmasi**
   - Firebase Console'dan proje olustur
   - iOS ve Android uygulamalarini ekle
   - `GoogleService-Info.plist` (iOS) ve `google-services.json` (Android) dosyalarini indir
   - `lib/firebase_options.dart` dosyasini guncelle

5. **Cloud Functions kur (Bildirimler icin)**
```bash
cd functions
npm install
npm run build
firebase deploy --only functions
cd ..
```

6. **Uygulamayi calistir**
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

---

## Proje Yapisi

```
lib/
├── data/                      # Statik veriler (universiteler, bolumler)
├── models/                    # Veri modelleri
│   └── user_profile.dart      # Kullanici profil modeli
├── providers/                 # Riverpod state yonetimi
│   ├── profile_provider.dart  # Profil state
│   └── swipe_provider.dart    # Swipe state
├── repositories/              # Veri katmani
│   ├── profile_repository.dart
│   └── swipe_repository.dart
├── screens/                   # UI ekranlari
│   ├── splash_screen.dart     # Acilis ekrani
│   ├── welcome_screen.dart    # Karsilama ekrani
│   ├── login_screen.dart      # Giris ekrani
│   ├── register_screen.dart   # Kayit ekrani
│   ├── create_profile_screen.dart  # Profil olusturma
│   ├── main_screen.dart       # Ana ekran (5 tab)
│   ├── discover_screen.dart   # Kesif/Swipe ekrani
│   ├── likes_screen.dart      # Begeniler ekrani
│   ├── matches_screen.dart    # Eslesmeler ekrani
│   ├── profile_edit_screen.dart    # Profil duzenleme
│   └── settings_screen.dart   # Ayarlar ekrani
├── services/                  # Is mantigi servisleri
│   ├── auth_service.dart      # Kimlik dogrulama
│   ├── profile_service.dart   # Profil islemleri
│   ├── notification_service.dart  # FCM ve bildirim yonetimi
│   └── seed_service.dart      # Test verisi olusturma
├── widgets/                   # Yeniden kullanilabilir widgetlar
│   ├── campus_logo.dart       # Logo widget
│   ├── custom_notification.dart   # Bildirim widget
│   └── swipe_card.dart        # Swipe karti widget
├── firebase_options.dart      # Firebase yapilandirmasi
└── main.dart                  # Uygulama girisi

functions/                     # Firebase Cloud Functions
├── src/
│   └── index.ts              # Bildirim trigger fonksiyonlari
├── package.json              # Node.js bagimliliklari
└── tsconfig.json             # TypeScript yapilandirmasi
```

---

## Firebase Yapilandirmasi

### Firestore Kurallari
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /swipes/{swipeId} {
      allow read, write: if request.auth != null;
    }
    match /matches/{matchId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Storage Kurallari
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_images/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## Sorun Giderme

### iOS Beyaz Ekran Sorunu
Eger iOS'ta beyaz ekran aliyorsaniz:

1. **API Key kontrolu** - `GoogleService-Info.plist` ve `firebase_options.dart` dosyalarindaki iOS API key'lerinin ayni oldugundan emin olun

2. **Clean build**
```bash
flutter clean
cd ios && pod install && cd ..
flutter build ios --debug
```

3. **Derived data temizligi**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
```

### Firebase Auth Hatalari
- Firebase Console'da **Authentication > Sign-in method > Email/Password** etkin olmali
- Bundle ID'nin Firebase Console'daki ile eslesmeli (`com.example.campusgoProject`)

---

## Gelecek Ozellikler

- [x] Gercek zamanli mesajlasma
- [x] Push bildirimleri (FCM + Firestore Stream)
- [ ] Konum bazli arkadas onerisi
- [ ] Premium uyelik sistemi
- [ ] Profil dogrulama
- [ ] Sesli/goruntulu arama
- [ ] Hikaye ozelligi

---

## Katkida Bulunma

1. Fork'layin
2. Feature branch olusturun (`git checkout -b feature/amazing-feature`)
3. Degisikliklerinizi commit edin (`git commit -m 'Add amazing feature'`)
4. Branch'i push edin (`git push origin feature/amazing-feature`)
5. Pull Request acin

---

## Lisans

MIT License - Detaylar icin [LICENSE](LICENSE) dosyasina bakin.

---

<p align="center">
  Made with Flutter
</p>
