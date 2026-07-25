import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import 'app_user.dart';

/// Supabase Auth를 앱 모델(AppUser)로 노출하는 얇은 컨트롤러.
class AuthController extends ChangeNotifier {
  final SupabaseClient _client;
  StreamSubscription<AuthState>? _sub;
  AppUser? _user;

  AuthController([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client {
    _user = _mapCurrent();
    _sub = _client.auth.onAuthStateChange.listen((_) {
      _user = _mapCurrent();
      notifyListeners();
    });
  }

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;

  AppUser? _mapCurrent() {
    final u = _client.auth.currentUser;
    return u == null ? null : appUserFrom(u.id, u.userMetadata);
  }

  /// 구글 OAuth 로그인. 모바일은 딥링크 콜백으로 복귀, 웹은 리다이렉트.
  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo:
          kIsWeb ? null : '$appUriScheme://login-callback/',
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
