import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class MatchingService {
  static final MatchingService _instance = MatchingService._internal();

  factory MatchingService() {
    return _instance;
  }

  MatchingService._internal();

  final _firestore = FirebaseFirestore.instance;

  Future<void> joinWaitingQueue(String userID) async {
    await _firestore.collection('waiting').doc(userID).set({
      'uid': userID,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getWaitingUsersStream(String userID) {
    return _firestore
        .collection('waiting')
        .where(FieldPath.documentId, isNotEqualTo: userID)
        .limit(1)
        .snapshots();
  }

  Future<String> findAndCreateCall(String user1ID, String user2ID) async {
    final ids = [user1ID, user2ID]..sort();
    final callID = ids.join('_');

    await _firestore.collection('calls').doc(callID).set({
      'callID': callID,
      'user1': user1ID,
      'user2': user2ID,
      'status': 'connecting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Remove both users from waiting queue
    await Future.wait([
      _firestore.collection('waiting').doc(user1ID).delete(),
      _firestore.collection('waiting').doc(user2ID).delete(),
    ]);

    return callID;
  }

  Future<void> leaveWaitingQueue(String userID) async {
    await _firestore.collection('waiting').doc(userID).delete();
  }
}
