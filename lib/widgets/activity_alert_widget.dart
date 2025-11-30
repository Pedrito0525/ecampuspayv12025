import 'package:flutter/material.dart';

/// Widget to display activity alerts with customizable styling
class ActivityAlertWidget extends StatelessWidget {
  final Map<String, dynamic> alertData;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;
  final bool isDismissible;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const ActivityAlertWidget({
    Key? key,
    required this.alertData,
    this.onDismiss,
    this.onTap,
    this.isDismissible = true,
    this.margin,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;
    final isTablet = screenWidth > 480 && screenWidth <= 1024;

    // Determine alert color based on type
    Color alertColor;
    IconData alertIcon;

    switch (alertData['type']) {
      case 'transfer_received':
        alertColor = Colors.green;
        alertIcon = Icons.account_balance_wallet;
        break;
      case 'transfer_sent':
        alertColor = Colors.blue;
        alertIcon = Icons.send;
        break;
      case 'service_transaction':
        alertColor = Colors.orange;
        alertIcon = Icons.payment;
        break;
      default:
        alertColor = Colors.blue;
        alertIcon = Icons.notifications;
    }

    return Container(
      margin:
          margin ??
          EdgeInsets.symmetric(
            horizontal: isWeb ? 24 : (isTablet ? 20 : 16),
            vertical: isWeb ? 12 : 8,
          ),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
            border: Border.all(color: alertColor.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: alertColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
            child: Padding(
              padding: padding ?? EdgeInsets.all(isWeb ? 16 : 12),
              child: Row(
                children: [
                  // Alert icon
                  Container(
                    width: isWeb ? 40 : 36,
                    height: isWeb ? 40 : 36,
                    decoration: BoxDecoration(
                      color: alertColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isWeb ? 20 : 18),
                    ),
                    child: Icon(
                      alertIcon,
                      color: alertColor,
                      size: isWeb ? 20 : 18,
                    ),
                  ),

                  SizedBox(width: isWeb ? 12 : 10),

                  // Alert content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          alertData['title'] ?? 'New Activity',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : (isTablet ? 15 : 14),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: isWeb ? 4 : 3),

                        // Message
                        Text(
                          alertData['message'] ?? 'You have new activity',
                          style: TextStyle(
                            fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                            color: const Color(0xFF666666),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Timestamp
                        if (alertData['timestamp'] != null) ...[
                          SizedBox(height: isWeb ? 4 : 3),
                          Text(
                            _formatTimestamp(alertData['timestamp']),
                            style: TextStyle(
                              fontSize: isWeb ? 12 : 11,
                              color: const Color(0xFF999999),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Dismiss button
                  if (isDismissible)
                    IconButton(
                      onPressed: onDismiss,
                      icon: Icon(
                        Icons.close,
                        size: isWeb ? 20 : 18,
                        color: const Color(0xFF999999),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Format timestamp to relative time (e.g., "2 minutes ago")
  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }
}

/// Floating alert banner that can be shown at the top of screens
class FloatingActivityAlert extends StatelessWidget {
  final Map<String, dynamic> alertData;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;
  final Duration? autoHideDuration;

  const FloatingActivityAlert({
    Key? key,
    required this.alertData,
    this.onDismiss,
    this.onTap,
    this.autoHideDuration = const Duration(seconds: 8),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;

    // Auto-hide after specified duration
    if (autoHideDuration != null) {
      Future.delayed(autoHideDuration!, () {
        if (context.mounted) {
          onDismiss?.call();
        }
      });
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + (isWeb ? 20 : 16),
      left: isWeb ? 24 : 16,
      right: isWeb ? 24 : 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
        child: ActivityAlertWidget(
          alertData: alertData,
          onDismiss: onDismiss,
          onTap: onTap,
          isDismissible: true,
          margin: EdgeInsets.zero,
          padding: EdgeInsets.all(isWeb ? 16 : 12),
        ),
      ),
    );
  }
}

/// Snackbar-style alert for quick notifications
class ActivityAlertSnackBar extends StatelessWidget {
  final Map<String, dynamic> alertData;
  final VoidCallback? onDismiss;

  const ActivityAlertSnackBar({
    Key? key,
    required this.alertData,
    this.onDismiss,
  }) : super(key: key);

  static void show(BuildContext context, Map<String, dynamic> alertData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIconForType(alertData['type']),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alertData['title'] ?? 'New Activity',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (alertData['message'] != null)
                    Text(
                      alertData['message'],
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _getColorForType(alertData['type']),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Could navigate to transaction details
          },
        ),
      ),
    );
  }

  static IconData _getIconForType(String? type) {
    switch (type) {
      case 'transfer_received':
        return Icons.account_balance_wallet;
      case 'transfer_sent':
        return Icons.send;
      case 'service_transaction':
        return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  static Color _getColorForType(String? type) {
    switch (type) {
      case 'transfer_received':
        return Colors.green;
      case 'transfer_sent':
        return Colors.blue;
      case 'service_transaction':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    // This widget is primarily used for the static show method
    return const SizedBox.shrink();
  }
}
