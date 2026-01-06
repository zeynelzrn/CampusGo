# CampusGo - Kapsamli Proje Dokumantasyonu

## GENEL BAKIS

**Proje Adi:** CampusGo
**Tanim:** Turk universite ogrencileri icin Tinder benzeri sosyal tanisma platformu
**Versiyon:** 1.0.0+1
**Platform:** Flutter (Android, iOS, macOS, Web)
**Firebase Project ID:** campusgo-zrn
**Gelistirme Dili:** Dart 3.0+
**State Management:** Flutter Riverpod
**Backend:** Firebase (Auth, Firestore, Storage, Cloud Messaging)

---

## PROJE MIMARISI

```
campusgo_project/
├── lib/
│   ├── main.dart                    # Uygulama giris noktasi
│   ├── firebase_options.dart        # Firebase konfigurasyonu
│   ├── data/                        # Statik veriler
│   │   └── turkish_universities.dart
│   ├── models/                      # Veri modelleri
│   │   ├── user_profile.dart
│   │   └── chat.dart
│   ├── providers/                   # Riverpod state management
│   │   ├── profile_provider.dart
│   │   ├── swipe_provider.dart
│   │   └── likes_provider.dart
│   ├── repositories/                # Firestore veri islemleri
│   │   ├── profile_repository.dart
│   │   ├── swipe_repository.dart
│   │   └── likes_repository.dart
│   ├── services/                    # Is mantigi servisleri
│   │   ├── auth_service.dart
│   │   ├── user_service.dart
│   │   ├── chat_service.dart
│   │   ├── profile_service.dart
│   │   ├── notification_service.dart
│   │   ├── seed_service.dart
│   │   └── debug_service.dart
│   ├── screens/                     # UI ekranlari
│   │   ├── splash_screen.dart
│   │   ├── welcome_screen.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── create_profile_screen.dart
│   │   ├── main_screen.dart
│   │   ├── discover_screen.dart
│   │   ├── likes_screen.dart
│   │   ├── matches_screen.dart
│   │   ├── chat_list_screen.dart
│   │   ├── chat_detail_screen.dart
│   │   ├── profile_edit_screen.dart
│   │   ├── user_profile_screen.dart
│   │   ├── blocked_users_screen.dart
│   │   └── settings_screen.dart
│   └── widgets/                     # Yeniden kullanilabilir widgetlar
│       ├── swipe_card.dart
│       └── custom_notification.dart
├── firestore.rules                  # Firestore guvenlik kurallari
├── firestore.indexes.json           # Firestore composite indexler
├── firebase.json                    # Firebase konfigurasyonu
└── pubspec.yaml                     # Flutter bagimliliklari
```

---

## FIREBASE / FIRESTORE VERITABANI YAPISI

### Collection: `users`
Kullanici profilleri

```javascript
{
  id: "userId",                    // Firebase Auth UID
  name: "Zeynep",                  // Isim
  age: 21,                         // Yas
  bio: "Muzik ve kitap...",        // Biyografi
  university: "Bogazici Univ.",    // Universite
  department: "Bilgisayar Muh.",   // Bolum
  photos: ["url1", "url2"],        // Fotograf URL'leri (Firebase Storage)
  interests: ["Muzik", "Spor"],    // Ilgi alanlari
  gender: "Kadin",                 // Cinsiyet: "Kadin" | "Erkek"
  lookingFor: "Erkek",             // Aradigi: "Kadin" | "Erkek" | "Herkes"
  createdAt: Timestamp,            // Kayit tarihi
  grade: "3. Sinif",               // Sinif seviyesi
  clubs: ["Dans Kulubu"],          // Topluluklar/Kulupler (TEXT input)
  socialLinks: {},                 // Sosyal medya (KALDIRILDI)
  intent: ["Kahve icmek"],         // Niyet/Aktivite tercihleri
  fcmToken: "token",               // Push notification token
  location: GeoPoint               // Konum (opsiyonel)
}
```

