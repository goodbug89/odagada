import 'package:flutter/material.dart';
import '../saved/saved_place.dart';
import '../saved/saved_place_repository.dart';

/// 내 저장 목록 화면.
class SavedListScreen extends StatefulWidget {
  final SavedPlaceRepository repo;
  final String ownerId;
  const SavedListScreen({super.key, required this.repo, required this.ownerId});

  @override
  State<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends State<SavedListScreen> {
  late Future<List<SavedPlace>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.listMine(widget.ownerId);
  }

  void _reload() {
    // 블록 본문 필수: 화살표는 대입식(Future)을 반환해 setState가 거부한다.
    setState(() {
      _future = widget.repo.listMine(widget.ownerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 저장')),
      body: FutureBuilder<List<SavedPlace>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('저장 목록을 불러오지 못했어요.\n잠시 후 다시 시도해 주세요.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('아직 저장한 곳이 없어요.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = items[i];
              return ListTile(
                leading: Icon(p.bucket.icon, color: p.bucket.color),
                title: Text(p.name),
                subtitle: Text([
                  p.bucket.label,
                  if (p.memo != null && p.memo!.isNotEmpty) p.memo!,
                ].join(' · ')),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (p.placeId != null) {
                      await widget.repo.deleteByPlaceId(
                          ownerId: widget.ownerId, placeId: p.placeId!);
                      _reload();
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
