import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _subscriptions =>
      _firestore.collection('subscriptions');

  /// Get all subscriptions ordered by registeredAt
  Future<List<Map<String, dynamic>>> getAllSubscriptions() async {
    try {
      final snapshot = await _subscriptions
          .orderBy('registeredAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // If ordering fails (missing index), fall back to unordered
      final snapshot = await _subscriptions.get();
      final list = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort in memory
      list.sort((a, b) {
        final aTime = a['registeredAt'] as Timestamp?;
        final bTime = b['registeredAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return list;
    }
  }

  /// Activate a subscription with an expiry date
  Future<void> activateSubscription(String email, DateTime expiryDate) async {
    await _subscriptions.doc(email).update({
      'status': 'active',
      'expiryDate': Timestamp.fromDate(expiryDate),
      'activatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Revoke a subscription
  Future<void> revokeSubscription(String email) async {
    await _subscriptions.doc(email).update({
      'status': 'revoked',
      'revokedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Migrate device - clears device binding and logs reason
  Future<void> migrateDevice(String email, String reason) async {
    await _subscriptions.doc(email).update({
      'deviceId': FieldValue.delete(),
      'deviceName': FieldValue.delete(),
      'deviceModel': FieldValue.delete(),
      'platform': FieldValue.delete(),
      'migrationHistory': FieldValue.arrayUnion([
        {
          'reason': reason,
          'migratedAt': DateTime.now().toIso8601String(),
        },
      ]),
    });
  }

  /// Update admin notes
  Future<void> updateNotes(String email, String notes) async {
    await _subscriptions.doc(email).update({
      'notes': notes,
      'notesUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a subscription permanently
  Future<void> deleteSubscription(String email) async {
    await _subscriptions.doc(email).delete();
  }

  /// Update expiry date only
  Future<void> updateExpiry(String email, DateTime newExpiry) async {
    await _subscriptions.doc(email).update({
      'expiryDate': Timestamp.fromDate(newExpiry),
    });
  }

  /// Get subscription statistics
  Future<Map<String, int>> getStats() async {
    final snapshot = await _subscriptions.get();
    int active = 0, trial = 0, expired = 0, revoked = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toLowerCase();

      switch (status) {
        case 'active':
          // Check if actually expired
          final expiryDate = data['expiryDate'] as Timestamp?;
          if (expiryDate != null &&
              expiryDate.toDate().isBefore(DateTime.now())) {
            expired++;
          } else {
            active++;
          }
          break;
        case 'trial':
          trial++;
          break;
        case 'expired':
          expired++;
          break;
        case 'revoked':
          revoked++;
          break;
        default:
          trial++; // Default to trial for unknown statuses
      }
    }

    return {
      'total': snapshot.docs.length,
      'active': active,
      'trial': trial,
      'expired': expired,
      'revoked': revoked,
    };
  }

  /// Get activity log for a specific client
  Future<List<Map<String, dynamic>>> getActivityLog(String email) async {
    try {
      final snapshot = await _subscriptions
          .doc(email)
          .collection('activity_log')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // If index not ready, get without ordering
      try {
        final snapshot = await _subscriptions
            .doc(email)
            .collection('activity_log')
            .get();

        final list = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        list.sort((a, b) {
          final aTime = a['timestamp'] as Timestamp?;
          final bTime = b['timestamp'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return list;
      } catch (_) {
        return [];
      }
    }
  }

  /// Set trial days for a client
  Future<void> setTrialDays(String email, int days) async {
    final trialExpiry = DateTime.now().add(Duration(days: days));
    await _subscriptions.doc(email).update({
      'status': 'trial',
      'expiryDate': Timestamp.fromDate(trialExpiry),
    });
  }
}
