import 'package:flutter/material.dart';
import '../core/models/poi.dart';

const double _dotSize = 30;
const double _headSize = 40;

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

/// 내 저장 장소: 카테고리색 핀 머리 + 꼬리 + 흰 북마크 배지 + 이름 굵게.
/// 앵커: 머리 중심 x, 꼬리 끝(상단에서 46px)이 기준점.
class SavedPin extends StatelessWidget {
  final Poi poi;
  final VoidCallback onTap;
  const SavedPin({super.key, required this.poi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = poi.bucket;
    return GestureDetector(
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
                Container(
                  width: _headSize,
                  height: _headSize,
                  decoration: BoxDecoration(
                    color: c.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x55000000), blurRadius: 5, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Icon(c.icon, color: Colors.white, size: 20),
                ),
                Positioned(
                  right: 0,
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
              ],
            ),
          ),
          Container(width: 3, height: 6, color: c.color), // 꼬리(끝=상단 46px)
          const SizedBox(height: 2),
          // 이름 라벨이 머리(44px)보다 넓어도 Column 폭을 넓히지 않게 고정 슬롯 안에서
          // 중앙 정렬로 넘치게 한다 → 머리 중심이 기준점(s.dx)에서 밀리지 않음.
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

/// 흰 배경 이름 라벨(가독성). 지도 오버레이에서 폭 제한으로 오버플로 방지.
class _NameLabel extends StatelessWidget {
  final String text;
  final bool bold;
  const _NameLabel({required this.text, required this.bold});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: const Color(0xFF333333),
          ),
        ),
      ),
    );
  }
}
