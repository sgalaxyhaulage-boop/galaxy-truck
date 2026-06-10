import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_truck/models/notification.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/notification_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({super.key});

  @override
  State<DriverNotificationsScreen> createState() => _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationService>().loadNotifications();
    });
  }

  Future<void> _markAll() async {
    if (_markingAll) return;
    final auth = context.read<AuthService>();
    final notif = context.read<NotificationService>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _markingAll = true);
    try {
      await notif.markAllAsRead(user.id);
      await notif.loadNotifications();
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update notifications.')));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final notif = context.watch<NotificationService>();
    final user = auth.currentUser;
    final cs = Theme.of(context).colorScheme;

    final items = user == null ? const <AppNotification>[] : notif.getNotificationsByUser(user.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: context.textStyles.titleLarge?.semiBold),
        actions: [
          TextButton(
            onPressed: _markingAll || user == null ? null : _markAll,
            child: Text('Mark all read', style: context.textStyles.labelLarge?.semiBold.copyWith(color: cs.primary)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_outlined, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No notifications', style: context.textStyles.titleMedium?.semiBold),
                  const SizedBox(height: 6),
                  Text('Updates from admins will appear here.', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.separated(
              padding: AppSpacing.paddingMd,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _NotificationCard(notification: items[i]),
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final service = context.read<NotificationService>();
    final icon = switch (notification.type) {
      NotificationType.rentalApproved => Icons.approval,
      NotificationType.rentalRejected => Icons.block,
      NotificationType.serviceApproved => Icons.build_circle_outlined,
      NotificationType.serviceScheduled => Icons.event_available_outlined,
      NotificationType.truckDroppedOff => Icons.assignment_return_outlined,
      NotificationType.truckInService => Icons.build_outlined,
      NotificationType.waitingForParts => Icons.hourglass_bottom,
      NotificationType.serviceCompleted => Icons.verified_outlined,
      NotificationType.truckReadyForPickup => Icons.notifications_active_outlined,
      NotificationType.damageReportUpdate => Icons.warning_amber_rounded,
      NotificationType.licenceExpiry => Icons.badge_outlined,
      NotificationType.registrationExpiry => Icons.event_busy_outlined,
      NotificationType.insuranceExpiry => Icons.policy_outlined,
      NotificationType.serviceDue => Icons.schedule,
      NotificationType.general => Icons.notifications_outlined,
    };
    final accent = notification.isRead ? cs.onSurfaceVariant : cs.primary;

    return Card(
      child: InkWell(
        onTap: () async {
          if (notification.isRead) return;
          try {
            await service.markAsRead(notification.id);
          } catch (e) {
            debugPrint('Failed to mark notification as read: $e');
          }
        },
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(notification.title, style: context.textStyles.titleMedium?.semiBold)),
                        if (!notification.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(notification.message, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45)),
                    const SizedBox(height: 10),
                    Text(
                      DateFormat('dd MMM yyyy, h:mm a').format(notification.timestamp),
                      style: context.textStyles.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
