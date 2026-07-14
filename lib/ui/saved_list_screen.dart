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
    setState(() => _future = widget.repo.listMine(widget.ownerId));
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
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('아직 저장한 곳이 없어요.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = items[i];
              return ListTile(
                leading: const Icon(Icons.bookmark, color: Color(0xFFFF5E13)),
                title: Text(p.name),
                subtitle: Text([
                  if (p.category != null) p.category!,
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
