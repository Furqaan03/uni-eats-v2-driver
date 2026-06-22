import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/driver_provider.dart';

Future<void> _openMaps(String address) async {
  final encoded = Uri.encodeComponent(address);
  // Opens Google Maps navigation; falls back to geo: URI on devices without GMaps
  final gmaps = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$encoded&travelmode=driving',
  );
  if (await canLaunchUrl(gmaps)) {
    await launchUrl(gmaps, mode: LaunchMode.externalApplication);
  } else {
    final geo = Uri.parse('geo:0,0?q=$encoded');
    await launchUrl(geo, mode: LaunchMode.externalApplication);
  }
}

class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _chevronCtrl;

  @override
  void initState() {
    super.initState();
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _chevronCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _chevronCtrl.forward();
    } else {
      _chevronCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverProvider>(
      builder: (context, driver, _) {
        final orders = driver.activeOrders;
        if (orders.isEmpty) return const SizedBox.shrink();
        final selected = driver.selectedOrder ?? orders.first;

        // Auto-collapse when a new incoming order needs attention
        if (driver.hasIncomingOrder && _expanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _expanded) {
              setState(() => _expanded = false);
              _chevronCtrl.reverse();
            }
          });
        }

        // Auto-expand when order is delivered so driver sees the earnings summary
        if (!driver.hasIncomingOrder && selected.step == DeliveryStep.delivered && !_expanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_expanded) {
              setState(() => _expanded = true);
              _chevronCtrl.forward();
            }
          });
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, -4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Order tabs — only when 2+ active
                if (orders.length > 1)
                  _OrderTabs(
                    orders: orders,
                    selectedId: selected.id,
                    onSelect: driver.selectOrder,
                  ),

                // Compact header — always visible
                _CompactHeader(
                  order: selected,
                  expanded: _expanded,
                  chevronCtrl: _chevronCtrl,
                  onToggle: _toggle,
                  driver: driver,
                ),

                // Expandable detail section
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  child: _expanded
                      ? _ExpandedDetail(order: selected, driver: driver)
                      : const SizedBox.shrink(),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Compact header (always visible) ─────────────────────────────────────────

class _CompactHeader extends StatelessWidget {
  final ActiveOrder order;
  final bool expanded;
  final AnimationController chevronCtrl;
  final VoidCallback onToggle;
  final DriverProvider driver;

  const _CompactHeader({
    required this.order,
    required this.expanded,
    required this.chevronCtrl,
    required this.onToggle,
    required this.driver,
  });

  // Destination address for navigation — switches at enRoute
  String get _navAddress => switch (order.step) {
        DeliveryStep.toRestaurant || DeliveryStep.atRestaurant => order.restaurantAddr,
        DeliveryStep.enRoute || DeliveryStep.atCustomer || DeliveryStep.delivered =>
          order.customerAddr,
      };

  String get _stepLabel => switch (order.step) {
        DeliveryStep.toRestaurant => 'Head to restaurant',
        DeliveryStep.atRestaurant => 'Pick up order',
        DeliveryStep.enRoute => 'En route to customer',
        DeliveryStep.atCustomer => 'Arrived at customer',
        DeliveryStep.delivered => 'Order delivered ✓',
      };

  Color get _stepColor => switch (order.step) {
        DeliveryStep.toRestaurant => AppColors.orange,
        DeliveryStep.atRestaurant => const Color(0xFFFFA940),
        DeliveryStep.enRoute => AppColors.green,
        DeliveryStep.atCustomer => AppColors.green,
        DeliveryStep.delivered => AppColors.green,
      };

