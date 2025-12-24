# CampusGo

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/Firebase-Backend-FFCA28?style=for-the-badge&logo=firebase" alt="Firebase"/>
</p>

<p align="center">
  <b>Universite ogrencileri icin modern bir tanisma uygulamasi</b>
</p>

---

## Ozellikler

### Kimlik Dogrulama
- Email/sifre ile kayit ve giris
- Sifre sifirlama
- Beni hatirla ozelligi
- Guvenli oturum yonetimi

### Profil Yonetimi
- Coklu fotograf yukleme (6 adete kadar)
- 183+ Turk universitesi ve 300+ bolum secenegi
- Otomatik tamamlamali arama
- Ilgi alanlari secimi
- Biyografi ve kisisel bilgiler

### Tinder Tarzi Eslestirme
- **Saga kaydir** - Begen (LIKE)
- **Sola kaydir** - Gec (NOPE)
- **Yukari kaydir** - Super Begen (SUPER LIKE)
- Fotograflar arasi gecis (sag/sol tiklama)
- Gorsel swipe overlay'leri
- Haptic feedback

### Eslestirme Deneyimi
- Animasyonlu "It's a Match!" ekrani
- Cift profil fotografi gorunumu
- Yuzen kalp animasyonlari
- Mesaj gonderme secenegi

### Bildirim Sistemi
- Ozel tasarim bildirimler
- Basari, hata, uyari ve bilgi tipleri
- Animasyonlu giris/cikis
- Swipe ile kapatma

### Hesap Yonetimi
- Profil duzenleme
- Hesap silme (sifre dogrulamali)
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
| **UI/UX** | Material Design, Google Fonts |

---

## Kurulum

### Gereksinimler
- Flutter SDK 3.x
- Dart SDK 3.x
- Firebase projesi
- Xcode (iOS icin)
- Android Studio (Android icin)

### Adimlar

1. **Repoyu klonla**
```bash
git clone https://github.com/YOUR_USERNAME/campusgo.git
cd campusgo
```

2. **Bagimliliklari yukle**
```bash
flutter pub get
```

3. **Firebase yapilandirmasi**
```bash
flutterfire configure
```

4. **Uygulamayi calistir**
```bash
flutter run
```

---

## Proje Yapisi

```
lib/
├── data/                  # Statik veriler
├── models/                # Veri modelleri
├── providers/             # Riverpod state yonetimi
├── repositories/          # Veri katmani
├── screens/               # UI ekranlari
├── services/              # Is mantigi servisleri
├── widgets/               # Yeniden kullanilabilir widgetlar
└── main.dart              # Uygulama girisi
```

---

## Gelecek Ozellikler

- [ ] Gercek zamanli mesajlasma
- [ ] Push bildirimleri
- [ ] Konum bazli eslestirme
- [ ] Premium uyelik sistemi
- [ ] Profil dogrulama

---

## Lisans

MIT License

---

<p align="center">
  Made with Flutter
</p>
