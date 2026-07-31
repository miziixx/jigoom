/// 아웃라인 독립 화면 — eyebrow 마스트헤드 + 본문 [OutlineView].
/// +폴더·+목표는 본문의 '§ 폴더와 목표' 헤더에 있다.
library;

import 'package:flutter/material.dart';

import '../../core/journal.dart';
import '../../core/theme.dart';
import '../shell/app_bottom_nav.dart';
import '../shell/app_drawer.dart';
import 'outline_view.dart';

class OutlineScreen extends StatelessWidget {
  const OutlineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Scaffold(
      backgroundColor: tk.paper,
      endDrawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Masthead(
                eyebrow: 'OUTLINE',
                title: '아웃라인',
                onBack: () => Navigator.of(context).pop(),
                showMenu: true),
            const Expanded(child: OutlineView()),
            const AppBottomNav(),
          ],
        ),
      ),
    );
  }
}
