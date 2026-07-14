/// 앱 내부에서 쓰는 로그인 사용자 표현(Supabase User와 분리).
class AppUser {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  const AppUser({required this.id, this.displayName, this.avatarUrl});
}

/// Supabase user id + userMetadata를 AppUser로 변환(순수).
AppUser appUserFrom(String id, Map<String, dynamic>? metadata) {
  final m = metadata ?? const {};
  return AppUser(
    id: id,
    displayName: (m['full_name'] ?? m['name']) as String?,
    avatarUrl: m['avatar_url'] as String?,
  );
}
