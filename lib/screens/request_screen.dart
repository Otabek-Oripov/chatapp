import 'package:chatapp/function/snakbar.dart';
import 'package:chatapp/providers/provide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RequestScreen extends ConsumerStatefulWidget {
  const RequestScreen({super.key});

  @override
  ConsumerState<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends ConsumerState<RequestScreen> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(requestsProvider);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(requestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text("Message Requests"),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(requestsProvider),
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: request.when(
        data: (requestList) {
          if (requestList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 15),
                  Text(
                    'No pending requests',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: requestList.length,
            itemBuilder: (context, index) {
              final requests = requestList[index];
              return Card(
                elevation: 0,
                margin: EdgeInsets.all(8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage: requests.photoUrl != null
                        ? NetworkImage(requests.photoUrl!)
                        : null,
                    child: requests.photoUrl == null
                        ? Icon(Icons.person, size: 30)
                        : null,
                  ),
                  title: Text(requests.senderName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await ref
                              .read(requestsProvider.notifier)
                              .acceptRequest(requests.id, requests.senderId);
                          if (context.mounted) {
                            showAppSnackbar(
                              context: context,
                              type: SnackbarType.success,
                              description: 'Request accepted',
                            );
                            ref.invalidate(usersProvider);
                          }
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.check, color: Colors.white),
                        ),
                      ),
                      SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          await ref
                              .read(requestsProvider.notifier)
                              .acceptRequest(requests.id, requests.senderId);
                          if (context.mounted) {
                            showAppSnackbar(
                              context: context,
                              type: SnackbarType.error,
                              description: 'Request rejected',
                            );
                            ref.invalidate(usersProvider);
                          }
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error:$error'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(requestsProvider),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
        loading: () => Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
