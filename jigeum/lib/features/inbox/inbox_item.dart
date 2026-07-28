/// 보류함 항목. 기획서 §7 데이터 모델 + §5 커밋9.
///
/// 음성 인텐트를 못 잡았거나(S==0) 되돌리기로 되돌아온 **원문**을 담는다.
/// "사용자의 말은 절대 버리지 않는다"(§0)의 저장소.
///
/// 프레임워크 비의존(순수 Dart) — 저장 계층과 무관하게 단위 테스트된다.
library;

/// 보류함 항목의 상태.
enum InboxStatus {
  /// 아직 정리 안 됨(기본).
  pending('pending'),

  /// 다른 입력지점(A~J)으로 재분류돼 처리됨.
  reclassified('reclassified'),

  /// 사용자가 버림(무시).
  dismissed('dismissed');

  const InboxStatus(this.code);

  /// 직렬화·로그용 코드.
  final String code;

  static InboxStatus fromCode(String code) =>
      InboxStatus.values.firstWhere((s) => s.code == code,
          orElse: () => InboxStatus.pending);
}

/// 보류함 한 건(§7).
class InboxItem {
  const InboxItem({
    required this.id,
    required this.rawText,
    required this.createdAt,
    this.sttConfidence,
    this.status = InboxStatus.pending,
  });

  /// 고유 식별자.
  final String id;

  /// 사용자가 말한 원문 그대로(정규화 이전).
  final String rawText;

  /// 생성 시각.
  final DateTime createdAt;

  /// STT 신뢰도(참고용). 없으면 null.
  final double? sttConfidence;

  /// 현재 상태.
  final InboxStatus status;

  InboxItem copyWith({InboxStatus? status}) => InboxItem(
        id: id,
        rawText: rawText,
        createdAt: createdAt,
        sttConfidence: sttConfidence,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawText': rawText,
        'createdAt': createdAt.toIso8601String(),
        'sttConfidence': sttConfidence,
        'status': status.code,
      };

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: json['id'] as String,
        rawText: json['rawText'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        sttConfidence: (json['sttConfidence'] as num?)?.toDouble(),
        status: InboxStatus.fromCode(json['status'] as String? ?? 'pending'),
      );

  @override
  String toString() =>
      'InboxItem($id, "${rawText.length > 12 ? '${rawText.substring(0, 12)}…' : rawText}", ${status.code})';
}