**Alt Koleksiyonlar:**
- `users/{userId}/matches/{matchId}` - Kullanicinin eslestigi kisiler
- `users/{userId}/blocked_users/{blockedId}` - Engelledigim kisiler
- `users/{userId}/blocked_by/{blockerId}` - Beni engelleyenler
- `users/{userId}/notifications/{notifId}` - In-app bildirimler

---

### Collection: `actions`
Swipe aksiyonlari (like/dislike/superlike)

```javascript
{
  id: "fromUserId_toUserId",       // Document ID formati
  fromUserId: "abc123",            // Aksiyonu yapan
  toUserId: "xyz789",              // Aksiyon yapilan
  type: "like",                    // "like" | "dislike" | "superlike"
  timestamp: Timestamp             // Aksiyon zamani
}
```

---

### Collection: `matches`
Karsilikli begeni (mutual like) eslestirmeleri

```javascript
{
  id: "userId1_userId2",           // Alfabetik sirali ID
  users: ["userId1", "userId2"],   // Eslesen kullanicilar
  timestamp: Timestamp             // Eslesme zamani
}
```

---

### Collection: `chats`
Sohbet odalari

```javascript
{
  id: "userId1_userId2",           // Alfabetik sirali ID
  users: ["userId1", "userId2"],   // Sohbetteki kullanicilar
  lastMessage: "Merhaba!",         // Son mesaj
  lastMessageTime: Timestamp,      // Son mesaj zamani
  lastMessageSenderId: "userId1",  // Son mesaji gonderen
  readBy: ["userId1"],             // Okuyanlar
  peerData: {                      // Peer bilgileri (cache)
    user1Name: "Zeynep",
    user1Image: "url",
    user2Name: "Ahmet",
    user2Image: "url"
  }
}
```

**Alt Koleksiyon:**
- `chats/{chatId}/messages/{messageId}` - Mesajlar

```javascript
{
  id: "messageId",
  senderId: "userId",
  text: "Merhaba!",
  timestamp: Timestamp,
  type: "text",                    // "text" | "image" | "system"
  isRead: false
}
```

---

### Collection: `reports`
Kullanici sikayetleri

```javascript
{
  reporterId: "userId",
  reportedId: "targetUserId",
  reason: "harassment",            // Sikayet sebebi
  description: "Detayli aciklama",
  timestamp: Timestamp,
  status: "pending",               // "pending" | "reviewed" | "resolved"
  action: null                     // Alinan aksiyon
}
```

---

## FIRESTORE COMPOSITE INDEXES

Dosya: `firestore.indexes.json`

```json
{
  "indexes": [
    {
      "collectionGroup": "chats",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "users", "arrayConfig": "CONTAINS" },
        { "fieldPath": "lastMessageTime", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "matches",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "users", "arrayConfig": "CONTAINS" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "gender", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

**Index Aciklamalari:**
1. **chats index:** Kullanicinin sohbetlerini son mesaj zamanina gore siralamak icin
2. **matches index:** Kullanicinin eslesmelerini zamana gore siralamak icin
3. **users index:** Cinsiyet filtrelemesi + kayit tarihine gore siralama (Kesif ekrani)

---

## FIRESTORE GUVENLIK KURALLARI

Dosya: `firestore.rules`

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // USERS - Kendi profilini okuyabilir/yazabilir
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;

      // Matches alt koleksiyonu
      match /matches/{matchId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // ACTIONS - Swipe aksiyonlari
    match /actions/{actionId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // MATCHES - Sadece eslesmedeki kullanicilar erisebilir
    match /matches/{matchId} {
      allow read: if request.auth != null &&
        request.auth.uid in resource.data.users;
      allow write: if request.auth != null;
    }

    // CHATS - Sadece sohbetteki kullanicilar erisebilir
    match /chats/{chatId} {
      allow read: if request.auth != null &&
        request.auth.uid in resource.data.users;
      allow create: if request.auth != null &&
        request.auth.uid in request.resource.data.users;
      allow update, delete: if request.auth != null &&
        request.auth.uid in resource.data.users;

      // MESSAGES alt koleksiyonu
      match /messages/{messageId} {
        allow read: if request.auth != null &&
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.users;
        allow create: if request.auth != null &&
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.users &&
          request.resource.data.senderId == request.auth.uid;
        allow update, delete: if request.auth != null &&
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.users;
      }
    }
  }
}
```

