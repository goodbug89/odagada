import 'package:flutter/material.dart';
import '../core/models/poi.dart';

const double _dotSize = 30;
const double _headSize = 40;
const Color _friendBlue = Color(0xFF1B4F9B);

/// 미저장 주변 장소: 작은 카테고리색 원형 아이콘 + 이름 라벨.
/// 앵커: 원 중심이 기준점.
class CategoryDot extends StatelessWidget {
  final Poi poi;
  final VoidCallback onTap;
  const CategoryDot({super.key, required this.poi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = poi.bucket;
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 아이콘·이름 사이 여백도 탭 되게(마커 탭 관대하게)
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              color: c.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
            child: Icon(c.icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 4),
          _NameLabel(text: poi.name, bold: false),
        ],
      ),
    );
  }
}

/// 저장/친구 상태를 표현하는 핀. saved=내 저장(북마크), friendCount>0=친구 수(파란 배지),
/// 둘 다=겹침(링 강조). 앵커: 머리 중심 x, 꼬리 끝(상단 46px)이 기준점.
class PlacePin extends StatelessWidget {
  final Poi poi;
  final bool saved;
  final int friendCount;
  final VoidCallback onTap;
  const PlacePin({
    super.key,
    required this.poi,
    required this.saved,
    required this.friendCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = poi.bucket;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: _headSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 겹침 링(오버플로) — 머리 뒤 파란 테두리 원 + 글로우로 강조("최강 신뢰 신호").
                if (saved && friendCount > 0)
                  Container(
                    key: const ValueKey('overlap-ring'),
                    width: _headSize + 16,
                    height: _headSize + 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _friendBlue, width: 4),
                      boxShadow: [
                        BoxShadow(
                            color: _friendBlue.withValues(alpha: 0.55),
                            blurRadius: 8),
                      ],
                    ),
                  ),
                // 머리
                Container(
                  width: _headSize,
                  height: _headSize,
                  decoration: BoxDecoration(
                    color: c.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 5,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Icon(c.icon, color: Colors.white, size: 20),
                ),
                // 내 저장 북마크(우상단)
                if (saved)
                  Positioned(
                    right: -1,
                    top: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.color, width: 1.5),
                      ),
                      child: Icon(Icons.bookmark, size: 10, color: c.color),
                    ),
                  ),
                // 친구 수 파란 배지(좌상단)
                if (friendCount > 0)
                  Positioned(
                    left: -4,
                    top: -4,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _friendBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text('$friendCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          Container(width: 3, height: 6, color: c.color),
          const SizedBox(height: 2),
          SizedBox(
            width: 44,
            child: LimitedBox(
              maxHeight: 30,
              child: OverflowBox(
                minWidth: 0,
                maxWidth: 120,
                alignment: Alignment.topCenter,
                child: _NameLabel(text: poi.name, bold: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 투명 배경 이름 라벨. 지도 위에서 묻히지 않게 흰 외곽선(헤일로)으로 가독성 확보
/// (구글 지도 라벨 방식). 폭 제한으로 오버플로 방지.
class _NameLabel extends StatelessWidget {
  final String text;
  final bool bold;
  const _NameLabel({required this.text, required this.bold});

  // 텍스트 사방에 흰 그림자를 겹쳐 외곽선처럼 보이게 한다.
  static const List<Shadow> _halo = [
    Shadow(color: Colors.white, blurRadius: 2, offset: Offset(0.8, 0)),
    Shadow(color: Colors.white, blurRadius: 2, offset: Offset(-0.8, 0)),
    Shadow(color: Colors.white, blurRadius: 2, offset: Offset(0, 0.8)),
    Shadow(color: Colors.white, blurRadius: 2, offset: Offset(0, -0.8)),
    Shadow(color: Colors.white, blurRadius: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: const Color(0xFF222222),
          shadows: _halo,
        ),
      ),
    );
  }
}
