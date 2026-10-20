import 'package:drift/drift.dart';
import 'package:studyplan/core/database/app_database.dart';

class ChatDao {
  final AppDatabase db;
  ChatDao(this.db);

  Stream<List<ChatMessage>> watchMessages(String groupId) {
    return (db.select(db.chatMessages)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<void> insertMessage(ChatMessagesCompanion message) {
    return db.into(db.chatMessages).insertOnConflictUpdate(message);
  }

  Future<void> markMessageSynced(String id) {
    return (db.update(db.chatMessages)..where((t) => t.id.equals(id))).write(
      const ChatMessagesCompanion(syncStatus: Value('synced')),
    );
  }
}
