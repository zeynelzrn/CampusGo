import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat.dart';
import '../models/hive_adapters.dart';

/// Hive tabanlı Mesaj Önbellekleme Servisi
///
/// Özellikler:
/// - Her sohbet için son 50 mesajı yerel depolamada saklar
/// - Anında erişim için Hive NoSQL veritabanı kullanır
/// - Pagination desteği ile RAM optimizasyonu
/// - Firebase maliyetlerini %70'e kadar düşürür
class MessageCacheService {
  static const String _boxName = 'messages_cache';
  static const int _maxCachedMessagesPerChat = 50;
  static const int _defaultFetchLimit = 20;

  Box<CachedMessage>? _box;
  bool _isInitialized = false;

  /// Singleton instance
  static final MessageCacheService _instance = MessageCacheService._internal();
  factory MessageCacheService() => _instance;
  MessageCacheService._internal();

  /// Hive'ı başlat ve adapterleri kaydet
  /// main.dart'ta uygulama başlatılırken çağrılmalı
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // TypeAdapter'ları kaydet (zaten kayıtlıysa hata vermez)
    if (!Hive.isAdapterRegistered(HiveTypeIds.cachedMessage)) {
      Hive.registerAdapter(CachedMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.messageType)) {
      Hive.registerAdapter(MessageTypeAdapter());
    }

