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
  ///
  /// Returns: Mesaj listesi (en yeniden en eskiye sıralı) veya null
  Future<List<Message>?> getCachedMessages(String chatId, {int limit = _defaultFetchLimit}) async {
    try {
      final box = await _getBox();

      // Bu chat'e ait mesajları filtrele
      final chatMessages = box.values
          .where((msg) => msg.chatId == chatId)
          .toList();

      if (chatMessages.isEmpty) {
        debugPrint('MessageCacheService: No cached messages for chat $chatId');
        return null;
      }

      // Timestamp'e göre sırala (en yeni önce)
      chatMessages.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));

      // Limit uygula (RAM optimizasyonu)
      final limitedMessages = chatMessages.take(limit).toList();

      // Message modellerine dönüştür ve ters çevir (en eski önce - ListView için)
      final messages = limitedMessages.map((c) => c.toMessage()).toList().reversed.toList();

      debugPrint('MessageCacheService: Loaded ${messages.length} messages from cache for chat $chatId');
      return messages;
    } catch (e) {
      debugPrint('MessageCacheService: Error loading cache: $e');
      return null;
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
      final cached = CachedMessage.fromMessage(message, chatId);
      await box.put('${chatId}_${message.id}', cached);

      // Cache limitini kontrol et ve eski mesajları temizle
      await _enforceLimit(chatId);

      debugPrint('MessageCacheService: Added/updated message ${message.id}');
    } catch (e) {
      debugPrint('MessageCacheService: Error adding message: $e');
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
