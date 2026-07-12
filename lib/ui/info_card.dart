import 'package:flutter/material.dart';
import '../core/models/poi.dart';

/// 핀 탭 시 하단에 뜨는 정보 카드. 운전 중 가독성 위해 큰 글씨/버튼 1개.
class InfoCard extends StatelessWidget {
  final Poi poi;
  final VoidCallback onNavigate;
  const InfoCard({super.key, required this.poi, required this.onNavigate});

  String get _distanceText {
    final d = poi.distanceMeters;
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}km';
    return '${d.round()}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poi.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_distanceText · ${poi.category}',
                style: const TextStyle(fontSize: 18, color: Colors.black54)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: onNavigate,
                child: const Text('길찾기', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