  String get _actionLabel => switch (order.step) {
        DeliveryStep.toRestaurant => 'At Restaurant',
        DeliveryStep.atRestaurant => 'Picked Up',
        DeliveryStep.enRoute => 'Arrived',
        DeliveryStep.atCustomer => 'Delivered',
        DeliveryStep.delivered => 'Done',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          // Step dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _stepColor,
              boxShadow: [
                BoxShadow(color: _stepColor.withValues(alpha: 0.5), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Restaurant + step
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.restaurant,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _stepLabel,
                  style: TextStyle(fontSize: 11, color: _stepColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Chevron toggle
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: RotationTransition(
                turns: Tween(begin: 0.0, end: 0.5).animate(
                  CurvedAnimation(parent: chevronCtrl, curve: Curves.easeInOut),
                ),
                child: const Icon(Icons.keyboard_arrow_up_rounded,
                    color: AppColors.darkSubText, size: 22),
              ),
            ),
          ),

          // Navigate button
          GestureDetector(
            onTap: () => _openMaps(_navAddress),
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: const Icon(Icons.navigation_rounded, color: AppColors.green, size: 18),
            ),
          ),

          // Primary action button
          GestureDetector(
            onTap: () => driver.advanceDeliveryStep(order.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.orangeLight, AppColors.orangeDark],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                _actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expanded detail ──────────────────────────────────────────────────────────

class _ExpandedDetail extends StatelessWidget {
  final ActiveOrder order;
  final DriverProvider driver;

  const _ExpandedDetail({required this.order, required this.driver});

  @override
  Widget build(BuildContext context) {
    if (order.step == DeliveryStep.delivered) {
      return _DeliveredView(order: order, driver: driver);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.darkBorder, height: 1),
          const SizedBox(height: 12),

          // Step tracker
          _StepTracker(step: order.step),
          const SizedBox(height: 14),

          // Route card
          _RouteCard(order: order),
          const SizedBox(height: 10),

          // Items
          _ItemsList(order: order),
          const SizedBox(height: 10),

          // Ping
          if (order.step == DeliveryStep.enRoute && !order.pingCustomerSent)
            _PingButton(onTap: () => driver.pingCustomer(order.id)),
          if (order.step == DeliveryStep.enRoute && order.pingCustomerSent)
            _PingSentBadge(),
        ],
      ),
    );
  }
}

// ─── Order selector tabs ──────────────────────────────────────────────────────

class _OrderTabs extends StatelessWidget {
  final List<ActiveOrder> orders;
  final String selectedId;
  final void Function(String) onSelect;

  const _OrderTabs({
    required this.orders,
    required this.selectedId,
    required this.onSelect,
  });

  Color _stepColor(DeliveryStep step) => switch (step) {
        DeliveryStep.toRestaurant => AppColors.orange,
        DeliveryStep.atRestaurant => const Color(0xFFFFA940),
        DeliveryStep.enRoute => AppColors.green,
        DeliveryStep.atCustomer => AppColors.green,
        DeliveryStep.delivered => AppColors.green,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final order = orders[i];
          final isSelected = order.id == selectedId;
          final stepColor = _stepColor(order.step);
          return GestureDetector(
            onTap: () => onSelect(order.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? stepColor.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? stepColor : AppColors.darkBorder,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: stepColor),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Order ${i + 1} · ${order.restaurant.split(' ').first}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.darkText : AppColors.darkSubText,
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
}

// ─── Delivered inline view ────────────────────────────────────────────────────

class _DeliveredView extends StatelessWidget {
  final ActiveOrder order;
  final DriverProvider driver;

  const _DeliveredView({required this.order, required this.driver});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          const Divider(color: AppColors.darkBorder, height: 1),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EARNINGS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkSubText,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                _EarningRow(label: 'Delivery fee', value: 'QAR ${order.deliveryFee.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                _EarningRow(label: 'Tip', value: 'QAR ${order.tip.toStringAsFixed(2)}', accent: AppColors.green),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.darkBorder),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total payout',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkText)),
                    Text(
                      'QAR ${order.payout.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => driver.advanceDeliveryStep(order.id),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.orangeLight, AppColors.orangeDark],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Done',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.darkText),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _EarningRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;
  const _EarningRow({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.darkSubText)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent ?? AppColors.darkText,
          ),
        ),
      ],
    );
  }
}

