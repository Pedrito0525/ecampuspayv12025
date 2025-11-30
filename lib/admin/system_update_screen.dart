import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class SystemUpdateScreen extends StatefulWidget {
  const SystemUpdateScreen({super.key});

  @override
  State<SystemUpdateScreen> createState() => _SystemUpdateScreenState();
}

class _SystemUpdateScreenState extends State<SystemUpdateScreen> {
  static const Color evsuRed = Color(0xFFB91C1C);

  // State variables for security settings
  bool _systemMaintenanceMode = false;
  bool _forceUpdateMode = false;
  bool _disableAllLogins = false;
  bool _loading = true;

  // Activity log
  final List<String> _activityLog = [
    'System initialized - ${DateTime.now().toString().substring(0, 16)}',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'System Updates & Maintenance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: evsuRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            // Status Overview
            _buildStatusOverview(),

            const SizedBox(height: 24),

            // Maintenance Control Section
            _buildControlSection(
              'System Maintenance',
              'Control system maintenance mode for all users and services',
              [
                _ControlItem(
                  icon: Icons.build,
                  title: 'Maintenance Mode',
                  subtitle:
                      'Show "System Maintenance" message to users and services',
                  value: _systemMaintenanceMode,
                  onChanged: (value) => _toggleMaintenanceMode(value),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Emergency Control Section
            _buildControlSection(
              'Emergency Controls',
              'Complete system lockdown controls (auto-enabled with maintenance/update modes)',
              [
                _ControlItem(
                  icon: Icons.block,
                  title: 'Disable All Logins',
                  subtitle:
                      _systemMaintenanceMode || _forceUpdateMode
                          ? 'Auto-enabled due to maintenance/update mode'
                          : 'Prevent all users and services from logging in',
                  value: _disableAllLogins,
                  onChanged: (value) => _toggleLoginDisable(value),
                  isDestructive: true,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _applyChanges,
                    icon: const Icon(Icons.save),
                    label: const Text('Apply Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: evsuRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: evsuRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Status Log
            _buildStatusLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [evsuRed, evsuRed.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: evsuRed.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'System Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusIndicator(
                  'Users',
                  _systemMaintenanceMode ||
                          _forceUpdateMode ||
                          _disableAllLogins
                      ? 'Restricted'
                      : 'Normal',
                  _systemMaintenanceMode ||
                          _forceUpdateMode ||
                          _disableAllLogins
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusIndicator(
                  'Services',
                  _systemMaintenanceMode ||
                          _forceUpdateMode ||
                          _disableAllLogins
                      ? 'Restricted'
                      : 'Normal',
                  _systemMaintenanceMode ||
                          _forceUpdateMode ||
                          _disableAllLogins
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection(
    String title,
    String description,
    List<_ControlItem> items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                if (index > 0) Divider(height: 1, color: Colors.grey[200]),
                _buildControlItem(item),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildControlItem(_ControlItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (item.isDestructive ? Colors.red : evsuRed).withOpacity(
                0.1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              color: item.isDestructive ? Colors.red : evsuRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: item.value,
            onChanged: item.onChanged,
            activeColor: item.isDestructive ? Colors.red : evsuRed,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLog() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          ..._activityLog.reversed
              .take(10)
              .map(
                (log) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.grey[400]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          log,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _toggleMaintenanceMode(bool value) {
    setState(() {
      _systemMaintenanceMode = value;
      // Auto-disable force update mode when maintenance is enabled
      if (value) {
        _forceUpdateMode = false;
        _disableAllLogins = true; // Auto-enable emergency controls
      } else {
        // Only auto-disable emergency controls if force update is also off
        if (!_forceUpdateMode) {
          _disableAllLogins = false;
        }
      }
    });
    if (value) {
      _showConfirmationDialog(
        'Enable Maintenance Mode',
        'This will show "System Maintenance" message to all users and services attempting to login. Force Update Mode will be automatically disabled.',
        () => _confirmMaintenanceMode(value),
      );
    } else {
      _confirmMaintenanceMode(value);
    }
  }

  void _toggleForceUpdateMode(bool value) {
    setState(() {
      _forceUpdateMode = value;
      // Auto-disable maintenance mode when force update is enabled
      if (value) {
        _systemMaintenanceMode = false;
        _disableAllLogins = true; // Auto-enable emergency controls
      } else {
        // Only auto-disable emergency controls if maintenance is also off
        if (!_systemMaintenanceMode) {
          _disableAllLogins = false;
        }
      }
    });
    if (value) {
      _showConfirmationDialog(
        'Enable Force Update Mode',
        'This will show "Need to Install New Version" message to all users and services. Maintenance Mode will be automatically disabled.',
        () => _confirmForceUpdateMode(value),
      );
    } else {
      _confirmForceUpdateMode(value);
    }
  }

  void _toggleLoginDisable(bool value) {
    // Prevent manual disabling if maintenance or force update is enabled
    if (!value && (_systemMaintenanceMode || _forceUpdateMode)) {
      _showStatusToast(
        'Emergency controls cannot be disabled while Maintenance Mode or Force Update Mode is active',
      );
      return;
    }

    setState(() => _disableAllLogins = value);
    if (value) {
      _showConfirmationDialog(
        'Disable All Logins',
        'This will prevent ALL users and services from logging in. This is an emergency control.',
        () => _confirmLoginDisable(value),
        isDestructive: true,
      );
    } else {
      _confirmLoginDisable(value);
    }
  }

  void _showConfirmationDialog(
    String title,
    String content,
    VoidCallback onConfirm, {
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    // Reset to previous values
                    _systemMaintenanceMode = _systemMaintenanceMode;
                    _forceUpdateMode = _forceUpdateMode;
                    _disableAllLogins = _disableAllLogins;
                  });
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDestructive ? Colors.red : evsuRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
  }

  void _confirmMaintenanceMode(bool value) {
    _addToLog(
      value
          ? 'Maintenance mode ENABLED - Users and services will see maintenance message'
          : 'Maintenance mode DISABLED - Normal login restored',
    );
    _showStatusToast(
      value ? 'Maintenance mode enabled' : 'Maintenance mode disabled',
    );
  }

  void _confirmForceUpdateMode(bool value) {
    _addToLog(
      value
          ? 'Force update mode ENABLED - Users and services must update to login'
          : 'Force update mode DISABLED - Update requirement removed',
    );
    _showStatusToast(
      value ? 'Force update mode enabled' : 'Force update mode disabled',
    );
  }

  void _confirmLoginDisable(bool value) {
    _addToLog(
      value
          ? 'ALL LOGINS DISABLED - Emergency lockdown active'
          : 'Login restrictions REMOVED - All access restored',
    );
    _showStatusToast(
      value ? 'All logins disabled' : 'Login restrictions removed',
    );
  }

  void _applyChanges() {
    _persistSettings();
  }

  void _resetAll() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset All Settings'),
            content: const Text(
              'This will reset all system controls to normal operation. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetSettings();
                },
                style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _addToLog(String message) {
    final timestamp = DateTime.now().toString().substring(0, 16);
    setState(() {
      _activityLog.add('$timestamp: $message');

      // Keep only last 50 entries to prevent memory issues
      if (_activityLog.length > 50) {
        _activityLog.removeAt(0);
      }
    });
  }

  void _showStatusToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: evsuRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _loading = true);
      final resp = await SupabaseService.getSystemUpdateSettings();
      final settings = resp['data'] ?? {};
      setState(() {
        _systemMaintenanceMode = settings['maintenance_mode'] == true;
        _forceUpdateMode = settings['force_update_mode'] == true;
        _disableAllLogins = settings['disable_all_logins'] == true;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _persistSettings() async {
    setState(() => _loading = true);
    final resp = await SupabaseService.upsertSystemUpdateSettings(
      maintenanceMode: _systemMaintenanceMode,
      forceUpdateMode: _forceUpdateMode,
      disableAllLogins: _disableAllLogins,
      updatedBy: 'admin',
    );
    setState(() => _loading = false);
    if (resp['success'] == true) {
      _addToLog('Settings applied.');
      _showStatusToast('All system settings applied successfully');
    } else {
      _showStatusToast(resp['message'] ?? 'Failed to apply settings');
    }
  }

  Future<void> _resetSettings() async {
    setState(() => _loading = true);
    final resp = await SupabaseService.resetSystemUpdateSettings(
      updatedBy: 'admin',
    );
    setState(() => _loading = false);
    if (resp['success'] == true) {
      setState(() {
        _systemMaintenanceMode = false;
        _forceUpdateMode = false;
        _disableAllLogins = false; // Reset emergency controls as well
      });
      _addToLog('All system controls RESET to normal operation');
      _showStatusToast('All settings reset to normal');
    } else {
      _showStatusToast(resp['message'] ?? 'Failed to reset');
    }
  }
}

class _ControlItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;
  final bool isDestructive;

  _ControlItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isDestructive = false,
  });
}
