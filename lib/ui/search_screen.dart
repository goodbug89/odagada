import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import '../saved/saved_place_repository.dart';
import 'login_sheet.dart';
import 'memo_sheet.dart';

/// 텍스트 검색으로 장소를 찾아 저장하는 화면.
class SearchScreen extends StatefulWidget {
  final Future<List<Poi>> Function(String query, LatLng? bias) textSearch;
  final LatLng? bias;
  final SavedPlaceRepository savedRepo;
  final AuthController auth;
  final Future<void> Function() onChanged; // 저장 후 지도 갱신용
  const SearchScreen({
    super.key,
    required this.textSearch,
    required this.bias,
    required this.savedRepo,
    required this.auth,
    required this.onChanged,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Poi> _results = const [];
  Set<String> _savedIds = {};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final u = widget.auth.user;
    if (u == null) return;
    final ids = await widget.savedRepo.savedPlaceIds(u.id);
    if (mounted) setState(() => _savedIds = ids);
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.textSearch(q, widget.bias);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _error = '검색에 실패했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(Poi poi) async {
    final u = widget.auth.user;
    if (u == null) {
      showLoginSheet(context, onGoogle: widget.auth.signInWithGoogle);
      return;
    }
    final memo = await showMemoSheet(context, placeName: poi.name);
    if (memo == null) return;
    await widget.savedRepo.save(
        ownerId: u.id, poi: poi, memo: memo.isEmpty ? null : memo);
    await _loadSaved();
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            hintText: '장소·가게 이름 검색',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24), child: Text(_error!)))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = _results[i];
                    final saved = _savedIds.contains(p.id);
                    return ListTile(
                      leading: Icon(p.bucket.icon, color: p.bucket.color),
                      title: Text(p.name),
                      subtitle: Text([
                        p.bucket.label,
                        if (p.address != null) p.address!,
                      ].join(' · ')),
                      trailing: saved
                          ? const Icon(Icons.bookmark, color: Color(0xFFFF5E13))
                          : TextButton(
                              onPressed: () => _save(p),
                              child: const Text('저장'),
                            ),
                    );
                  },
                ),
    );
  }
}
