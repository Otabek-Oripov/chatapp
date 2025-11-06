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
    WidgetsBinding.instance.addPostFrameCallback((_){
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("All Users"),
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: TextField(
              onChanged: (value) =>
                  ref.read(searchQueryProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: 'Search user by name or email...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () =>
                            ref.read(searchQueryProvider.notifier).state = '',
                        icon: Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        backgroundColor: Colors.white,
        child: users.when(
          data: (userList) {
            if (userList.isEmpty && searchQuery.isNotEmpty) {
              return ListView(
                children: [
                  SizedBox(height: 200),
                  Center(child: Text('No users found matching your search')),
                ],
              );
            }
            if (userList.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: 200),
                  Center(child: Text("No other users found")),
                ],
              );
            }
            return ListView.builder(
              physics: AlwaysScrollableScrollPhysics(),
              itemCount: userList.length,
              itemBuilder: (context, index) {
                final user = userList[index];
                return Userlisttitle(user: user);
              },
            );
          },
          error: (error, _) => ListView(
            children: [
              SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Text('Error $error'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(usersProvider),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => Center(child: CircularProgressIndicator()),
        ),
        // onRefresh: onRefresh,
      ),
    );
  }
}
