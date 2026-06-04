import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/subscription_service.dart';

class ClientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const ClientDetailScreen({super.key, required this.clientData});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final SubscriptionService _service = SubscriptionService();
  List<Map<String, dynamic>> _activityLog = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivityLog();
  }

  Future<void> _loadActivityLog() async {
    setState(() => _isLoading = true);
    final email = widget.clientData['id'] ?? widget.clientData['email'] ?? '';
    final log = await _service.getActivityLog(email);
    if (!mounted) return;
    setState(() {
      _activityLog = log;
      _isLoading = false;
    });
  }

  /// Safely convert a Firestore value to Timestamp (handles both Timestamp and String)
  Timestamp? _safeTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is String && value.isNotEmpty) {
      final dt = DateTime.tryParse(value);
      if (dt != null) return Timestamp.fromDate(dt);
    }
    return null;
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
  }

  String _formatRelativeTime(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final now = DateTime.now();
    final date = ts.toDate();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.clientData;
    final email = data['id'] ?? data['email'] ?? 'Unknown';
    final displayName = data['displayName'] ?? email;
    final status = (data['status'] ?? data['subscriptionStatus'] ?? 'trial').toString();
    final lastOnline = _safeTimestamp(data['lastOnline']) ?? _safeTimestamp(data['lastOnlineAt']);
    final registeredAt = _safeTimestamp(data['registeredAt']);
    final expiryDate = _safeTimestamp(data['expiryDate']);
    final appVersion = data['appVersion'] ?? '';

    // Legacy fields
    final deviceId = data['deviceId'] ?? 'N/A';
    final deviceName = data['deviceName'] ?? '';
    final deviceModel = data['deviceModel'] ?? '';
    final platform = data['platform'] ?? '';

    // Platform-specific fields
    final androidDeviceId = data['androidDeviceId'] ?? '';
    final androidDeviceName = data['androidDeviceName'] ?? '';
    final androidDeviceModel = data['androidDeviceModel'] ?? '';
    final windowsDeviceId = data['windowsDeviceId'] ?? '';
    final windowsDeviceName = data['windowsDeviceName'] ?? '';
    final windowsDeviceModel = data['windowsDeviceModel'] ?? '';
    final hasAndroid = androidDeviceId.toString().isNotEmpty;
    final hasWindows = windowsDeviceId.toString().isNotEmpty;
    final hasLegacyOnly = !hasAndroid && !hasWindows && deviceId != 'N/A';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E1A), Color(0xFF121830), Color(0xFF0A0E1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7C4DFF).withAlpha(51),
                      const Color(0xFF448AFF).withAlpha(26),
                    ],
                  ),
                  border: Border(bottom: BorderSide(color: Colors.white.withAlpha(10))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(email,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadActivityLog,
                  color: const Color(0xFF7C4DFF),
                  backgroundColor: const Color(0xFF141929),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ====== CLIENT INFO CARD ======
                      _buildSectionCard('Client Information', Icons.person, const Color(0xFF448AFF), [
                        _buildDetailRow(Icons.email, 'Email', email),
                        _buildDetailRow(Icons.badge, 'Name', displayName),
                        _buildDetailRow(Icons.update, 'App Version', appVersion),
                      ]),

                      const SizedBox(height: 12),

                      // ====== ANDROID DEVICE SECTION ======
                      _buildSectionCard(
                        'Android Device',
                        Icons.phone_android,
                        const Color(0xFF4CAF50),
                        hasAndroid
                          ? [
                              _buildDetailRow(Icons.phone_android, 'Device', '$androidDeviceName $androidDeviceModel'.trim()),
                              _buildDetailRow(Icons.fingerprint, 'Device ID', androidDeviceId.toString()),
                            ]
                          : [
                              _buildDetailRow(Icons.info_outline, 'Status', 'No Android device registered'),
                            ],
                        trailing: hasAndroid
                          ? _buildMigrateChip('Migrate', const Color(0xFF4CAF50), () => _showMigrateDialog(email, 'android'))
                          : null,
                      ),

                      const SizedBox(height: 12),

                      // ====== WINDOWS DEVICE SECTION ======
                      _buildSectionCard(
                        'Windows Device',
                        Icons.desktop_windows,
                        const Color(0xFF448AFF),
                        hasWindows
                          ? [
                              _buildDetailRow(Icons.desktop_windows, 'Device', '$windowsDeviceName $windowsDeviceModel'.trim()),
                              _buildDetailRow(Icons.fingerprint, 'Device ID', windowsDeviceId.toString()),
                            ]
                          : [
                              _buildDetailRow(Icons.info_outline, 'Status', 'No Windows device registered'),
                            ],
                        trailing: hasWindows
                          ? _buildMigrateChip('Migrate', const Color(0xFF448AFF), () => _showMigrateDialog(email, 'windows'))
                          : null,
                      ),

                      // ====== LEGACY DEVICE (backward compat) ======
                      if (hasLegacyOnly) ...[
                        const SizedBox(height: 12),
                        _buildSectionCard('Legacy Device', Icons.devices_other, const Color(0xFF9E9E9E), [
                          _buildDetailRow(Icons.phone_android, 'Device', '$deviceName $deviceModel'.trim()),
                          _buildDetailRow(Icons.devices, 'Platform', platform),
                          _buildDetailRow(Icons.fingerprint, 'Device ID', deviceId),
                        ],
                        trailing: _buildMigrateChip('Migrate All', const Color(0xFF009688), () => _showMigrateDialog(email, 'all')),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // ====== PLATFORM STATUS BADGES ======
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withAlpha(13)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.devices, size: 16, color: Colors.white38),
                            const SizedBox(width: 10),
                            Text('Platforms:', style: GoogleFonts.inter(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 12),
                            _buildPlatformBadge('Android', Icons.phone_android, hasAndroid, const Color(0xFF4CAF50)),
                            const SizedBox(width: 8),
                            _buildPlatformBadge('Windows', Icons.desktop_windows, hasWindows, const Color(0xFF448AFF)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ====== ANDROID SUBSCRIPTION ======
                      _buildPlatformSubscriptionCard(
                        title: 'Android Subscription',
                        icon: Icons.phone_android,
                        color: const Color(0xFF4CAF50),
                        status: (data['androidStatus'] ?? data['subscriptionStatus'] ?? status).toString(),
                        expiryDate: _safeTimestamp(data['androidExpiryDate']) ?? expiryDate,
                        lastOnlineAt: _safeTimestamp(data['androidLastOnlineAt']) ?? lastOnline,
                        registeredAt: registeredAt,
                        email: email,
                        platform: 'android',
                      ),

                      const SizedBox(height: 12),

                      // ====== WINDOWS SUBSCRIPTION ======
                      _buildPlatformSubscriptionCard(
                        title: 'Windows Subscription',
                        icon: Icons.desktop_windows,
                        color: const Color(0xFF448AFF),
                        status: (data['windowsStatus'] ?? data['subscriptionStatus'] ?? status).toString(),
                        expiryDate: _safeTimestamp(data['windowsExpiryDate']) ?? expiryDate,
                        lastOnlineAt: _safeTimestamp(data['windowsLastOnlineAt']) ?? lastOnline,
                        registeredAt: registeredAt,
                        email: email,
                        platform: 'windows',
                      ),

                      const SizedBox(height: 12),

                      // ====== CLOUD SYNC ======
                      _buildCloudSyncCard(
                        email: email,
                        cloudSyncEnabled: data['cloudSyncEnabled'] == true,
                        cloudSyncRequested: data['cloudSyncRequested'] == true,
                      ),

                      // ====== MIGRATION REQUEST ======
                      if (data['migrationRequested'] == true) ...[
                        const SizedBox(height: 12),
                        _buildMigrationRequestCard(
                          email: email,
                          platform: (data['migrationPlatform'] ?? 'all').toString(),
                          requestedAt: _safeTimestamp(data['migrationRequestedAt']),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // ====== ACTIVITY LOG ======
                      _buildSectionCard(
                        'Activity Log (${_activityLog.length} opens)',
                        Icons.history,
                        const Color(0xFFFF9800),
                        [],
                        trailing: _isLoading
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9800)))
                            : null,
                      ),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))),
                        )
                      else if (_activityLog.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(8),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            border: Border.all(color: Colors.white.withAlpha(13)),
                          ),
                          child: Center(
                            child: Text('No activity recorded yet',
                              style: GoogleFonts.inter(color: Colors.white30, fontSize: 14)),
                          ),
                        )
                      else
                        ..._buildActivityTimeline(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActivityTimeline() {
    // Group by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final log in _activityLog) {
      final ts = log['timestamp'] as Timestamp?;
      if (ts == null) continue;
      final dateKey = DateFormat('dd MMM yyyy').format(ts.toDate());
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(log);
    }

    final widgets = <Widget>[];
    int dayIndex = 0;

    for (final entry in grouped.entries) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF).withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF7C4DFF)),
              const SizedBox(width: 8),
              Text(entry.key,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7C4DFF))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${entry.value.length} opens',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF7C4DFF), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );

      for (int i = 0; i < entry.value.length; i++) {
        final log = entry.value[i];
        final ts = log['timestamp'] as Timestamp?;
        final time = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : '??';
        final deviceName = log['deviceName'] ?? '';
        final type = log['type'] ?? 'app_open';

        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withAlpha(8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: type == 'app_open' ? const Color(0xFF4CAF50) : const Color(0xFF448AFF),
                  ),
                ),
                const SizedBox(width: 12),
                Text(time,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type == 'app_open' ? 'App Opened' : type,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                  ),
                ),
                if (deviceName.isNotEmpty)
                  Text(deviceName,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white24)),
              ],
            ),
          ),
        );
      }

      dayIndex++;
    }

    return widgets;
  }

  Widget _buildSectionCard(String title, IconData icon, Color color, List<Widget> children, {Widget? trailing}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Text(title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
          ),
          if (children.isNotEmpty)
            Divider(color: Colors.white.withAlpha(10), height: 1),
          if (children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    if (value.isEmpty || value == 'N/A') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.white24),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white30, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = const Color(0xFF4CAF50);
        break;
      case 'trial':
        color = const Color(0xFFFF9800);
        break;
      case 'expired':
        color = const Color(0xFFF44336);
        break;
      case 'revoked':
        color = const Color(0xFFB71C1C);
        break;
      default:
        color = const Color(0xFF9E9E9E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Text(status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildPlatformBadge(String label, IconData icon, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? color.withAlpha(26) : Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color.withAlpha(77) : Colors.white.withAlpha(18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isActive ? color : Colors.white24),
          const SizedBox(width: 5),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: isActive ? color : Colors.white24,
            )),
          const SizedBox(width: 4),
          Icon(
            isActive ? Icons.check_circle : Icons.cancel_outlined,
            size: 12,
            color: isActive ? color : Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildMigrateChip(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phonelink_erase, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformSubscriptionCard({
    required String title,
    required IconData icon,
    required Color color,
    required String status,
    required Timestamp? expiryDate,
    required Timestamp? lastOnlineAt,
    required Timestamp? registeredAt,
    required String email,
    required String platform,
  }) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'active':
        statusColor = const Color(0xFF4CAF50);
        break;
      case 'trial':
        statusColor = const Color(0xFFFF9800);
        break;
      case 'expired':
        statusColor = const Color(0xFFF44336);
        break;
      case 'revoked':
        statusColor = const Color(0xFFB71C1C);
        break;
      default:
        statusColor = const Color(0xFF9E9E9E);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Text(title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withAlpha(51)),
                  ),
                  child: Text(status.toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withAlpha(10), height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildDetailRow(Icons.event, 'Expiry', expiryDate != null
                    ? DateFormat('dd MMM yyyy').format(expiryDate.toDate())
                    : 'N/A'),
                _buildDetailRow(Icons.access_time, 'Last Online', _formatRelativeTime(lastOnlineAt)),
                if (lastOnlineAt != null)
                  _buildDetailRow(Icons.schedule, 'Last Online (exact)', _formatDateTime(lastOnlineAt)),
                _buildDetailRow(Icons.calendar_today, 'Registered', _formatDateTime(registeredAt)),
              ],
            ),
          ),
          Divider(color: Colors.white.withAlpha(10), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildActionChip('Activate', Icons.check_circle_outline, const Color(0xFF4CAF50), () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked == null || !mounted) return;
                  try {
                    await _service.activateSubscription(email, picked, platform: platform);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Activated $platform for $email until ${DateFormat('dd MMM yyyy').format(picked)}'),
                      backgroundColor: const Color(0xFF4CAF50),
                    ));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'), backgroundColor: const Color(0xFFF44336),
                    ));
                  }
                }),
                _buildActionChip('Set Expiry', Icons.event, const Color(0xFF448AFF), () async {
                  DateTime initial = expiryDate?.toDate() ?? DateTime.now().add(const Duration(days: 30));
                  if (initial.isBefore(DateTime.now())) {
                    initial = DateTime.now().add(const Duration(days: 30));
                  }
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked == null || !mounted) return;
                  try {
                    await _service.updateExpiry(email, picked, platform: platform);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('$platform expiry updated to ${DateFormat('dd MMM yyyy').format(picked)}'),
                      backgroundColor: const Color(0xFF4CAF50),
                    ));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'), backgroundColor: const Color(0xFFF44336),
                    ));
                  }
                }),
                _buildActionChip('Revoke', Icons.block, const Color(0xFFF44336), () async {
                  try {
                    await _service.revokeSubscription(email, platform: platform);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Revoked $platform access for $email'),
                      backgroundColor: const Color(0xFFF44336),
                    ));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'), backgroundColor: const Color(0xFFF44336),
                    ));
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudSyncCard({
    required String email,
    required bool cloudSyncEnabled,
    required bool cloudSyncRequested,
  }) {
    return StatefulBuilder(
      builder: (context, setCardState) {
        bool syncEnabled = cloudSyncEnabled;
        bool requested = cloudSyncRequested;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(13)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_sync, size: 18, color: const Color(0xFF7C4DFF)),
                    const SizedBox(width: 10),
                    Text('Cloud Sync',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF7C4DFF))),
                    const Spacer(),
                    Text(syncEnabled ? 'Enabled' : 'Disabled',
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: syncEnabled ? const Color(0xFF4CAF50) : Colors.white38,
                      )),
                    const SizedBox(width: 8),
                    Switch(
                      value: syncEnabled,
                      activeColor: const Color(0xFF7C4DFF),
                      onChanged: (value) async {
                        try {
                          await _service.toggleCloudSync(email, value);
                          setCardState(() => syncEnabled = value);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Cloud sync ${value ? 'enabled' : 'disabled'} for $email'),
                            backgroundColor: const Color(0xFF7C4DFF),
                          ));
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error: $e'), backgroundColor: const Color(0xFFF44336),
                          ));
                        }
                      },
                    ),
                  ],
                ),
                // Show request badge if requested
                if (requested) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF9800).withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active, size: 16, color: Color(0xFFFF9800)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('User requested cloud sync',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFFF9800), fontWeight: FontWeight.w500))),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            try {
                              await _service.approveCloudSync(email);
                              setCardState(() { syncEnabled = true; requested = false; });
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Cloud sync approved for $email'),
                                backgroundColor: const Color(0xFF4CAF50),
                              ));
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Error: $e'), backgroundColor: const Color(0xFFF44336),
                              ));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Approve', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4CAF50))),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () async {
                            try {
                              await _service.denyCloudSync(email);
                              setCardState(() => requested = false);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Cloud sync request denied for $email'),
                                backgroundColor: const Color(0xFFF44336),
                              ));
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Error: $e'), backgroundColor: const Color(0xFFF44336),
                              ));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF44336).withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Deny', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF44336))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMigrationRequestCard({
    required String email,
    required String platform,
    required Timestamp? requestedAt,
  }) {
    final platformLabel = platform == 'all' ? 'All Platforms' : platform[0].toUpperCase() + platform.substring(1);
    final platformColor = platform == 'android' ? const Color(0xFF4CAF50) : platform == 'windows' ? const Color(0xFF448AFF) : const Color(0xFFFF9800);

    return StatefulBuilder(
      builder: (context, setCardState) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withAlpha(8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF9800).withAlpha(30)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 18, color: Color(0xFFFF9800)),
                    const SizedBox(width: 10),
                    Text('Migration Requested',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFFF9800))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: platformColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(platformLabel,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: platformColor)),
                    ),
                  ],
                ),
                if (requestedAt != null) ...[
                  const SizedBox(height: 8),
                  Text('Requested: ${_formatDateTime(requestedAt)}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: GestureDetector(
                      onTap: () async {
                        try {
                          await _service.approveMigration(email);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Migration approved for $email ($platformLabel)'),
                            backgroundColor: const Color(0xFF4CAF50),
                          ));
                          setState(() {}); // Refresh parent
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error: $e'), backgroundColor: const Color(0xFFF44336),
                          ));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF4CAF50).withAlpha(51)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.check_circle, size: 14, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 6),
                          Text('Approve', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4CAF50))),
                        ]),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(
                      onTap: () async {
                        try {
                          await _service.denyMigration(email);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Migration denied for $email'),
                            backgroundColor: const Color(0xFFF44336),
                          ));
                          setState(() {}); // Refresh parent
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error: $e'), backgroundColor: const Color(0xFFF44336),
                          ));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF44336).withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF44336).withAlpha(51)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.cancel, size: 14, color: Color(0xFFF44336)),
                          const SizedBox(width: 6),
                          Text('Deny', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFF44336))),
                        ]),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  void _showMigrateDialog(String email, String platform) {
    final reasonController = TextEditingController();
    final platformLabel = platform == 'all' ? 'All Platforms' : platform[0].toUpperCase() + platform.substring(1);
    final color = platform == 'android'
        ? const Color(0xFF4CAF50)
        : platform == 'windows'
            ? const Color(0xFF448AFF)
            : const Color(0xFF009688);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.phonelink_erase, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Migrate $platformLabel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will clear the $platformLabel device binding for $email, allowing them to register on a new device.',
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Reason for migration',
                labelStyle: GoogleFonts.inter(color: Colors.white38),
                hintText: 'e.g., New phone, device lost...',
                hintStyle: GoogleFonts.inter(color: Colors.white24),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final reason = reasonController.text.trim().isEmpty
                  ? 'Admin migration'
                  : reasonController.text.trim();
              try {
                await _service.migrateDevice(email, reason, platform: platform);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Device binding cleared ($platformLabel) for $email'),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: const Color(0xFFF44336),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text('Migrate', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
