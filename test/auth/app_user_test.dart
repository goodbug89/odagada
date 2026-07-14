import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/auth/app_user.dart';

void main() {
  test('full_name과 avatar_url을 매핑한다', () {
    final u = appUserFrom('uid-1', {
      'full_name': '홍길동',
      'avatar_url': 'https://img/a.png',
    });
    expect(u.id, 'uid-1');
    expect(u.displayName, '홍길동');
    expect(u.avatarUrl, 'https://img/a.png');
  });

  test('full_name이 없으면 name을 쓴다', () {
    final u = appUserFrom('uid-2', {'name': 'Gildong'});
    expect(u.displayName, 'Gildong');
  });

  test('metadata가 null이면 표시명/아바타는 null', () {
    final u = appUserFrom('uid-3', null);
    expect(u.id, 'uid-3');
    expect(u.displayName, isNull);
    expect(u.avatarUrl, isNull);
  });
}
