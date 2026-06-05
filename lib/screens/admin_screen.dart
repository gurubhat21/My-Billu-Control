import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/subscription_service.dart';
import 'client_detail_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {
  final SubscriptionService _service = SubscriptionService();
  List<Map<String, dynamic>> _allSubscriptions = [];
  List<Map<String, dynamic>> _filteredSubscriptions = [];
  Map<String, int> _stats = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.getAllSubscriptions(),
        _service.getStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _allSubscriptions = results[0] as List<Map<String, dynamic>>;
        _stats = results[1] as Map<String, int>;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error loading data: $e', isError: true);
    }
  }

  void _applyFilters() {
    _filteredSubscriptions = _allSubscriptions.where((sub) {
      // Status filter
      if (_filterStatus != 'All') {
        final status = _getEffectiveStatus(sub);
        if (status.toLowerCase() != _filterStatus.toLowerCase()) {
          return false;
        }
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final email = (sub['email'] ?? sub['id'] ?? '').toString().toLowerCase();
        final name = (sub['displayName'] ?? '').toString().toLowerCase();
        final device = (sub['deviceName'] ?? '').toString().toLowerCase();
        final model = (sub['deviceModel'] ?? '').toString().toLowerCase();
        final androidDevice = (sub['androidDeviceName'] ?? '').toString().toLowerCase();
        final androidModel = (sub['androidDeviceModel'] ?? '').toString().toLowerCase();
        final windowsDevice = (sub['windowsDeviceName'] ?? '').toString().toLowerCase();
        final windowsModel = (sub['windowsDeviceModel'] ?? '').toString().toLowerCase();
        return email.contains(query) ||
            name.contains(query) ||
            device.contains(query) ||
            model.contains(query) ||
            androidDevice.contains(query) ||
            androidModel.contains(query) ||
            windowsDevice.contains(query) ||
            windowsModel.contains(query);
      }

      return true;
    }).toList();
  }

  String _getEffectiveStatus(Map<String, dynamic> sub) {
    final status = (sub['status'] ?? 'trial').toString().toLowerCase();
    if (status == 'active') {
      Timestamp? expiryDate;
      final raw = sub['expiryDate'];
      if (raw is Timestamp) expiryDate = raw;
      else if (raw is String) {
        final dt = DateTime.tryParse(raw);
        if (dt != null) expiryDate = Timestamp.fromDate(dt);
      }
      if (expiryDate != null && expiryDate.toDate().isBefore(DateTime.now())) {
        return 'expired';
      }
    }
    return status;
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isSuccess
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFF44336)
            : isSuccess
                ? const Color(0xFF4CAF50)
                : const Color(0xFF448AFF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E1A),
              Color(0xFF121830),
              Color(0xFF0A0E1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadData(isRefresh: true),
                  color: const Color(0xFF7C4DFF),
                  backgroundColor: const Color(0xFF141929),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF7C4DFF),
                          ),
                        )
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(child: _buildStatsBar()),
                            SliverToBoxAdapter(child: _buildSearchFilter()),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Text(
                                  '${_filteredSubscriptions.length} clients',
                                  style: GoogleFonts.inter(
                                    color: Colors.white38,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            _filteredSubscriptions.isEmpty
                                ? SliverFillRemaining(
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.inbox_outlined,
                                            size: 64,
                                            color: Colors.white.withAlpha(38),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No clients found',
                                            style: GoogleFonts.inter(
                                              color: Colors.white38,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        return _ClientCard(
                                          key: ValueKey(
                                              _filteredSubscriptions[index]
                                                      ['id'] ??
                                                  index),
                                          data: _filteredSubscriptions[index],
                                          index: index,
                                          effectiveStatus: _getEffectiveStatus(
                                              _filteredSubscriptions[index]),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ClientDetailScreen(
                                                  clientData: _filteredSubscriptions[index],
                                                ),
                                              ),
                                            ).then((_) => _loadData());
                                          },
                                          onActivate: () => _showActivateDialog(
                                              _filteredSubscriptions[index]),
                                          onRevoke: () => _showRevokeDialog(
                                              _filteredSubscriptions[index]),
                                          onExpiry: () => _showExpiryDialog(
                                              _filteredSubscriptions[index]),
                                          onMigrate: () => _showMigrateDialog(
                                              _filteredSubscriptions[index]),
                                          onNotes: () => _showNotesDialog(
                                              _filteredSubscriptions[index]),
                                          onDelete: () => _showDeleteDialog(
                                              _filteredSubscriptions[index]),
                                        );
                                      },
                                      childCount:
                                          _filteredSubscriptions.length,
                                    ),
                                  ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 32),
                            ),
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

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C4DFF).withAlpha(51),
            const Color(0xFF448AFF).withAlpha(26),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withAlpha(10),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withAlpha(51),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.admin_panel_settings,
                size: 22, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Billu Control',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Admin Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white38,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final statItems = [
      _StatItem('Total', _stats['total'] ?? 0, const Color(0xFF448AFF), Icons.people),
      _StatItem('Active', _stats['active'] ?? 0, const Color(0xFF4CAF50), Icons.check_circle),
      _StatItem('Trial', _stats['trial'] ?? 0, const Color(0xFFFF9800), Icons.hourglass_top),
      _StatItem('Expired', _stats['expired'] ?? 0, const Color(0xFFF44336), Icons.timer_off),
      _StatItem('Revoked', _stats['revoked'] ?? 0, const Color(0xFFB71C1C), Icons.block),
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: statItems.length,
        itemBuilder: (context, index) {
          final item = statItems[index];
          return Container(
            width: 120,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  item.color.withAlpha(38),
                  item.color.withAlpha(13),
                ],
              ),
              border: Border.all(
                color: item.color.withAlpha(38),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, color: item.color, size: 16),
                      const Spacer(),
                      Text(
                        '${item.count}',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: item.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: item.color.withAlpha(179),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(18)),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search email, name, device...',
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 20),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.white24, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _applyFilters();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilters();
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(18)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterStatus,
                dropdownColor: const Color(0xFF1E2240),
                icon: const Icon(Icons.filter_list, color: Colors.white24, size: 18),
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                items: ['All', 'Active', 'Trial', 'Expired', 'Revoked']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _filterStatus = value ?? 'All';
                    _applyFilters();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======================= DIALOGS =======================

  void _showActivateDialog(Map<String, dynamic> sub) async {
    final email = sub['id'] ?? sub['email'] ?? '';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => _datePickerTheme(child),
    );

    if (picked == null || !mounted) return;
    selectedDate = picked;

    try {
      await _service.activateSubscription(email, selectedDate);
      _showSnackBar(
        'Activated $email until ${DateFormat('dd MMM yyyy').format(selectedDate)}',
        isSuccess: true,
      );
      _loadData();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showRevokeDialog(Map<String, dynamic> sub) {
    final email = sub['id'] ?? sub['email'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.block, color: Color(0xFFF44336), size: 22),
            const SizedBox(width: 10),
            Text('Revoke Access', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to revoke access for\n$email?',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.revokeSubscription(email);
                _showSnackBar('Revoked access for $email', isSuccess: true);
                _loadData();
              } catch (e) {
                _showSnackBar('Error: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF44336)),
            child: Text('Revoke', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showExpiryDialog(Map<String, dynamic> sub) async {
    final email = sub['id'] ?? sub['email'] ?? '';
    final raw = sub['expiryDate'];
    Timestamp? currentExpiry;
    if (raw is Timestamp) currentExpiry = raw;
    else if (raw is String) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) currentExpiry = Timestamp.fromDate(dt);
    }
    DateTime initial = currentExpiry?.toDate() ?? DateTime.now().add(const Duration(days: 30));
    if (initial.isBefore(DateTime.now())) {
      initial = DateTime.now().add(const Duration(days: 30));
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => _datePickerTheme(child),
    );

    if (picked == null || !mounted) return;

    try {
      await _service.updateExpiry(email, picked);
      _showSnackBar(
        'Expiry updated to ${DateFormat('dd MMM yyyy').format(picked)}',
        isSuccess: true,
      );
      _loadData();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showMigrateDialog(Map<String, dynamic> sub) {
    final email = sub['id'] ?? sub['email'] ?? '';
    final reasonController = TextEditingController();
    String selectedPlatform = 'all';

    final hasAndroid = (sub['androidDeviceId'] ?? '').toString().isNotEmpty;
    final hasWindows = (sub['windowsDeviceId'] ?? '').toString().isNotEmpty;
    final hasLegacy = (sub['deviceId'] ?? '').toString().isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.phonelink_erase, color: Color(0xFF009688), size: 22),
              const SizedBox(width: 10),
              Text('Migrate Device', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will clear the device binding for $email, allowing them to register on a new device.',
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text('Platform to migrate:',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildPlatformChip('All', 'all', selectedPlatform, const Color(0xFF009688), (val) {
                    setDialogState(() => selectedPlatform = val);
                  }),
                  if (hasAndroid || hasLegacy)
                    _buildPlatformChip('Android', 'android', selectedPlatform, const Color(0xFF4CAF50), (val) {
                      setDialogState(() => selectedPlatform = val);
                    }),
                  if (hasWindows)
                    _buildPlatformChip('Windows', 'windows', selectedPlatform, const Color(0xFF448AFF), (val) {
                      setDialogState(() => selectedPlatform = val);
                    }),
                ],
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
                  await _service.migrateDevice(email, reason, platform: selectedPlatform);
                  final platformLabel = selectedPlatform == 'all' ? 'all platforms' : selectedPlatform;
                  _showSnackBar('Device binding cleared ($platformLabel) for $email', isSuccess: true);
                  _loadData();
                } catch (e) {
                  _showSnackBar('Error: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009688)),
              child: Text('Migrate', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformChip(String label, String value, String selected, Color color, ValueChanged<String> onSelected) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(51) : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.white.withAlpha(26)),
        ),
        child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: isSelected ? color : Colors.white38,
          )),
      ),
    );
  }

  void _showNotesDialog(Map<String, dynamic> sub) {
    final email = sub['id'] ?? sub['email'] ?? '';
    final notesController = TextEditingController(text: sub['notes'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.note_alt_outlined, color: Color(0xFFFF9800), size: 22),
            const SizedBox(width: 10),
            Text('Admin Notes', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ],
        ),
        content: TextField(
          controller: notesController,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Add notes about this client...',
            hintStyle: GoogleFonts.inter(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.updateNotes(email, notesController.text.trim());
                _showSnackBar('Notes updated', isSuccess: true);
                _loadData();
              } catch (e) {
                _showSnackBar('Error: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            child: Text('Save', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> sub) {
    final email = sub['id'] ?? sub['email'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Color(0xFFB71C1C), size: 22),
            const SizedBox(width: 10),
            Text('Delete Permanently',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF44336).withAlpha(26),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF44336).withAlpha(51)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Color(0xFFF44336), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFF44336),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to permanently delete the subscription for $email?',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
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
              try {
                await _service.deleteSubscription(email);
                _showSnackBar('Deleted $email', isSuccess: true);
                _loadData();
              } catch (e) {
                _showSnackBar('Error: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _datePickerTheme(Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C4DFF),
          onPrimary: Colors.white,
          surface: Color(0xFF1E2240),
          onSurface: Colors.white,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF141929),
        ),
      ),
      child: child!,
    );
  }
}

