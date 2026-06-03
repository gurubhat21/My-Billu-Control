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
    final deviceId = data['deviceId'] ?? 'N/A';
    final deviceName = data['deviceName'] ?? '';
    final deviceModel = data['deviceModel'] ?? '';
    final platform = data['platform'] ?? '';
    final status = (data['status'] ?? data['subscriptionStatus'] ?? 'trial').toString();
    final lastOnline = data['lastOnline'] as Timestamp? ?? data['lastOnlineAt'] as Timestamp?;
    final registeredAt = data['registeredAt'] as Timestamp?;
    final expiryDate = data['expiryDate'] as Timestamp?;
    final appVersion = data['appVersion'] ?? '';

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
                        _buildDetailRow(Icons.phone_android, 'Device', '$deviceName $deviceModel'.trim()),
                        _buildDetailRow(Icons.devices, 'Platform', platform),
                        _buildDetailRow(Icons.fingerprint, 'Device ID', deviceId),
                        _buildDetailRow(Icons.update, 'App Version', appVersion),
                      ]),

                      const SizedBox(height: 12),

                      // ====== SUBSCRIPTION INFO ======
                      _buildSectionCard('Subscription', Icons.card_membership, const Color(0xFF4CAF50), [
                        _buildDetailRow(Icons.info, 'Status', status.toUpperCase()),
                        _buildDetailRow(Icons.event, 'Expiry', expiryDate != null
                            ? DateFormat('dd MMM yyyy').format(expiryDate.toDate())
                            : 'N/A'),
                        _buildDetailRow(Icons.calendar_today, 'Registered', _formatDateTime(registeredAt)),
                        _buildDetailRow(Icons.access_time, 'Last Online', _formatRelativeTime(lastOnline)),
                        if (lastOnline != null)
                          _buildDetailRow(Icons.schedule, 'Last Online (exact)', _formatDateTime(lastOnline)),
                      ]),

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
}
