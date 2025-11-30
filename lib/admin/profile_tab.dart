import 'package:flutter/material.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  static const Color evsuRed = Color(0xFFB01212);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: evsuRed.withOpacity(0.1),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          size: 40,
                          color: evsuRed,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _changeProfilePicture,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: evsuRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Maria Christina Santos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  const Text(
                    'System Administrator',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'admin@evsu.edu.ph',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatusChip(
                        label: 'Active',
                        color: Colors.green,
                        icon: Icons.check_circle,
                      ),
                      _StatusChip(
                        label: 'Level 5',
                        color: evsuRed,
                        icon: Icons.security,
                      ),
                      _StatusChip(
                        label: 'Online',
                        color: Colors.blue,
                        icon: Icons.online_prediction,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Account Management
            const Text(
              'Account Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: evsuRed,
              ),
            ),
            const SizedBox(height: 12),
            _MenuSection(
              children: [
                _MenuItem(
                  icon: Icons.edit,
                  title: 'Edit Profile',
                  subtitle: 'Update personal information',
                  onTap: _editProfile,
                ),
                _MenuItem(
                  icon: Icons.lock,
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: _changePassword,
                ),
                _MenuItem(
                  icon: Icons.security,
                  title: 'Two-Factor Authentication',
                  subtitle: 'Enable additional security',
                  onTap: _manageTwoFactor,
                  trailing: Switch(
                    value: true,
                    onChanged: (value) => _toggleTwoFactor(value),
                    activeColor: evsuRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // System Settings
            const Text(
              'System Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: evsuRed,
              ),
            ),
            const SizedBox(height: 12),
            _MenuSection(
              children: [
                _MenuItem(
                  icon: Icons.notifications,
                  title: 'Notification Settings',
                  subtitle: 'Manage alerts and notifications',
                  onTap: _notificationSettings,
                ),
                _MenuItem(
                  icon: Icons.access_time,
                  title: 'Session Timeout',
                  subtitle: 'Auto-logout after inactivity',
                  onTap: _sessionSettings,
                ),
                _MenuItem(
                  icon: Icons.language,
                  title: 'Language & Region',
                  subtitle: 'English (Philippines)',
                  onTap: _languageSettings,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Activity & Logs
            const Text(
              'Activity & Logs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: evsuRed,
              ),
            ),
            const SizedBox(height: 12),
            _MenuSection(
              children: [
                _MenuItem(
                  icon: Icons.history,
                  title: 'Login History',
                  subtitle: 'View recent login activities',
                  onTap: _viewLoginHistory,
                ),
                _MenuItem(
                  icon: Icons.list_alt,
                  title: 'Activity Logs',
                  subtitle: 'System administration activities',
                  onTap: _viewActivityLogs,
                ),
                _MenuItem(
                  icon: Icons.download,
                  title: 'Export Data',
                  subtitle: 'Download your activity data',
                  onTap: _exportData,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Activity Feed
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Activities',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    itemBuilder:
                        (context, index) => _ActivityItem(
                          title: _getActivityTitle(index),
                          time: _getActivityTime(index),
                          icon: _getActivityIcon(index),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  void _changeProfilePicture() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Change Profile Picture',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: evsuRed),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage('Camera opened');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: evsuRed),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage('Gallery opened');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Picture'),
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage('Profile picture removed');
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _editProfile() {
    _showMessage('Opening profile editor...');
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                onPressed: () {
                  Navigator.pop(context);
                  _showMessage('Password updated successfully');
                },
                child: const Text(
                  'Update',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _manageTwoFactor() {
    _showMessage('Opening two-factor authentication settings...');
  }

  void _toggleTwoFactor(bool value) {
    _showMessage(
      value
          ? 'Two-factor authentication enabled'
          : 'Two-factor authentication disabled',
    );
  }

  void _notificationSettings() {
    _showMessage('Opening notification settings...');
  }

  void _sessionSettings() {
    _showMessage('Opening session settings...');
  }

  void _languageSettings() {
    _showMessage('Opening language settings...');
  }

  void _viewLoginHistory() {
    _showMessage('Opening login history...');
  }

  void _viewActivityLogs() {
    _showMessage('Opening activity logs...');
  }

  void _exportData() {
    _showMessage('Preparing data export...');
  }

  void _logout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _showMessage('Logged out successfully');
                  // Navigate to login page
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: evsuRed));
  }

  String _getActivityTitle(int index) {
    const activities = [
      'Approved transaction TXN-001234',
      'Updated system settings',
      'Exported monthly report',
      'Reset user password',
      'Login from new device',
    ];
    return activities[index];
  }

  String _getActivityTime(int index) {
    const times = [
      '2 minutes ago',
      '1 hour ago',
      '3 hours ago',
      '1 day ago',
      '2 days ago',
    ];
    return times[index];
  }

  IconData _getActivityIcon(int index) {
    const icons = [
      Icons.check_circle,
      Icons.settings,
      Icons.file_download,
      Icons.refresh,
      Icons.login,
    ];
    return icons[index];
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final List<Widget> children;

  const _MenuSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _MenuItem.evsuRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _MenuItem.evsuRed, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ActivityItem extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final String title;
  final String time;
  final IconData icon;

  const _ActivityItem({
    required this.title,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _ActivityItem.evsuRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: _ActivityItem.evsuRed, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
