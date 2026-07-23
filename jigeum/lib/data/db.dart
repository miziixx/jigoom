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
  // ADHD 개선(v6): 다음 시작점·실행의도·장애물 한 줄, 캡처된 집중세션 링크.
  TextColumn get nextStep => text().nullable()(); // 다음엔 어디부터
  TextColumn get triggerCondition => text().nullable()(); // "~하면 시작한다"
  TextColumn get obstacleNote => text().nullable()(); // 가장 망칠 위험
  TextColumn get focusSessionId => text().nullable()(); // 어느 집중세션 중 캡처됐나
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 집중 세션(적응형 타임박싱). plannedMinutes=null 이면 몰입모드(무제한).
class FocusSessions extends Table {
  TextColumn get id => text()(); // uuid v4
  TextColumn get nodeId => text().nullable()(); // 연결된 노드(없을 수 있음)
  IntColumn get plannedMinutes => integer().nullable()(); // null=몰입모드
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get actualSeconds => integer().withDefault(const Constant(0))();

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

/// 하루 일정 (일과). 시작·끝 시간이 있는 그날의 일정.
class Schedules extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()(); // 자정 기준 날짜
  TextColumn get title => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get color => integer().withDefault(const Constant(0))(); // 팔레트 index
  IntColumn get startMin => integer()(); // 0~1439 (하루 분 단위)
  IntColumn get endMin => integer()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  TextColumn get routineId => text().nullable()(); // 루틴에서 생성됐으면 그 id
  DateTimeColumn get createdAt => dateTime()();
  // ---- 구글 캘린더 동기화(v7) ----
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get gcalCalendarId => text().nullable()(); // 어느 구글 캘린더(종류)
  TextColumn get gcalId => text().nullable()(); // 원격 이벤트 id (연결됨)
  TextColumn get gcalEtag => text().nullable()(); // 충돌 감지용 etag
  BoolColumn get dirty =>
      boolean().withDefault(const Constant(false))(); // 원격에 밀어야 함
  BoolColumn get deleted =>
      boolean().withDefault(const Constant(false))(); // 삭제 툼스톤(동기화 전)
  DateTimeColumn get updatedAt => dateTime().nullable()(); // 로컬 최종 수정(LWW)

  @override
  Set<Column> get primaryKey => {id};
}

/// 루틴 블록(그룹) — 순서 있는 스텝 묶음. 예: "모닝 루틴".
class RoutineGroups extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get weekdays =>
      text().withDefault(const Constant('1,2,3,4,5,6,7'))(); // 1=월~7=일
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 루틴 스텝 — 블록 안의 한 줄. trigger("눈 뜨면"·"07:20")로 "뭐 다음에 뭐"를 잇는다.
/// 하루 체크는 lastDone(자정 기준)이 오늘이면 완료. streak=연속 일수(근사).
class RoutineSteps extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get trigger =>
      text().withDefault(const Constant(''))(); // "눈 뜨면"·"07:20"·""
  TextColumn get title => text()();
  IntColumn get streak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastDone => dateTime().nullable()(); // 마지막 완료(자정 기준)
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 사용자의 구글 캘린더 목록. selected=동기화 대상(종류별 선택).
class GcalCalendars extends Table {
  TextColumn get id => text()(); // 캘린더 id (primary / xxx@group.calendar…)
  TextColumn get summary => text()(); // 표시 이름
  TextColumn get colorHex =>
      text().withDefault(const Constant('#4A5A66'))(); // 구글 색
  BoolColumn get selected =>
      boolean().withDefault(const Constant(false))(); // 동기화 on/off
  BoolColumn get primaryCal =>
      boolean().withDefault(const Constant(false))(); // 주 캘린더
  TextColumn get accessRole =>
      text().withDefault(const Constant('reader'))(); // reader|writer|owner
  TextColumn get syncToken => text().nullable()(); // 증분 동기화 토큰

  @override
  Set<Column> get primaryKey => {id};
}

/// 타임트래커: 하루를 30분 단위(0~47)로 실제 한 일을 기록.
class TimeBlocks extends Table {
  DateTimeColumn get date => dateTime()(); // 자정 기준 날짜
  IntColumn get block => integer()(); // 0~47 (30분 단위)
  TextColumn get content => text()(); // 'text' 는 drift 빌더명과 충돌 → content

  @override
  Set<Column> get primaryKey => {date, block};
}

/// 루틴: 매일/요일 반복되는 일정 템플릿. 앱 열 때 오늘 일정으로 자동 생성.
class Routines extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get color => integer().withDefault(const Constant(0))();
  IntColumn get startMin => integer()();
  IntColumn get endMin => integer()();
  TextColumn get weekdays =>
      text().withDefault(const Constant('1,2,3,4,5,6,7'))(); // 1=월 ~ 7=일
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Nodes,
  Settings,
  Habits,
  HabitTicks,
  Schedules,
  Routines,
  TimeBlocks,
  FocusSessions,
  GcalCalendars,
  RoutineGroups,
  RoutineSteps
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 8;

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
          if (from < 4) {
            await m.createTable(schedules);
            await m.createTable(routines);
          }
          if (from < 5) {
            await m.createTable(timeBlocks);
          }
          if (from < 6) {
            await m.addColumn(nodes, nodes.nextStep);
            await m.addColumn(nodes, nodes.triggerCondition);
            await m.addColumn(nodes, nodes.obstacleNote);
            await m.addColumn(nodes, nodes.focusSessionId);
            await m.createTable(focusSessions);
          }
          if (from < 7) {
            await m.addColumn(schedules, schedules.allDay);
            await m.addColumn(schedules, schedules.gcalCalendarId);
            await m.addColumn(schedules, schedules.gcalId);
            await m.addColumn(schedules, schedules.gcalEtag);
            await m.addColumn(schedules, schedules.dirty);
            await m.addColumn(schedules, schedules.deleted);
            await m.addColumn(schedules, schedules.updatedAt);
            await m.createTable(gcalCalendars);
          }
          if (from < 8) {
            await m.createTable(routineGroups);
            await m.createTable(routineSteps);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'jigeum_db');
  }
}
