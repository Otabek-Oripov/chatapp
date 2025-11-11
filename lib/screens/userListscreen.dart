import 'package:chatapp/main.dart';
import 'package:chatapp/providers/provide.dart';
import 'package:chatapp/providers/userListPProvider.dart';
import 'package:chatapp/widgets/userlistTitle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Userlistscreen extends ConsumerStatefulWidget {
  const Userlistscreen({super.key});

  @override
  ConsumerState<Userlistscreen> createState() => _UserlistscreenState();
}

class _UserlistscreenState extends ConsumerState<Userlistscreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    OnlineStatusService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(usersProvider);
    });
  }

  Future<void> onRefresh() async {
    ref.invalidate(usersProvider);
    ref.invalidate(requestsProvider);
    await Future.delayed(Duration(microseconds: 500));
  }

  @override
  Widget build(BuildContext contex) {
    ref.watch(authStateProvider);
    final users = ref.watch(filteresUsersProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    // lib/screens/userListscreen.dart
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Foydalanuvchilar",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: TextField(
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: "Qidiruv...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              ref.read(searchQueryProvider.notifier).state = '',
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
        ),
      ),
      body: users.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  searchQuery.isNotEmpty
                      ? "Hech kim topilmadi"
                      : "Boshqa foydalanuvchilar yo‘q",
                  style: const TextStyle(fontSize: 18),
                ),
              )
            : ListView.builder(
                itemCount: list.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (_, i) {
                  final user = list[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Userlisttitle(user: user),
                  );
                },
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6a11cb)),
        ),
        error: (_, __) => const Center(child: Text("Xatolik")),
      ),
    );
  }
}
