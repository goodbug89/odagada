import 'package:flutter/material.dart';
import '../poi/poi_provider.dart';

/// 활성 모듈 선택 화면. MVP는 맛집만 노출(항상 켜짐), 구조는 다중 대비.
class ModuleSelector extends StatelessWidget {
  final ProviderRegistry registry;
  const ModuleSelector({super.key, required this.registry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('모듈 선택')),
      body: ListView(
        children: registry.all
            .map((p) => SwitchListTile(
                  title: Text(p.displayName),
                  value: true,
                  onChanged: null, // MVP: 맛집 고정. v2에서 토글 가능.
                ))
            .toList(),
      ),
    );
  }
}