    debugPrint('MessageCacheService: Hive initialized');
  }

  /// Box'ı aç (lazy initialization)
  Future<Box<CachedMessage>> _getBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }

    _box = await Hive.openBox<CachedMessage>(_boxName);
    _isInitialized = true;
    debugPrint('MessageCacheService: Box opened with ${_box!.length} messages');
    return _box!;
  }

  /// Önbellekten mesajları yükle (pagination ile)
  ///
  /// [chatId] - Sohbet ID'si
  /// [limit] - Getirilecek maksimum mesaj sayısı (varsayılan: 20)
  /// [beforeTimestamp] - Bu timestamp'ten önceki mesajları getir (pagination için)
  ///
  /// Returns: Mesaj listesi (en eskiden en yeniye sıralı - ListView için) veya null
  Future<List<Message>?> getCachedMessages(
    String chatId, {
    int limit = _defaultFetchLimit,
    DateTime? beforeTimestamp,
  }) async {
    try {
      final box = await _getBox();

      // Bu chat'e ait mesajları filtrele
      var chatMessages = box.values
          .where((msg) => msg.chatId == chatId)
          .toList();

      if (chatMessages.isEmpty) {
        debugPrint('MessageCacheService: No cached messages for chat $chatId');
        return null;
      }

      // Timestamp'e göre sırala (en yeni önce)
      chatMessages.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));

      // Pagination: beforeTimestamp varsa, ondan önceki mesajları al
      if (beforeTimestamp != null) {
        final beforeMs = beforeTimestamp.millisecondsSinceEpoch;
        chatMessages = chatMessages
            .where((msg) => msg.timestampMs < beforeMs)
            .toList();
      }

      // Limit uygula (RAM optimizasyonu)
      final limitedMessages = chatMessages.take(limit).toList();

      // Message modellerine dönüştür ve ters çevir (en eski önce - ListView için)
      final messages = limitedMessages.map((c) => c.toMessage()).toList().reversed.toList();

      debugPrint('MessageCacheService: Loaded ${messages.length} messages from cache for chat $chatId (before: ${beforeTimestamp?.toIso8601String() ?? 'latest'})');
      return messages;
    } catch (e) {
      debugPrint('MessageCacheService: Error loading cache: $e');
      return null;
    }
  }

  /// Önbellekte bu chat için toplam mesaj sayısını getir
  Future<int> getCachedMessageCount(String chatId) async {
    try {
      final box = await _getBox();
      return box.values.where((msg) => msg.chatId == chatId).length;
    } catch (e) {
      debugPrint('MessageCacheService: Error getting message count: $e');
      return 0;
    }
  }

  /// Önbellekteki en eski mesajın timestamp'ini getir (pagination için)
  Future<DateTime?> getOldestCachedMessageTimestamp(String chatId) async {
    try {
      final box = await _getBox();
      final chatMessages = box.values.where((msg) => msg.chatId == chatId).toList();

      if (chatMessages.isEmpty) return null;

      chatMessages.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
      return DateTime.fromMillisecondsSinceEpoch(chatMessages.first.timestampMs);
    } catch (e) {
      debugPrint('MessageCacheService: Error getting oldest timestamp: $e');
      return null;
    }
  }

  /// Önbellekteki en yeni mesajın timestamp'ini getir (delta sync için)
  ///
  /// ChatService.watchMessages bu değeri kullanarak sadece
  /// yeni mesajları sorgulamasına olanak tanır (maliyet optimizasyonu)
  Future<DateTime?> getNewestCachedMessageTimestamp(String chatId) async {
    try {
      final box = await _getBox();
      final chatMessages = box.values.where((msg) => msg.chatId == chatId).toList();

      if (chatMessages.isEmpty) return null;

      // En yeni mesajı bul
      chatMessages.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
      return DateTime.fromMillisecondsSinceEpoch(chatMessages.first.timestampMs);
    } catch (e) {
      debugPrint('MessageCacheService: Error getting newest timestamp: $e');
      return null;
    }
  }

  /// Cache'de bu chat için veri var mı?
  Future<bool> hasCachedMessages(String chatId) async {
    try {
      final box = await _getBox();
      return box.values.any((msg) => msg.chatId == chatId);
    } catch (e) {
      return false;
    }
  }

  /// Mesajları önbelleğe kaydet
  ///
  /// [chatId] - Sohbet ID'si
  /// [messages] - Kaydedilecek mesajlar
  ///
  /// Not: Sadece son 50 mesaj saklanır
  Future<void> cacheMessages(String chatId, List<Message> messages) async {
    if (messages.isEmpty) return;

    try {
      final box = await _getBox();

      // Önce bu chat'in eski mesajlarını sil
      final keysToDelete = box.keys.where((key) {
        final msg = box.get(key);
        return msg?.chatId == chatId;
      }).toList();

      for (final key in keysToDelete) {
        await box.delete(key);
      }

      // Son 50 mesajı al
      final messagesToCache = messages.length > _maxCachedMessagesPerChat
          ? messages.sublist(messages.length - _maxCachedMessagesPerChat)
          : messages;

      // Yeni mesajları ekle
      for (final message in messagesToCache) {
        final cached = CachedMessage.fromMessage(message, chatId);
        // Unique key: chatId_messageId
        await box.put('${chatId}_${message.id}', cached);
      }

      debugPrint('MessageCacheService: Cached ${messagesToCache.length} messages for chat $chatId');
    } catch (e) {
      debugPrint('MessageCacheService: Error caching messages: $e');
    }
  }

  /// Tek bir mesajı önbelleğe ekle veya güncelle
  ///
  /// Yeni mesaj geldiğinde tüm cache'i yeniden yazmak yerine
  /// sadece yeni mesajı ekler (performans optimizasyonu)
  Future<void> addOrUpdateMessage(String chatId, Message message) async {
    try {
      final box = await _getBox();
      final key = '${chatId}_${message.id}';

      // Mevcut mesajı kontrol et - sadece değişiklik varsa güncelle
      final existing = box.get(key);
      if (existing != null) {
        // isRead durumu değiştiyse güncelle
        if (existing.isRead != message.isRead) {
          final updated = CachedMessage.fromMessage(message, chatId);
          await box.put(key, updated);
          debugPrint('MessageCacheService: Updated isRead for message ${message.id}');
        }
        return; // Mesaj zaten var, tekrar ekleme
      }

      // Yeni mesaj ekle
      final cached = CachedMessage.fromMessage(message, chatId);
      await box.put(key, cached);

      // Cache limitini kontrol et ve eski mesajları temizle
      await _enforceLimit(chatId);

      debugPrint('MessageCacheService: Added message ${message.id}');
    } catch (e) {
      debugPrint('MessageCacheService: Error adding message: $e');
    }
  }

  /// Tek bir mesajın isRead durumunu güncelle (doğrudan key erişimi)
  ///
  /// [chatId] - Sohbet ID'si
  /// [messageId] - Mesaj ID'si
  /// [isRead] - Yeni okundu durumu
  /// [readAt] - Okunma zamanı (opsiyonel)
  Future<void> markMessageAsRead(String chatId, String messageId, {DateTime? readAt}) async {
    try {
      final box = await _getBox();
      final key = '${chatId}_$messageId';

      final existing = box.get(key);
      if (existing == null) return;

      // Zaten okunmuşsa tekrar güncelleme
      if (existing.isRead) return;

      // isRead durumunu güncelle
      final updated = CachedMessage(
        id: existing.id,
        chatId: existing.chatId,
        senderId: existing.senderId,
        text: existing.text,
        timestampMs: existing.timestampMs,
        typeIndex: existing.typeIndex,
        isRead: true,
        readAtMs: readAt?.millisecondsSinceEpoch,
      );

      await box.put(key, updated);
      debugPrint('MessageCacheService: Marked message $messageId as read');
    } catch (e) {
      debugPrint('MessageCacheService: Error marking message as read: $e');
    }
  }

  /// Bir sohbetteki tüm mesajları okundu olarak işaretle (batch update)
  ///
  /// markMessagesAsRead başarılı olduğunda çağrılır
  /// Sadece göndereni [excludeSenderId] olmayan mesajları günceller
  Future<void> markChatMessagesAsRead(String chatId, String excludeSenderId) async {
    try {
      final box = await _getBox();
      final now = DateTime.now().millisecondsSinceEpoch;
      int updatedCount = 0;

      // Bu chat'e ait mesajları bul ve güncelle
      for (final key in box.keys) {
        if (!key.toString().startsWith('${chatId}_')) continue;

        final msg = box.get(key);
        if (msg == null) continue;

        // Sadece karşı tarafın mesajlarını ve okunmamış olanları güncelle
        if (msg.senderId != excludeSenderId && !msg.isRead) {
          final updated = CachedMessage(
            id: msg.id,
            chatId: msg.chatId,
            senderId: msg.senderId,
            text: msg.text,
            timestampMs: msg.timestampMs,
            typeIndex: msg.typeIndex,
            isRead: true,
            readAtMs: now,
          );
          await box.put(key, updated);
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        debugPrint('MessageCacheService: Marked $updatedCount messages as read in chat $chatId');
      }
    } catch (e) {
      debugPrint('MessageCacheService: Error marking chat messages as read: $e');
    }
  }

  /// Firebase'den gelen mesajları Hive ile akıllı senkronize et
  ///
  /// - Yeni mesajları ekler
  /// - isRead durumu değişen mesajları günceller
  /// - Performans için sadece değişen kayıtları yazar
  Future<void> syncMessagesFromFirestore(String chatId, List<Message> firestoreMessages) async {
    if (firestoreMessages.isEmpty) return;

    try {
      final box = await _getBox();
      int addedCount = 0;
      int updatedCount = 0;

      for (final message in firestoreMessages) {
        final key = '${chatId}_${message.id}';
        final existing = box.get(key);

        if (existing == null) {
          // Yeni mesaj - ekle
          final cached = CachedMessage.fromMessage(message, chatId);
          await box.put(key, cached);
          addedCount++;
        } else if (existing.isRead != message.isRead) {
          // isRead durumu değişmiş - güncelle (mavi tik senkronizasyonu)
          final updated = CachedMessage.fromMessage(message, chatId);
          await box.put(key, updated);
          updatedCount++;
        }
        // Diğer durumlarda değişiklik yok, yazma işlemi yapma
      }

      // Cache limitini uygula
      await _enforceLimit(chatId);

      if (addedCount > 0 || updatedCount > 0) {
        debugPrint('MessageCacheService: Synced - Added: $addedCount, Updated isRead: $updatedCount');
      }
    } catch (e) {
      debugPrint('MessageCacheService: Error syncing messages: $e');
    }
  }

  /// Cache limitini uygula (eski mesajları sil)
  Future<void> _enforceLimit(String chatId) async {
    try {
      final box = await _getBox();

      // Bu chat'e ait mesajları al
      final chatMessages = <dynamic, CachedMessage>{};
      for (final key in box.keys) {
        final msg = box.get(key);
        if (msg?.chatId == chatId) {
          chatMessages[key] = msg!;
        }
      }

      // Limit aşılmışsa en eski mesajları sil
      if (chatMessages.length > _maxCachedMessagesPerChat) {
        final sortedEntries = chatMessages.entries.toList()
          ..sort((a, b) => b.value.timestampMs.compareTo(a.value.timestampMs));

        final keysToDelete = sortedEntries
            .skip(_maxCachedMessagesPerChat)
            .map((e) => e.key)
            .toList();

        for (final key in keysToDelete) {
          await box.delete(key);
        }

        debugPrint('MessageCacheService: Removed ${keysToDelete.length} old messages');
      }
    } catch (e) {
      debugPrint('MessageCacheService: Error enforcing limit: $e');
    }
  }

  /// Belirli bir sohbetin önbelleğini temizle
  Future<void> clearChatCache(String chatId) async {
    try {
      final box = await _getBox();

      final keysToDelete = box.keys.where((key) {
        final msg = box.get(key);
        return msg?.chatId == chatId;
      }).toList();

      for (final key in keysToDelete) {
        await box.delete(key);
      }

      debugPrint('MessageCacheService: Cleared cache for chat $chatId (${keysToDelete.length} messages)');
    } catch (e) {
      debugPrint('MessageCacheService: Error clearing chat cache: $e');
    }
  }

  /// Tüm mesaj önbelleğini temizle
  /// Kullanıcı çıkış yaptığında çağrılmalı
  Future<void> clearAllCache() async {
    try {
      final box = await _getBox();
      final count = box.length;
      await box.clear();
      debugPrint('MessageCacheService: Cleared all cache ($count messages)');
    } catch (e) {
      debugPrint('MessageCacheService: Error clearing all cache: $e');
    }
  }

  /// Box'ı kapat (uygulama kapanırken)
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
      _isInitialized = false;
      debugPrint('MessageCacheService: Box closed');
    }
  }

  /// Önbellek istatistikleri (debug için)
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final box = await _getBox();

      // Chat başına mesaj sayıları
      final chatCounts = <String, int>{};
      for (final msg in box.values) {
        chatCounts[msg.chatId] = (chatCounts[msg.chatId] ?? 0) + 1;
      }

      return {
        'totalMessages': box.length,
        'chatCount': chatCounts.length,
        'chats': chatCounts,
        'boxSizeBytes': await _getBoxSize(),
      };
    } catch (e) {
      debugPrint('MessageCacheService: Error getting stats: $e');
      return {};
    }
  }

  /// Box boyutunu hesapla (yaklaşık)
  Future<int> _getBoxSize() async {
    try {
      final box = await _getBox();
      int size = 0;
      for (final msg in box.values) {
        // Yaklaşık boyut hesaplama
        size += msg.id.length * 2;
        size += msg.chatId.length * 2;
        size += msg.senderId.length * 2;
        size += msg.text.length * 2;
        size += 8 + 4 + 1 + 8; // timestamps, typeIndex, isRead, readAt
      }
      return size;
    } catch (e) {
      return 0;
    }
  }

  /// Önbellek başlatıldı mı?
  bool get isInitialized => _isInitialized;
}