---

## VERI MODELLERI

### UserProfile Model (`lib/models/user_profile.dart`)

```dart
class UserProfile {
  final String id;
  final String name;
  final int age;
  final String bio;
  final String university;
  final String department;
  final List<String> photos;
  final List<String> interests;
  final String gender;           // "Kadin" | "Erkek"
  final String lookingFor;       // "Kadin" | "Erkek" | "Herkes"
  final DateTime? createdAt;
  final GeoPoint? location;

  // Zenginlestirilmis alanlar
  final String grade;            // "Hazirlik", "1. Sinif", "2. Sinif", vb.
  final List<String> clubs;      // Topluluklar (serbest metin)
  final Map<String, String> socialLinks;  // (KALDIRILDI - bos)
  final List<String> intent;     // Aktivite niyetleri

  // Firestore donusumleri
  factory UserProfile.fromFirestore(DocumentSnapshot doc);
  Map<String, dynamic> toFirestore();

  // Yardimci getterlar
  String get primaryPhoto;       // Ilk fotograf veya placeholder
  bool get isComplete;           // Profil tamamlanmis mi?
}
```

### SwipeActionType Enum

```dart
enum SwipeActionType {
  like,
  dislike,
  superlike,
}
```

### Match Model

```dart
class Match {
  final String id;
  final List<String> userIds;
  final DateTime matchedAt;
  final DateTime? lastMessageAt;
}
```

### Chat Model (`lib/models/chat.dart`)

```dart
class Chat {
  final String id;
  final List<String> users;
  final String peerId;
  final String peerName;
  final String? peerImage;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool isRead;
  final String? lastMessageSenderId;

  // Statik yardimcilar
  static String generateChatId(String userId1, String userId2);
  static String getPeerId(String chatId, String currentUserId);

  // Zaman formatlama
  String get formattedTime;  // "Simdi", "5 dk", "2 sa", "3 gun"
  bool hasUnreadFor(String currentUserId);
}
```

### Message Model

```dart
class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageType type;    // text, image, system
  final bool isRead;

  String get formattedTime;  // "HH:mm" formati
  bool isFromMe(String currentUserId);
}

enum MessageType {
  text,
  image,
  system,
}
```

---

## STATE MANAGEMENT (Riverpod Providers)

### SwipeProvider (`lib/providers/swipe_provider.dart`)

Kesif ekrani state yonetimi - profil kartlari, swipe aksiyonlari, eslesme tespiti

```dart
// State
class SwipeState {
  final List<UserProfile> profiles;    // Gosterilecek profiller
  final Set<String> excludedIds;       // Haric tutulanlar (swiped + blocked)
  final bool isLoading;
  final bool hasMore;                  // Daha fazla profil var mi?
  final DocumentSnapshot? lastDocument; // Pagination cursor
  final UserProfile? lastSwipedProfile; // Geri alma icin
  final bool isMatch;                  // Eslesme animasyonu
  final String? genderFilter;          // Cinsiyet filtresi
}

// Notifier metodlari
class SwipeNotifier {
  Future<void> _initialize();           // Baslangic yuklemesi
  Future<void> _fetchNextBatch();       // Sonraki batch (PAGINATION)
  Future<void> onSwipe(int index, SwipeActionType type);
  Future<void> swipeLeft(int index);    // Dislike
  Future<void> swipeRight(int index);   // Like
  Future<void> superLike(int index);    // SuperLike
  Future<bool> undoLastSwipe();         // Son swipe'i geri al
  Future<void> refresh();               // Yenile
  Future<void> updateGenderFilter(String? gender);  // Filtre degistir
}

// Providerlar
final swipeRepositoryProvider = Provider<SwipeRepository>(...);
final swipeProvider = StateNotifierProvider<SwipeNotifier, SwipeState>(...);
final matchesProvider = StreamProvider<List<Match>>(...);
final profileAtIndexProvider = Provider.family<UserProfile?, int>(...);
```

