import 'package:hive/hive.dart';
import 'chat.dart';

/// Hive TypeAdapter ID'leri
/// Her adapter için benzersiz bir ID gerekli
class HiveTypeIds {
  static const int cachedMessage = 0;
  static const int messageType = 1;
}

/// MessageType enum için Hive TypeAdapter
class MessageTypeAdapter extends TypeAdapter<MessageType> {
  @override
  final int typeId = HiveTypeIds.messageType;

  @override
  MessageType read(BinaryReader reader) {
    final index = reader.readByte();
    return MessageType.values[index];
  }

  @override
  void write(BinaryWriter writer, MessageType obj) {
    writer.writeByte(obj.index);
  }
}

/// Önbelleklenmiş mesaj modeli
/// Hive için optimize edilmiş, Message modelinden dönüştürülür
@HiveType(typeId: HiveTypeIds.cachedMessage)
class CachedMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String chatId;

  @HiveField(2)
  final String senderId;

  @HiveField(3)
  final String text;

  @HiveField(4)
  final int timestampMs;

  @HiveField(5)
  final int typeIndex;

  @HiveField(6)
  final bool isRead;

  @HiveField(7)
  final int? readAtMs;

  CachedMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestampMs,
    required this.typeIndex,
    required this.isRead,
    this.readAtMs,
  });

  /// Message modelinden CachedMessage oluştur
  factory CachedMessage.fromMessage(Message message, String chatId) {
    return CachedMessage(
      id: message.id,
      chatId: chatId,
      senderId: message.senderId,
      text: message.text,
      timestampMs: message.timestamp.millisecondsSinceEpoch,
      typeIndex: message.type.index,
      isRead: message.isRead,
      readAtMs: message.readAt?.millisecondsSinceEpoch,
    );
  }

  /// CachedMessage'dan Message modeline dönüştür
  Message toMessage() {
    return Message(
      id: id,
      senderId: senderId,
      text: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      type: MessageType.values[typeIndex],
      isRead: isRead,
      readAt: readAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(readAtMs!)
          : null,
    );
  }
}

/// CachedMessage için manuel TypeAdapter
/// build_runner kullanmadan elle yazıldı
class CachedMessageAdapter extends TypeAdapter<CachedMessage> {
  @override
  final int typeId = HiveTypeIds.cachedMessage;

  @override
  CachedMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return CachedMessage(
      id: fields[0] as String,
      chatId: fields[1] as String,
      senderId: fields[2] as String,
      text: fields[3] as String,
      timestampMs: fields[4] as int,
      typeIndex: fields[5] as int,
      isRead: fields[6] as bool,
      readAtMs: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CachedMessage obj) {
    writer
      ..writeByte(8) // field sayısı
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chatId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.text)
      ..writeByte(4)
      ..write(obj.timestampMs)
      ..writeByte(5)
      ..write(obj.typeIndex)
      ..writeByte(6)
      ..write(obj.isRead)
      ..writeByte(7)
      ..write(obj.readAtMs);
  }
}
