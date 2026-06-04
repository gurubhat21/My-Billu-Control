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
  Future<void> activateSubscription(String email, DateTime expiryDate, {String platform = 'all'}) async {
    final updates = <String, dynamic>{};
    if (platform == 'android' || platform == 'all') {
      updates['androidExpiryDate'] = Timestamp.fromDate(expiryDate);
      updates['androidStatus'] = 'active';
    }
    if (platform == 'windows' || platform == 'all') {
      updates['windowsExpiryDate'] = Timestamp.fromDate(expiryDate);
      updates['windowsStatus'] = 'active';
    }
    // Also update legacy fields
    updates['subscriptionStatus'] = 'active';
    updates['status'] = 'active';
    updates['expiryDate'] = Timestamp.fromDate(expiryDate);
    updates['activatedAt'] = FieldValue.serverTimestamp();
    await _subscriptions.doc(email).update(updates);
  }

  /// Revoke a subscription
  Future<void> revokeSubscription(String email, {String platform = 'all'}) async {
    final updates = <String, dynamic>{};
    if (platform == 'android' || platform == 'all') {
      updates['androidStatus'] = 'revoked';
    }
    if (platform == 'windows' || platform == 'all') {
      updates['windowsStatus'] = 'revoked';
    }
    updates['subscriptionStatus'] = 'revoked';
    updates['status'] = 'revoked';
    updates['revokedAt'] = FieldValue.serverTimestamp();
    await _subscriptions.doc(email).update(updates);
  }

  /// Migrate device - clears device binding and logs reason
  /// [platform] can be 'android', 'windows', or 'all' (default)
  Future<void> migrateDevice(String email, String reason, {String platform = 'all'}) async {
    final Map<String, dynamic> updateData = {};

    if (platform == 'android' || platform == 'all') {
      updateData['androidDeviceId'] = FieldValue.delete();
      updateData['androidDeviceName'] = FieldValue.delete();
      updateData['androidDeviceModel'] = FieldValue.delete();
    }

    if (platform == 'windows' || platform == 'all') {
      updateData['windowsDeviceId'] = FieldValue.delete();
      updateData['windowsDeviceName'] = FieldValue.delete();
      updateData['windowsDeviceModel'] = FieldValue.delete();
    }

    if (platform == 'all') {
      // Also clear legacy fields for backward compatibility
      updateData['deviceId'] = FieldValue.delete();
      updateData['deviceName'] = FieldValue.delete();
      updateData['deviceModel'] = FieldValue.delete();
      updateData['platform'] = FieldValue.delete();
    }

    updateData['migrationHistory'] = FieldValue.arrayUnion([
      {
        'reason': reason,
        'platform': platform,
        'migratedAt': DateTime.now().toIso8601String(),
      },
    ]);

    await _subscriptions.doc(email).update(updateData);
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

  /// Toggle cloud sync for a client
  Future<void> toggleCloudSync(String email, bool enabled) async {
    await _subscriptions.doc(email).update({'cloudSyncEnabled': enabled});
  }

  /// Update expiry date only
  Future<void> updateExpiry(String email, DateTime newExpiry, {String platform = 'all'}) async {
    final updates = <String, dynamic>{};
    if (platform == 'android' || platform == 'all') {
      updates['androidExpiryDate'] = Timestamp.fromDate(newExpiry);
    }
    if (platform == 'windows' || platform == 'all') {
      updates['windowsExpiryDate'] = Timestamp.fromDate(newExpiry);
    }
    updates['expiryDate'] = Timestamp.fromDate(newExpiry);
    await _subscriptions.doc(email).update(updates);
  }

  /// Get subscription statistics
  Future<Map<String, int>> getStats() async {
    final snapshot = await _subscriptions.get();
    int active = 0, trial = 0, expired = 0, revoked = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Check both legacy 'status' and new 'subscriptionStatus'
      final status = (data['subscriptionStatus'] ?? data['status'] ?? '').toString().toLowerCase();

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
  Future<void> setTrialDays(String email, int days, {String platform = 'all'}) async {
    final trialExpiry = DateTime.now().add(Duration(days: days));
    final updates = <String, dynamic>{};
    if (platform == 'android' || platform == 'all') {
      updates['androidExpiryDate'] = Timestamp.fromDate(trialExpiry);
      updates['androidStatus'] = 'trial';
    }
    if (platform == 'windows' || platform == 'all') {
      updates['windowsExpiryDate'] = Timestamp.fromDate(trialExpiry);
      updates['windowsStatus'] = 'trial';
    }
    updates['subscriptionStatus'] = 'trial';
    updates['status'] = 'trial';
    updates['expiryDate'] = Timestamp.fromDate(trialExpiry);
    await _subscriptions.doc(email).update(updates);
  }

  /// Approve cloud sync request
  Future<void> approveCloudSync(String email) async {
    await _subscriptions.doc(email).update({
      'cloudSyncEnabled': true,
      'cloudSyncRequested': false,
      'cloudSyncApprovedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deny cloud sync request
  Future<void> denyCloudSync(String email) async {
    await _subscriptions.doc(email).update({
      'cloudSyncRequested': false,
    });
  }

  /// Approve migration request
  Future<void> approveMigration(String email) async {
    final doc = await _subscriptions.doc(email).get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final platform = (data['migrationPlatform'] ?? 'all').toString();

    // Clear device binding for the requested platform
    await migrateDevice(email, 'User requested migration', platform: platform);

    // Clear request flags
    await _subscriptions.doc(email).update({
      'migrationRequested': false,
      'migrationPlatform': FieldValue.delete(),
      'migrationRequestedAt': FieldValue.delete(),
    });
  }

  /// Deny migration request
  Future<void> denyMigration(String email) async {
    await _subscriptions.doc(email).update({
      'migrationRequested': false,
      'migrationPlatform': FieldValue.delete(),
      'migrationRequestedAt': FieldValue.delete(),
    });
  }
}