// ======================== STAT ITEM ========================

class _StatItem {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  _StatItem(this.label, this.count, this.color, this.icon);
}

// ======================== CLIENT CARD ========================

class _ClientCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;
  final String effectiveStatus;
  final VoidCallback onTap;
  final VoidCallback onActivate;
  final VoidCallback onRevoke;
  final VoidCallback onExpiry;
  final VoidCallback onMigrate;
  final VoidCallback onNotes;
  final VoidCallback onDelete;

  const _ClientCard({
    super.key,
    required this.data,
    required this.index,
    required this.effectiveStatus,
    required this.onTap,
    required this.onActivate,
    required this.onRevoke,
    required this.onExpiry,
    required this.onMigrate,
    required this.onNotes,
    required this.onDelete,
  });

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + (widget.index.clamp(0, 10) * 50)),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.effectiveStatus) {
      case 'active':
        return const Color(0xFF4CAF50);
      case 'trial':
        return const Color(0xFFFF9800);
      case 'expired':
        return const Color(0xFFF44336);
      case 'revoked':
        return const Color(0xFFB71C1C);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String get _statusLabel {
    return widget.effectiveStatus[0].toUpperCase() +
        widget.effectiveStatus.substring(1);
  }

  String _formatRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _getDaysRemaining(Timestamp? expiryDate) {
    if (expiryDate == null) return '';
    final now = DateTime.now();
    final expiry = expiryDate.toDate();
    final diff = expiry.difference(now).inDays;
    if (diff < 0) return '(${-diff}d overdue)';
    if (diff == 0) return '(today)';
    return '(${diff}d left)';
  }

  /// Safely convert Firestore value to Timestamp (handles both Timestamp and String)
  Timestamp? _safeTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is String && value.isNotEmpty) {
      final dt = DateTime.tryParse(value);
      if (dt != null) return Timestamp.fromDate(dt);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final email = data['id'] ?? data['email'] ?? 'Unknown';
    final displayName = data['displayName'] ?? '';
    final deviceName = data['deviceName'] ?? '';
    final deviceModel = data['deviceModel'] ?? '';
    final deviceId = data['deviceId'] ?? '';
    final platform = data['platform'] ?? '';
    final expiryDate = _safeTimestamp(data['expiryDate']);
    final lastOnline = _safeTimestamp(data['lastOnline']) ?? _safeTimestamp(data['lastOnlineAt']);
    final registeredAt = _safeTimestamp(data['registeredAt']);
    final notes = data['notes'] ?? '';

    // Platform-specific device fields
    final hasAndroid = (data['androidDeviceId'] ?? '').toString().isNotEmpty;
    final hasWindows = (data['windowsDeviceId'] ?? '').toString().isNotEmpty;
    final androidDeviceName = data['androidDeviceName'] ?? '';
    final androidDeviceModel = data['androidDeviceModel'] ?? '';
    final windowsDeviceName = data['windowsDeviceName'] ?? '';
    final windowsDeviceModel = data['windowsDeviceModel'] ?? '';

    // Platform-specific subscription status
    final androidStatus = (data['androidStatus'] ?? '').toString();
    final windowsStatus = (data['windowsStatus'] ?? '').toString();
    final cloudSyncEnabled = data['cloudSyncEnabled'] == true;

    // Platform-specific expiry dates
    final androidExpiry = _safeTimestamp(data['androidExpiryDate']) ?? expiryDate;
    final windowsExpiry = _safeTimestamp(data['windowsExpiryDate']) ?? expiryDate;
    final androidLastOnline = _safeTimestamp(data['androidLastOnlineAt']) ?? lastOnline;
    final windowsLastOnline = _safeTimestamp(data['windowsLastOnlineAt']) ?? lastOnline;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withAlpha(8),
            border: Border.all(color: Colors.white.withAlpha(13)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: Avatar + Name + Status badge
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                _statusColor.withAlpha(77),
                                _statusColor.withAlpha(38),
                              ],
                            ),
                            border: Border.all(
                              color: _statusColor.withAlpha(102),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              (displayName.isNotEmpty
                                      ? displayName[0]
                                      : email[0])
                                  .toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _statusColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name + email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (displayName.isNotEmpty)
                                Text(
                                  displayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                email,
                                style: GoogleFonts.inter(
                                  fontSize: displayName.isNotEmpty ? 12 : 14,
                                  color: displayName.isNotEmpty
                                      ? Colors.white54
                                      : Colors.white,
                                  fontWeight: displayName.isNotEmpty
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _statusColor.withAlpha(51),
                            ),
                          ),
                          child: Text(
                            _statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _statusColor,
                            ),
                          ),
                        ),
                        // Cloud sync badge
                        if (cloudSyncEnabled) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C4DFF).withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF7C4DFF).withAlpha(51)),
                            ),
                            child: const Icon(Icons.cloud_sync, size: 14, color: Color(0xFF7C4DFF)),
                          ),
                        ],
                        const SizedBox(width: 6),
                        // Platform badges
                        if (hasAndroid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF4CAF50).withAlpha(51)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_android, size: 12, color: Color(0xFF4CAF50)),
                                SizedBox(width: 2),
                                Icon(Icons.check, size: 10, color: Color(0xFF4CAF50)),
                              ],
                            ),
                          ),
                        if (hasWindows) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF448AFF).withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF448AFF).withAlpha(51)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.desktop_windows, size: 12, color: Color(0xFF448AFF)),
                                SizedBox(width: 2),
                                Icon(Icons.check, size: 10, color: Color(0xFF448AFF)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Pending requests notification
                    if (data['cloudSyncRequested'] == true || data['migrationRequested'] == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFF9800).withAlpha(40)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.notifications_active, size: 13, color: Color(0xFFFF9800)),
                              const SizedBox(width: 6),
                              Text(
                                [
                                  if (data['cloudSyncRequested'] == true) 'Cloud Sync',
                                  if (data['migrationRequested'] == true) 'Migration',
                                ].join(' + ') + ' Request',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFFF9800)),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Platform-specific status + expiry
                    if (androidStatus.isNotEmpty || windowsStatus.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (androidStatus.isNotEmpty || hasAndroid)
                              _buildPlatformExpiryRow(
                                'Android',
                                Icons.phone_android,
                                const Color(0xFF4CAF50),
                                androidStatus.isNotEmpty ? androidStatus : widget.effectiveStatus,
                                androidExpiry,
                                androidLastOnline,
                              ),
                            if (windowsStatus.isNotEmpty || hasWindows) ...[
                              const SizedBox(height: 6),
                              _buildPlatformExpiryRow(
                                'Windows',
                                Icons.desktop_windows,
                                const Color(0xFF448AFF),
                                windowsStatus.isNotEmpty ? windowsStatus : widget.effectiveStatus,
                                windowsExpiry,
                                windowsLastOnline,
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Info rows
                    _buildInfoGrid(
                      deviceName: deviceName,
                      deviceModel: deviceModel,
                      deviceId: deviceId,
                      platform: platform,
                      expiryDate: expiryDate,
                      lastOnline: lastOnline,
                      registeredAt: registeredAt,
                      hasAndroid: hasAndroid,
                      androidDeviceName: androidDeviceName,
                      androidDeviceModel: androidDeviceModel,
                      hasWindows: hasWindows,
                      windowsDeviceName: windowsDeviceName,
                      windowsDeviceModel: windowsDeviceModel,
                    ),

                    // Notes
                    if (notes.toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withAlpha(13),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFF9800).withAlpha(26),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.sticky_note_2_outlined,
                                size: 14,
                                color: const Color(0xFFFF9800).withAlpha(153)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                notes.toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFFFF9800).withAlpha(179),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Action buttons
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildActionButton(
                          'Activate',
                          Icons.check_circle_outline,
                          const Color(0xFF4CAF50),
                          widget.onActivate,
                        ),
                        _buildActionButton(
                          'Revoke',
                          Icons.block,
                          const Color(0xFFF44336),
                          widget.onRevoke,
                        ),
                        _buildActionButton(
                          'Expiry',
                          Icons.event,
                          const Color(0xFF448AFF),
                          widget.onExpiry,
                        ),
                        _buildActionButton(
                          'Migrate',
                          Icons.phonelink_erase,
                          const Color(0xFF009688),
                          widget.onMigrate,
                        ),
                        _buildActionButton(
                          'Notes',
                          Icons.note_alt_outlined,
                          const Color(0xFFFF9800),
                          widget.onNotes,
                        ),
                        _buildActionButton(
                          'Delete',
                          Icons.delete_forever,
                          const Color(0xFFB71C1C),
                          widget.onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildInfoGrid({
    required String deviceName,
    required String deviceModel,
    required String deviceId,
    required String platform,
    required Timestamp? expiryDate,
    required Timestamp? lastOnline,
    required Timestamp? registeredAt,
    bool hasAndroid = false,
    String androidDeviceName = '',
    String androidDeviceModel = '',
    bool hasWindows = false,
    String windowsDeviceName = '',
    String windowsDeviceModel = '',
  }) {
    final rows = <Widget>[];

    // Android device info
    if (hasAndroid) {
      final androidStr = [
        if (androidDeviceName.isNotEmpty) androidDeviceName,
        if (androidDeviceModel.isNotEmpty) androidDeviceModel,
      ].join(' · ');
      if (androidStr.isNotEmpty) {
        rows.add(_buildInfoRow(Icons.phone_android, 'Android', androidStr, color: const Color(0xFF4CAF50)));
      }
    }

    // Windows device info
    if (hasWindows) {
      final windowsStr = [
        if (windowsDeviceName.isNotEmpty) windowsDeviceName,
        if (windowsDeviceModel.isNotEmpty) windowsDeviceModel,
      ].join(' · ');
      if (windowsStr.isNotEmpty) {
        rows.add(_buildInfoRow(Icons.desktop_windows, 'Windows', windowsStr, color: const Color(0xFF448AFF)));
      }
    }

    // Legacy device info (backward compat)
    if (!hasAndroid && !hasWindows && (deviceName.isNotEmpty || deviceModel.isNotEmpty)) {
      final deviceStr = [
        if (deviceName.isNotEmpty) deviceName,
        if (deviceModel.isNotEmpty) deviceModel,
        if (platform.isNotEmpty) '($platform)',
      ].join(' · ');
      rows.add(_buildInfoRow(Icons.phone_android, 'Device', deviceStr));
    }

    // Legacy device ID (backward compat)
    if (!hasAndroid && !hasWindows && deviceId.isNotEmpty) {
      rows.add(_buildInfoRow(Icons.fingerprint, 'ID', deviceId));
    }

    // Expiry
    if (expiryDate != null) {
      final expiryStr =
          '${DateFormat('dd MMM yyyy').format(expiryDate.toDate())} ${_getDaysRemaining(expiryDate)}';
      rows.add(_buildInfoRow(Icons.event, 'Expiry', expiryStr));
    }

    // Last online
    rows.add(_buildInfoRow(
        Icons.access_time, 'Last online', _formatRelativeTime(lastOnline)));

    // Registered
    if (registeredAt != null) {
      rows.add(_buildInfoRow(Icons.calendar_today, 'Registered',
          DateFormat('dd MMM yyyy').format(registeredAt.toDate())));
    }

    return Column(children: rows);
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color?.withAlpha(153) ?? Colors.white24),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: color?.withAlpha(128) ?? Colors.white30,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white60,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(38)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformStatusChip(String platform, String status, Color platformColor) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withAlpha(38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            platform == 'Android' ? Icons.phone_android : Icons.desktop_windows,
            size: 11,
            color: platformColor.withAlpha(179),
          ),
          const SizedBox(width: 4),
          Text(
            '$platform: ${status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Unknown'}',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformExpiryRow(
    String platform,
    IconData icon,
    Color color,
    String status,
    Timestamp? expiry,
    Timestamp? lastOnline,
  ) {
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

    final expiryStr = expiry != null
        ? DateFormat('dd MMM yyyy').format(expiry.toDate())
        : 'N/A';
    final daysLeft = _getDaysRemaining(expiry);
    final lastOnlineStr = _formatRelativeTime(lastOnline);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Unknown',
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
            ),
          ),
          const SizedBox(width: 8),
          // Expiry
          Icon(Icons.event, size: 11, color: Colors.white30),
          const SizedBox(width: 3),
          Text(
            '$expiryStr $daysLeft',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          // Last online
          Icon(Icons.access_time, size: 11, color: Colors.white24),
          const SizedBox(width: 3),
          Text(
            lastOnlineStr,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
