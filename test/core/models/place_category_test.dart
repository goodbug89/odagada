import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/place_category.dart';

void main() {
  group('fromGooglePrimaryType', () {
    test('음식점류 → restaurant', () {
      expect(PlaceCategory.fromGooglePrimaryType('restaurant'), PlaceCategory.restaurant);
      expect(PlaceCategory.fromGooglePrimaryType('korean_restaurant'), PlaceCategory.restaurant);
      expect(PlaceCategory.fromGooglePrimaryType('fast_food_restaurant'), PlaceCategory.restaurant);
    });
    test('카페·베이커리 → cafe', () {
      expect(PlaceCategory.fromGooglePrimaryType('cafe'), PlaceCategory.cafe);
      expect(PlaceCategory.fromGooglePrimaryType('coffee_shop'), PlaceCategory.cafe);
      expect(PlaceCategory.fromGooglePrimaryType('bakery'), PlaceCategory.cafe);
    });
    test('술집류 → bar', () {
      expect(PlaceCategory.fromGooglePrimaryType('bar'), PlaceCategory.bar);
      expect(PlaceCategory.fromGooglePrimaryType('night_club'), PlaceCategory.bar);
    });
    test('명소류 → attraction', () {
      expect(PlaceCategory.fromGooglePrimaryType('park'), PlaceCategory.attraction);
      expect(PlaceCategory.fromGooglePrimaryType('tourist_attraction'), PlaceCategory.attraction);
      expect(PlaceCategory.fromGooglePrimaryType('museum'), PlaceCategory.attraction);
    });
    test('쇼핑류 → shopping (집합 + _store 접미사)', () {
      expect(PlaceCategory.fromGooglePrimaryType('shopping_mall'), PlaceCategory.shopping);
      expect(PlaceCategory.fromGooglePrimaryType('clothing_store'), PlaceCategory.shopping);
      expect(PlaceCategory.fromGooglePrimaryType('jewelry_store'), PlaceCategory.shopping);
    });
    test('액티비티류 → activity', () {
      expect(PlaceCategory.fromGooglePrimaryType('movie_theater'), PlaceCategory.activity);
      expect(PlaceCategory.fromGooglePrimaryType('amusement_park'), PlaceCategory.activity);
    });
    test('미지·null → other', () {
      expect(PlaceCategory.fromGooglePrimaryType(null), PlaceCategory.other);
      expect(PlaceCategory.fromGooglePrimaryType(''), PlaceCategory.other);
      expect(PlaceCategory.fromGooglePrimaryType('church'), PlaceCategory.other);
    });
  });

  test('각 카테고리는 라벨·색·아이콘을 갖는다', () {
    expect(PlaceCategory.cafe.label, '카페·디저트');
    expect(PlaceCategory.cafe.color, const Color(0xFFB07A4E));
    expect(PlaceCategory.cafe.icon, Icons.local_cafe);
    expect(PlaceCategory.restaurant.color, const Color(0xFFFF7A2F));
  });
}
