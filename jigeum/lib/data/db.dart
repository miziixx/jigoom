import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'db.g.dart';

class Nodes extends Table {
  TextColumn get id => text()(); // uuid v4
  TextColumn get parentId => text().nullable()();
  IntColumn get sortOrder => integer()();
  TextColumn get type => text()(); // goal | task | memo
  TextColumn get title => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get important => boolean().withDefault(const Constant(false))();
  BoolColumn get urgent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get slot => text().nullable()(); // am | pm | eve
  TextColumn get status =>
      text().withDefault(const Constant('open'))(); // open|done|drawer
  DateTimeColumn get doneAt => dateTime().nullable()();
  IntColumn get carriedCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// key-value 설정 저장 (마지막 이월일, Q2 승격일 등).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 습관 (해빗 트래커).
class Habits extends Table {
  TextColumn get id => text()(); // uuid v4
  TextColumn get title => text()();
  TextColumn get category => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 습관 체크 기록: 하루 1개 (habitId + date 유니크).
class HabitTicks extends Table {
  TextColumn get habitId => text()();
  DateTimeColumn get date => dateTime()(); // 자정 기준 날짜만

  @override
  Set<Column> get primaryKey => {habitId, date};
}

@DriftDatabase(tables: [Nodes, Settings, Habits, HabitTicks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_nodes_parent ON nodes(parent_id)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_nodes_date_status ON nodes(date, status)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_nodes_matrix ON nodes(important, urgent, status)');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(habits);
            await m.createTable(habitTicks);
          }
          if (from == 2) {
            await m.addColumn(habits, habits.category);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'jigeum_db');
  }
}
