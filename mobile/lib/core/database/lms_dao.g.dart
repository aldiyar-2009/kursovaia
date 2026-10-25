// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lms_dao.dart';

// ignore_for_file: type=lint
mixin _$LmsDaoMixin on DatabaseAccessor<AppDatabase> {
  $LmsCoursesTable get lmsCourses => attachedDatabase.lmsCourses;
  $LmsEventsTable get lmsEvents => attachedDatabase.lmsEvents;
  $LmsMaterialsTable get lmsMaterials => attachedDatabase.lmsMaterials;
  LmsDaoManager get managers => LmsDaoManager(this);
}

class LmsDaoManager {
  final _$LmsDaoMixin _db;
  LmsDaoManager(this._db);
  $$LmsCoursesTableTableManager get lmsCourses =>
      $$LmsCoursesTableTableManager(_db.attachedDatabase, _db.lmsCourses);
  $$LmsEventsTableTableManager get lmsEvents =>
      $$LmsEventsTableTableManager(_db.attachedDatabase, _db.lmsEvents);
  $$LmsMaterialsTableTableManager get lmsMaterials =>
      $$LmsMaterialsTableTableManager(_db.attachedDatabase, _db.lmsMaterials);
}