### LikesProvider (`lib/providers/likes_provider.dart`)

Beni begenenleri gorme ve yonetme

```dart
// Providerlar
final receivedLikesProvider = StreamProvider<List<UserProfile>>(...);
final eliminatedUserIdsProvider = FutureProvider<Set<String>>(...);
final likesUIProvider = StateNotifierProvider<LikesUINotifier, LikesUIState>(...);
```

### ProfileProvider (`lib/providers/profile_provider.dart`)

Kullanici profil durumu ve olusturma

```dart
enum AppStartupState {
  loading,
  unauthenticated,
  needsProfile,
  authenticated,
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(...);
final profileCreationProvider = StateNotifierProvider<ProfileCreationNotifier, ProfileCreationState>(...);
final currentProfileProvider = FutureProvider<UserProfile?>(...);
```

---

## SERVISLER

### AuthService (`lib/services/auth_service.dart`)

Firebase Authentication wrapper

```dart
class AuthService {
  User? get currentUser;
  Stream<User?> get authStateChanges;

  Future<UserCredential> register(String email, String password);
  Future<UserCredential> login(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> deleteAccount(String password);  // Re-auth gerektirir
}
```

### UserService (`lib/services/user_service.dart`)

Kullanici engelleme ve raporlama (~450 satir)

```dart
class UserService {
  // Engelleme islemleri
  Future<void> blockUser(String blockedUserId);
  Future<void> unblockUser(String blockedUserId);
  Future<bool> isUserBlocked(String userId);
  Future<Set<String>> getBlockedUserIds();
  Stream<Set<String>> watchBlockedUserIds();

  // Karsilikli gorunmezlik (Blacklist)
  Future<Set<String>> getBlockedByUserIds();     // Beni engelleyenler
  Future<Set<String>> getAllRestrictedUserIds(); // Tum kisitlilar
  Stream<Set<String>> watchAllRestrictedUserIds();
  Future<bool> hasBlockRelationship(String userId);

  // Raporlama
  Future<void> reportUser(String reportedUserId, String reason, String? description);
  Future<bool> hasAlreadyReported(String reportedUserId);
}

// Rapor sebepleri
class ReportReason {
  static const harassment = "taciz/zorbalik";
  static const fake_profile = "sahte profil";
  static const inappropriate_content = "uygunsuz icerik";
  static const underage = "18 yasindan kucuk";
  static const scam = "dolandiricilik";
  static const other = "diger";
}
```

### ChatService (`lib/services/chat_service.dart`)

Gercek zamanli mesajlasma (~390 satir)

```dart
class ChatService {
  // Sohbet listesi
  Stream<List<Chat>> watchChats();
  Future<Chat?> getChat(String chatId);
  Future<String> createOrGetChat(String otherUserId);
  Future<String> createMatchChat(String userId1, String userId2);

  // Mesajlar
  Stream<List<Message>> watchMessages(String chatId);
  Future<void> sendMessage(String chatId, String text);
  Future<void> markChatAsRead(String chatId);

  // Okunmamis sayisi
  Stream<int> watchUnreadCount();

  // Sohbet yonetimi
  Future<void> clearChat(String chatId);   // Mesajlari temizle
  Future<void> deleteChat(String chatId);  // Tamamen sil
}
```

### NotificationService (`lib/services/notification_service.dart`)

Push ve in-app bildirimler (~628 satir, Singleton pattern)

```dart
class NotificationService {
  static final NotificationService instance = NotificationService._();

  // Baslangic
  Future<void> initialize();
  Future<void> requestPermission();

  // FCM Token yonetimi
  Future<String?> getFCMToken();
  Future<void> saveTokenToFirestore(String token);
  Future<void> deleteTokenFromFirestore();
  Future<void> getAndSaveToken();

  // Yerel bildirimler
  Future<void> showLocalNotification(String title, String body, String? payload);

  // In-app overlay bildirimler (Firestore stream)
  void listenToInAppNotifications();
  void stopListeningToNotifications();

  // Bildirim tipleri ve renkleri
  void _showLikeNotification();    // Indigo gradient
  void _showMessageNotification(); // Mor gradient
  void _showMatchNotification();   // Pembe-turuncu gradient

  // Navigasyon callback
  static void setNavigationCallback(Function(int) callback);
}
```

