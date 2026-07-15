import 'package:flutter/material.dart';
import '../core/models/poi.dart';

/// 핀 탭 시 하단에 뜨는 정보 카드. 운전 중 가독성 위해 큰 글씨. 내용이 길면 스크롤.
class InfoCard extends StatelessWidget {
  final Poi poi;
  final VoidCallback onNavigate;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onClose;
  const InfoCard({
    super.key,
    required this.poi,
    required this.onNavigate,
    this.isSaved = false,
    required this.onSave,
    required this.onClose,
  });

  String get _distanceText {
    final d = poi.distanceMeters;
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}km';
    return '${d.round()}m';
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 내비게이션 바(제스처/버튼) 높이만큼 카드를 위로 띄워 겹침 방지.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Card(
      margin: EdgeInsets.only(
          left: 12, right: 12, top: 12, bottom: 12 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(poi.name,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '닫기',
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(children: [
                Icon(poi.bucket.icon, size: 18, color: poi.bucket.color),
                const SizedBox(width: 6),
                Text('$_distanceText · ${poi.bucket.label}',
                    style: const TextStyle(fontSize: 18, color: Colors.black54)),
              ]),
              if (poi.openNow != null) ...[
                const SizedBox(height: 8),
                _OpenBadge(open: poi.openNow!),
              ],
              if (poi.address != null && poi.address!.isNotEmpty)
                _InfoRow(icon: Icons.place_outlined, text: poi.address!),
              if (poi.phone != null && poi.phone!.isNotEmpty)
                _InfoRow(icon: Icons.phone_outlined, text: poi.phone!),
              if (poi.weekdayHours != null && poi.weekdayHours!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('영업시간',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...poi.weekdayHours!.map((h) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(h,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54)),
                    )),
              ],
              const SizedBox(height: 16),
              Row(children: [
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
                    child:
                        const Text('길찾기', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16))),
      ]),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  final bool open;
  const _OpenBadge({required this.open});
  @override
  Widget build(BuildContext context) {
    final color = open ? Colors.green : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(open ? '영업 중' : '영업 종료',
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
