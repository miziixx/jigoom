import 'package:flutter/material.dart';

/// 간격 토큰 (4px 리듬 + 편집 레이아웃 상수). DESIGN_SYSTEM §2.
class AppSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s8 = 48.0;

  /// 편집 gutter — 화면 좌우 여백. 잡지 마진의 시그니처. (22px)
  static const gutter = 22.0;
}

/// 각진 모서리가 편집 시그니처. (DESIGN_SYSTEM §4)
const double kRadius = 0.0;

/// 라벨·기호·영문·숫자용 모노스페이스. (JetBrains Mono 미번들 → generic monospace)
const kMonoFamily = 'monospace';

/// 한글 본문·제목용 산세리프. null = 기기 기본 글꼴(삼성 One UI 등).
const String? kSansFamily = null;

const kAnimDuration = Duration(milliseconds: 160);
const kAnimCurve = Curves.easeOut;

/// 굵기 조절: FontWeight 을 delta 만큼 이동 (w400=index3 기준).
FontWeight shiftWeight(FontWeight base, int delta) {
  const order = [
    FontWeight.w100,
    FontWeight.w200,
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
    FontWeight.w900,
  ];
  final i = (order.indexOf(base) + delta).clamp(0, order.length - 1);
  return order[i];
}

/// 노드 타입
class NodeType {
  static const goal = 'goal';
  static const task = 'task';
  static const memo = 'memo';
  static const folder = 'folder'; // 카테고리/폴더
}

/// 노드 상태
class NodeStatus {
  static const open = 'open';
  static const done = 'done';
  static const drawer = 'drawer';
}

/// 하루의 구간 (오전/오후/저녁)
class Slot {
  static const am = 'am';
  static const pm = 'pm';
  static const eve = 'eve';

  static const all = [am, pm, eve];

  static String label(String slot) {
    switch (slot) {
      case am:
        return '오전';
      case pm:
        return '오후';
      case eve:
        return '저녁';
      default:
        return '';
    }
  }
}

/// 날짜 유틸: 자정 기준 날짜만 남김.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime todayDate() => dateOnly(DateTime.now());