---

## REPOSITORY LAYER

### SwipeRepository (`lib/repositories/swipe_repository.dart`)

Swipe islemleri ve profil cekme - **OPTIMIZE EDILMIS**

```dart
class SwipeRepository {
  static const int batchSize = 10;
  static const int fetchBatchSize = 20;

  // Exclusion list (haric tutulacaklar)
  Future<Set<String>> fetchAllActionIds();     // Swipe edilenler + Engellenenler
  Future<Set<String>> refreshExclusionList();  // Engelleme sonrasi yenile

  // Profil cekme - PAGINATION DESTEKLI
  Future<({List<UserProfile> profiles, DocumentSnapshot? lastDoc})> fetchUserBatch({
    DocumentSnapshot? lastDocument,  // Pagination cursor
    String? genderFilter,            // Cinsiyet filtresi
  });

  // Swipe kaydetme ve eslesme kontrolu
  Future<Map<String, dynamic>> recordSwipeAction({
    required String targetUserId,
    required SwipeActionType actionType,
  });
  // Return: {'success': bool, 'isMatch': bool}

  // Match olusturma (KARSILIKLI BEGENI KONTROLU)
  Future<bool> _checkAndCreateMatch(String targetUserId);
  Future<void> _createMatchAndChat(String userId1, String userId2);

  // Profil islemleri
  Future<UserProfile?> getCurrentUserProfile();
  Future<UserProfile?> getUserProfile(String userId);
  Future<String?> getUserLookingForPreference();

  // Geri alma
  Future<bool> undoLastSwipe(String targetUserId);

  // Match stream
  Stream<List<Match>> watchMatches();
}
```

**Pagination Optimizasyonu:**
- `lastDocument` ile Firestore cursor-based pagination
- Her batch'te sadece yeni kullanicilar cekilir
- Ayni kullanicilarin tekrar cekilmesi onlenir
- Firebase okuma maliyeti ~%80 azaltildi

### LikesRepository (`lib/repositories/likes_repository.dart`)

Gelen begenileri yonetme

```dart
class LikesRepository {
  // Gelen begeniler stream'i
  Stream<List<UserProfile>> watchReceivedLikes();
  // Filtreler: like/superlike, matched degil, dismissed degil

  Future<Set<String>> getEliminatedUserIds();  // Dislike ettiklerim
  Future<void> likeUser(String userId);        // Like -> Match kontrolu
  Future<void> dislikeUser(String userId);     // Dislike
  Future<void> dismissUser(String userId);     // Listeden cikar
}
```

---

## UI EKRANLARI

### MainScreen - Ana Navigasyon Hub

5 sekmeli sayfa gorunumu (PageView)

```
Index 0: ProfileEditScreen  - Profil Duzenleme
Index 1: LikesScreen        - Gelen Begeniler
Index 2: DiscoverScreen     - Kesif (VARSAYILAN)
Index 3: ChatListScreen     - Sohbetler
Index 4: SettingsScreen     - Ayarlar
```

**Ozellikler:**
- `DirectionalLockPageView`: Dikey scroll sirasinda yatay kaydirmayi engeller
- Ozel animasyonlu navigation bar (indigo gradient balon efekti)
- Haptic feedback
- FCM token otomatik guncelleme
- In-app notification listener

### DiscoverScreen - Kesif

Tinder tarzı kart kaydirma arayuzu

**Ozellikler:**
- Swipe kartlari (like/dislike/superlike)
- Cinsiyet filtreleme
- Pagination ile otomatik onyukleme (prefetch)
- Eslesme animasyonu
- Immersive status bar

### LikesScreen - Gelen Begeniler

**Ozellikler:**
- Gercek zamanli begeni stream'i
- Akilli filtreleme (eslesmis/dislike/dismissed haric)
- Like/dislike butonlari
- Swipe-to-dismiss

