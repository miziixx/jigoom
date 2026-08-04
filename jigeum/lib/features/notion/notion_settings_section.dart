import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/repos/notion_repository.dart';
import 'notion_controller.dart';

/// 설정 화면의 "Notion" 섹션 — 연결/해제 · 실시간 자동 공유 · 유형별 선택 · 지금 동기화.
/// gcal 의 [GcalSettingsSection] 을 본떠 만들었다.
class NotionSettingsSection extends ConsumerStatefulWidget {
  const NotionSettingsSection({super.key});

  @override
  ConsumerState<NotionSettingsSection> createState() =>
      _NotionSettingsSectionState();
}

class _NotionSettingsSectionState
    extends ConsumerState<NotionSettingsSection> {
  final _tokenCtrl = TextEditingController();
  final _pageCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final state = ref.watch(notionControllerProvider);
    final ctrl = ref.read(notionControllerProvider.notifier);

    if (!state.connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
            child: Text(
                '내 기록을 노션에 실시간으로 자동 공유해요. 노션에서 Internal Integration 을 '
                '만들고, 공유할 페이지를 그 integration 과 공유한 뒤 토큰과 페이지 주소를 붙여넣어 주세요.',
                style: AppText.body(tk.ink)),
          ),
          _field(tk, _tokenCtrl, '통합 토큰 (Integration Token)', 'secret_ 로 시작',
              obscure: true),
          _field(tk, _pageCtrl, '부모 페이지 주소 또는 ID', '노션 페이지 링크 붙여넣기'),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 0),
            child: _Btn(
              label: _busy ? '연결 중…' : '노션 연결 켜기',
              filled: true,
              onTap: _busy ? null : () => _connect(ctrl),
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
              child: Text(state.error!, style: AppText.meta(tk.mark, size: 12)),
            ),
        ],
      );
    }

    // 연결됨.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('노션 연결됨', style: AppText.body(tk.ink)),
                    const SizedBox(height: 2),
                    Text(
                      state.syncing
                          ? '동기화 중…'
                          : state.lastSyncAt == null
                              ? '아직 동기화 안 함'
                              : '마지막 동기화 ${_ago(state.lastSyncAt!)}',
                      style: AppText.meta(tk.inkSoft, size: 11),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => ctrl.disconnect(),
                behavior: HitTestBehavior.opaque,
                child: Text('연동 끄기', style: AppText.meta(tk.mark, size: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: _Btn(
            label: state.syncing ? '동기화 중…' : '지금 동기화',
            filled: false,
            onTap: state.syncing ? null : () => ctrl.syncNow(),
          ),
        ),
        // 실시간 자동 공유 토글.
        _toggleRow(
          tk,
          title: '실시간 자동 공유',
          sub: '기록이 바뀔 때마다 노션으로 자동으로 올려요.',
          value: state.autoShare,
          onChanged: ctrl.setAutoShare,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 4),
          child: Text('공유할 기록 종류',
              style: AppText.meta(tk.inkSoft, size: 11)
                  .copyWith(letterSpacing: 1.2)),
        ),
        for (final type in NotionSyncType.values)
          _toggleRow(
            tk,
            title: type.label,
            sub: null,
            value: state.enabled[type] ?? false,
            onChanged: (v) => ctrl.setTypeEnabled(type, v),
          ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
            child: Text(state.error!, style: AppText.meta(tk.mark, size: 12)),
          ),
      ],
    );
  }

  Future<void> _connect(NotionController ctrl) async {
    setState(() => _busy = true);
    final ok = await ctrl.connect(_tokenCtrl.text, _pageCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _tokenCtrl.clear();
      _pageCtrl.clear();
    }
  }

  Widget _field(AppTokens tk, TextEditingController c, String label, String hint,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.meta(tk.inkSoft, size: 11)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            obscureText: obscure,
            style: AppText.body(tk.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: AppText.meta(tk.inkSoft),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: tk.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: tk.ink, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(AppTokens tk,
      {required String title,
      required String? sub,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(tk.ink)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: AppText.meta(tk.inkSoft, size: 10)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '방금';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    return '${d.inDays}일 전';
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.filled, this.onTap});
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? tk.ink : Colors.transparent,
          border: Border.all(color: tk.ink, width: 1),
        ),
        child: Text(
          label,
          style: AppText.nav(filled ? tk.paper : tk.ink, active: true),
        ),
      ),
    );
  }
}
