import 'package:flutter/material.dart';

/// 저장·표시용 7종 카테고리 큰 묶음.
/// 색=종류(지도에서 색으로 종류 구분), 아이콘=종류. (spec §7.7)
enum PlaceCategory {
  restaurant('맛집', Color(0xFFFF7A2F), Icons.restaurant),
  cafe('카페·디저트', Color(0xFFB07A4E), Icons.local_cafe),
  bar('술집·바', Color(0xFF8E3B7A), Icons.local_bar),
  attraction('명소·뷰', Color(0xFF3E9E5B), Icons.park),
  shopping('쇼핑', Color(0xFF2E7DF6), Icons.shopping_bag),
  activity('액티비티·체험', Color(0xFF7A5AE0), Icons.local_activity),
  other('기타', Color(0xFF9AA0A6), Icons.place);

  final String label;
  final Color color;
  final IconData icon;
  const PlaceCategory(this.label, this.color, this.icon);

  /// enum id(name)로 역매핑. 미지/누락은 기타.
  static PlaceCategory fromId(String? id) =>
      values.firstWhere((e) => e.name == id, orElse: () => PlaceCategory.other);

  /// Google Places(New) primaryType 코드를 7종으로 매핑. 미지/누락은 기타.
  /// 구체 종류(카페/술집/명소/쇼핑/액티비티)를 먼저 판정하고,
  /// 광범위한 restaurant(및 `*_restaurant`)는 마지막에 판정한다.
  static PlaceCategory fromGooglePrimaryType(String? primaryType) {
    final t = primaryType?.toLowerCase() ?? '';
    if (t.isEmpty) return PlaceCategory.other;
    if (_cafe.contains(t)) return PlaceCategory.cafe;
    if (_bar.contains(t)) return PlaceCategory.bar;
    if (_attraction.contains(t)) return PlaceCategory.attraction;
    if (_shopping.contains(t) || t.endsWith('_store')) return PlaceCategory.shopping;
    if (_activity.contains(t)) return PlaceCategory.activity;
    if (_restaurant.contains(t) || t.endsWith('_restaurant')) {
      return PlaceCategory.restaurant;
    }
    return PlaceCategory.other;
  }

  static const _restaurant = {
    'restaurant', 'food', 'meal_takeaway', 'meal_delivery',
    'diner', 'buffet_restaurant', 'food_court',
  };
  static const _cafe = {
    'cafe', 'coffee_shop', 'bakery', 'dessert_shop', 'ice_cream_shop',
    'tea_house', 'bagel_shop', 'donut_shop', 'dessert_restaurant',
  };
  static const _bar = {
    'bar', 'pub', 'wine_bar', 'night_club', 'bar_and_grill',
  };
  static const _attraction = {
    'tourist_attraction', 'park', 'national_park', 'museum', 'art_gallery',
    'historical_landmark', 'historical_place', 'plaza', 'garden',
    'observation_deck', 'monument',
  };
  static const _shopping = {
    'store', 'shopping_mall', 'department_store', 'supermarket',
    'convenience_store', 'market', 'grocery_store',
  };
  static const _activity = {
    'movie_theater', 'amusement_park', 'bowling_alley', 'gym', 'spa',
    'zoo', 'aquarium', 'stadium', 'water_park', 'sports_complex', 'arcade',
  };
}