### ChatListScreen - Sohbet Listesi

**Ozellikler:**
- Gercek zamanli sohbet listesi
- Son mesaja gore siralama
- Okunmamis mesaj gostergesi
- Sohbet onizleme

### ChatDetailScreen - Sohbet Detayi

**Ozellikler:**
- Gercek zamanli mesaj stream'i
- Mesaj gonderme
- Okundu bilgisi
- Profil onizleme
- Engelleme/Raporlama

### ProfileEditScreen - Profil Duzenleme

**Ozellikler:**
- Fotograf galerisi yonetimi
- Kisisel bilgi duzenleme
- Universite/Bolum secimi
- Sinif seviyesi
- Topluluklar (serbest metin girisi)
- "Kiminle tanismak istiyorsun" filtresi
- Onizleme modu
- Animated kayit bildirimi

### UserProfileScreen - Profil Onizleme

Discover ekrani ile ayni gorunum - kart stili profil gosterimi

---

## WIDGET'LAR

### SwipeCard (`lib/widgets/swipe_card.dart`)

Tinder tarzı kart widget'i

**Ozellikler:**
- Fotograf galerisi (tap ile gezinme)
- Gradient overlay ile profil bilgileri
- Swipe aksiyon overlay'leri (like/nope/superlike)
- Fotograf gostergeleri
- Tap zone'lari
- Haptic feedback
- Shimmer yukleme efekti

### CustomNotification (`lib/widgets/custom_notification.dart`)

Animasyonlu in-app bildirim overlay'i

```dart
enum NotificationType {
  success,  // Yesil gradient
  error,    // Kirmizi gradient
  warning,  // Turuncu gradient
  info,     // Mavi gradient
  like,     // Indigo gradient
  message,  // Mor gradient
}

// Kullanim
CustomNotification.success(context, title: "Basarili!", message: "Kayit edildi");
CustomNotification.error(context, title: "Hata", message: "Bir sorun olustu");
CustomNotification.like(context, title: "Yeni begeni!", message: "Biri seni begendi");
```

---

## DEPENDENCIES (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2
  google_fonts: ^6.1.0

  # Firebase Suite
  firebase_core: ^3.8.1
  firebase_auth: ^5.3.4
  cloud_firestore: ^5.5.1
  firebase_storage: ^12.3.7
  firebase_messaging: ^15.1.6

  # State Management
  flutter_riverpod: ^2.4.9

  # UI Components
  flutter_card_swiper: ^7.0.1
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  overlay_support: ^2.1.0

  # Notifications
  flutter_local_notifications: ^18.0.1

  # Storage
  shared_preferences: ^2.2.2
  image_picker: ^1.0.7

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
  flutter_launcher_icons: ^0.14.2
```

---

## ONEMLI OZELLIKLER VE IS MANTIGI

### 1. Karsilikli Eslesme (Mutual Match)

Match SADECE iki kullanici birbirini begendiginde olusur:

```
A begeniyor B -> Aksyon kaydedilir, eslesme YOK
B begeniyor A -> Karsilikli kontrol -> IT'S A MATCH!
              -> Match document olusturulur
              -> Chat odasi otomatik olusturulur
