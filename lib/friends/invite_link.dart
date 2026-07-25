// lib/friends/invite_link.dart

import '../core/constants.dart';

/// 초대 링크 형식과 파싱.
/// 기본은 https App Link(메신저에서 탭 가능·앱 없으면 안내 페이지),
/// 커스텀 스킴은 폴백 페이지의 "앱에서 열기"와 기존 공유 링크 하위호환용.
const String inviteLinkHost = 'goodbug89.github.io';
const String inviteLinkPathPrefix = '/invite';
const String inviteLegacyScheme = appUriScheme;
const String _tokenParam = 't';

/// 공유용 초대 링크.
String buildInviteLink(String token) =>
    'https://$inviteLinkHost$inviteLinkPathPrefix/?$_tokenParam=$token';

/// URI가 초대 링크면 토큰을, 아니면 null.
/// 초대가 아닌 URI(로그인 콜백 등)에는 반드시 null을 돌려준다.
String? inviteTokenFromUri(Uri uri) {
  if (uri.scheme == 'https' &&
      uri.host == inviteLinkHost &&
      uri.path.startsWith(inviteLinkPathPrefix)) {
    final t = uri.queryParameters[_tokenParam];
    return (t == null || t.isEmpty) ? null : t;
  }
  if (uri.scheme == inviteLegacyScheme && uri.host == 'invite') {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return segs.isEmpty ? null : segs.first;
  }
  return null;
}
