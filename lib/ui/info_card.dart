import 'package:flutter/material.dart';
import '../core/models/poi.dart';

/// 핀 탭 시 하단에 뜨는 정보 카드. 운전 중 가독성 위해 큰 글씨.
class InfoCard extends StatelessWidget {
  final Poi poi;
  final VoidCallback onNavigate;
  final bool isSaved;
  final VoidCallback onSave;
  const InfoCard({
    super.key,
    required this.poi,
    required this.onNavigate,
    this.isSaved = false,
    required this.onSave,
  });

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
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_distanceText · ${poi.category}',
                style: const TextStyle(fontSize: 18, color: Colors.black54)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSave,
                    icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                    label: Text(isSaved ? '저장됨' : '저장',
                        style: const TextStyle(fontSize: 18)),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onNavigate,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56)),
                    child: const Text('길찾기',
                        style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