```

### 2. Blacklist Sistemi

Karsilikli gorunmezlik:
- Engellediklerim: `users/{me}/blocked_users`
- Beni engelleyenler: `users/{me}/blocked_by`
- Her iki taraf da birbirini goremez
- Swipe listesinden otomatik haric tutulur

### 3. Cinsiyet Filtreleme

Profil ayarindaki "Kiminle tanismak istiyorsun" secenegine gore:
- "Kadin" -> Sadece kadinlari goster
- "Erkek" -> Sadece erkekleri goster
- "Herkes" -> Herkesi goster

Firestore index: `gender ASC + createdAt DESC`

### 4. Pagination Optimizasyonu

**Onceki sorun:**
- Ayni kullanicilar 5 kez cekiliyor
- lastDocument takip edilmiyor
- Firebase maliyeti yuksek

**Cozum:**
- `DocumentSnapshot? lastDocument` ile cursor-based pagination
- Her batch'te cursor guncelleniyor
- Tekrar eden fetch'ler onleniyor
- ~%80 maliyet azaltmasi

### 5. Bildirim Sistemi

**FCM (Push Notifications):**
- Background handler ile terminated state'de calisir
- Token Firestore'a kaydedilir
- Logout'ta token silinir

**In-App Overlay Notifications:**
- Like: Indigo gradient + el sallama ikonu
- Message: Mor gradient + chat ikonu
- Match: Pembe-turuncu gradient + kutlama ikonu

---

## EKRAN AKISI

```
SplashScreen
    |
    +-- Kullanici yok --> WelcomeScreen
    |                         |
    |                         +-- LoginScreen
    |                         |
    |                         +-- RegisterScreen
    |
    +-- Profil yok --> CreateProfileScreen
    |
    +-- Profil var --> MainScreen (index=2, DiscoverScreen)
                           |
                           +-- ProfileEditScreen (index=0)
                           |       +-- UserProfileScreen (onizleme)
                           |
                           +-- LikesScreen (index=1)
                           |
                           +-- DiscoverScreen (index=2)
                           |       +-- UserProfileScreen (profil detay)
                           |
                           +-- ChatListScreen (index=3)
                           |       +-- ChatDetailScreen
                           |
                           +-- SettingsScreen (index=4)
                                   +-- BlockedUsersScreen
```

---

## FIREBASE KONFIGURASYONU

**Project ID:** campusgo-zrn
**Storage Bucket:** campusgo-zrn.firebasestorage.app
**Messaging Sender ID:** 871846711176

**Desteklenen Platformlar:**
- Android
- iOS
- macOS
- Web
- Windows

---

## GELISTIRME NOTLARI

### Tamamlanan Ozellikler
- [x] Email/Password authentication
- [x] Profil olusturma ve duzenleme
- [x] Fotograf yukleme (Firebase Storage)
- [x] Tinder-style swipe kartlari
- [x] Like/Dislike/SuperLike aksiyonlari
- [x] Karsilikli eslesme (mutual match)
- [x] Gercek zamanli mesajlasma
- [x] Push notifications (FCM)
- [x] In-app overlay notifications
- [x] Kullanici engelleme
- [x] Kullanici raporlama
- [x] Cinsiyet filtreleme
- [x] Pagination optimizasyonu
- [x] Profil onizleme modu

### Gelecek Gelistirmeler (Oneriler)
- [ ] Fotograf kirilma (crop) ozelligi
- [ ] Konum bazli filtreleme
- [ ] Universite bazli filtreleme
- [ ] Goruntulu/sesli arama
- [ ] Hikaye (story) ozelligi
- [ ] Premium uyelik sistemi

---

## ONEMLI DOSYA YOLLARI

```
lib/main.dart                          - Uygulama giris noktasi
lib/firebase_options.dart              - Firebase config
lib/models/user_profile.dart           - Kullanici modeli
lib/models/chat.dart                   - Chat/Message modeli
lib/providers/swipe_provider.dart      - Kesif state management
lib/providers/likes_provider.dart      - Begeniler state
lib/providers/profile_provider.dart    - Profil state
lib/repositories/swipe_repository.dart - Swipe Firestore islemleri
lib/repositories/likes_repository.dart - Begeni Firestore islemleri
lib/services/auth_service.dart         - Firebase Auth wrapper
lib/services/chat_service.dart         - Chat islemleri
lib/services/user_service.dart         - Engelleme/Raporlama
lib/services/notification_service.dart - Bildirimler
lib/screens/main_screen.dart           - Ana navigasyon
lib/screens/discover_screen.dart       - Kesif ekrani
lib/screens/profile_edit_screen.dart   - Profil duzenleme
lib/widgets/swipe_card.dart            - Kart widget'i
lib/widgets/custom_notification.dart   - Bildirim widget'i
firestore.rules                        - Guvenlik kurallari
firestore.indexes.json                 - Composite indexler
```

---

*Bu dokuman CampusGo projesinin kapsamli teknik dokumantasyonudur. 