// ─── Step tracker ─────────────────────────────────────────────────────────────

class _StepTracker extends StatelessWidget {
  final DeliveryStep step;
  const _StepTracker({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (DeliveryStep.toRestaurant, Icons.directions_bike_outlined, 'To\nRestaurant'),
      (DeliveryStep.atRestaurant, Icons.storefront_outlined, 'Pick Up'),
      (DeliveryStep.enRoute, Icons.navigation_outlined, 'Deliver'),
      (DeliveryStep.atCustomer, Icons.flag_outlined, 'Arrived'),
    ];

    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final (stepEnum, icon, label) = entry.value;
        final isDone = step.index > stepEnum.index;
        final isCurrent = step == stepEnum;
        final color = isDone || isCurrent ? AppColors.orange : AppColors.darkBorder;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? AppColors.green
                            : isCurrent
                                ? AppColors.orange.withValues(alpha: 0.15)
                                : AppColors.darkCard,
                        border: Border.all(
                          color: isDone ? AppColors.green : color,
                          width: isCurrent ? 2.5 : 1.5,
                        ),
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : icon,
                        size: 16,
                        color: isDone ? Colors.white : color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? AppColors.orange : AppColors.darkSubText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 22),
                    color: step.index > stepEnum.index ? AppColors.green : AppColors.darkBorder,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Route card ───────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final ActiveOrder order;
  const _RouteCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          _RouteRow(
            dot: AppColors.orange,
            label: 'PICKUP',
            place: '${order.restaurant} · ${order.stall}',
            sub: order.restaurantAddr,
            onNavigate: () => _openMaps(order.restaurantAddr),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 2, bottom: 2),
            child: Column(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(width: 2, height: 4, color: AppColors.darkBorder),
                  ),
                ),
              ),
            ),
          ),
          _RouteRow(
            dot: AppColors.green,
            label: 'DROPOFF',
            place: order.dropoff,
            sub: order.customerAddr,
            onNavigate: () => _openMaps(order.customerAddr),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final Color dot;
  final String label;
  final String place;
  final String sub;
  final VoidCallback? onNavigate;
  const _RouteRow({
    required this.dot,
    required this.label,
    required this.place,
    required this.sub,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFBBBBBB),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                place,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkText),
              ),
              Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.darkSubText)),
            ],
          ),
        ),
        if (onNavigate != null)
          GestureDetector(
            onTap: onNavigate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: dot.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dot.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.navigation_rounded, size: 11, color: dot),
                  const SizedBox(width: 4),
                  Text(
                    'Navigate',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dot),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Items list ───────────────────────────────────────────────────────────────

class _ItemsList extends StatelessWidget {
  final ActiveOrder order;
  const _ItemsList({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'ORDER ITEMS',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.darkSubText, letterSpacing: 0.8),
              ),
              const Spacer(),
              Text(
                '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 10, color: AppColors.darkSubText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.$2, style: const TextStyle(fontSize: 12, color: AppColors.darkText)),
                  ),
                  Text(item.$3, style: const TextStyle(fontSize: 11, color: AppColors.darkSubText)),
                ],
              ),
            ),
          ),
          const Divider(color: AppColors.darkBorder, height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontSize: 11, color: AppColors.darkSubText)),
              Text(
                'QAR ${order.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Ping button ──────────────────────────────────────────────────────────────

class _PingButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PingButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_outlined, size: 15, color: AppColors.darkText),
            SizedBox(width: 7),
            Text(
              'Ping customer — I\'m almost there',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkText),
            ),
          ],
        ),
      ),
    );
  }
}

class _PingSentBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 13, color: AppColors.green),
          SizedBox(width: 5),
          Text(
            'Customer notified ✓',
            style: TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
