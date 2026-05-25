import 'dart:async';

import 'package:flutter/material.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import 'approval_screen.dart';
import 'inventory_screen.dart';
import 'my_dashboard_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _NavTab {
  const _NavTab({
    required this.title,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
  final String title;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // Base tabs everyone sees. Approval tab is inserted before profile only for
  // managers — see `_visibleTabs()`.
  static const _baseTabs = <_NavTab>[
    _NavTab(
      title: 'ໜ້າຫຼັກ',
      label: 'ໜ້າຫຼັກ',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      page: MyDashboardScreen(),
    ),
    _NavTab(
      title: 'Sale Order',
      label: 'Sale',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      page: OrdersScreen(),
    ),
    _NavTab(
      title: 'ສິນຄ້າຄົງເຫຼືອ',
      label: 'ສິນຄ້າ',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      page: InventoryScreen(),
    ),
  ];

  static const _approvalTab = _NavTab(
    title: 'ການອະນຸມັດ',
    label: 'ອະນຸມັດ',
    icon: Icons.fact_check_outlined,
    activeIcon: Icons.fact_check,
    page: ApprovalScreen(),
  );

  static const _profileTab = _NavTab(
    title: 'ໂປຣໄຟລ໌',
    label: 'ໂປຣໄຟລ໌',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    page: ProfileScreen(),
  );

  List<_NavTab> _visibleTabs(BuildContext context) {
    final me = AppScope.of(context).auth.employee;
    return [
      ..._baseTabs,
      if (me?.appRole == AppRole.manager) _approvalTab,
      _profileTab,
    ];
  }

  // Managers see a count badge on the approval tab so they don't have to keep
  // opening it to check. Polled every 30s while the home screen is mounted.
  int _pendingApprovals = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBadge());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshBadge(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBadge() async {
    if (!mounted) return;
    try {
      final n = await AppScope.of(context).api.fetchPriceRequestPendingCount();
      if (mounted && n != _pendingApprovals) {
        setState(() => _pendingApprovals = n);
      }
    } catch (_) {
      // Silent — badge is a nice-to-have, don't bother the user if it fails.
    }
  }

  // Wraps an icon in a Badge when the tab has pending count. Flutter's
  // Badge.count handles the "99+" overflow, the red pill, and accessibility
  // labels — no custom painter needed.
  Widget _navIcon(IconData icon, int badge) {
    final iconWidget = Icon(icon);
    if (badge <= 0) return iconWidget;
    return Badge.count(count: badge, child: iconWidget);
  }

  void _onTab(int i) {
    setState(() => _index = i);
    // Tab change is a free opportunity to refresh the badge — catches counts
    // that drifted since the last 30s poll.
    _refreshBadge();
  }

  PreferredSizeWidget _appBar(String title) {
    return AppBar(
      title: Text(title),
      // Theme already styles this — no gradient monogram or subtitle.
      // The screens themselves give the user enough context.
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs(context);
    // If role changed (e.g. demoted from manager → no approval tab), clamp
    // the selected index so we don't index out of bounds.
    final safeIndex = _index >= tabs.length ? 0 : _index;
    final badges = {
      for (var i = 0; i < tabs.length; i++)
        if (tabs[i].label == _approvalTab.label && _pendingApprovals > 0)
          i: _pendingApprovals,
    };

    final useRail = isTablet(context);
    // Tab 0 (dashboard) renders its own greeting header inline; the shell
    // AppBar would duplicate that. Every other tab keeps the AppBar.
    final showAppBar = safeIndex != 0;

    final stack = IndexedStack(
      index: safeIndex,
      children: tabs.map((t) => t.page).toList(),
    );

    if (useRail) {
      // Tablet layout — NavigationRail on the left replaces the bottom bar.
      return Scaffold(
        appBar: showAppBar ? _appBar(tabs[safeIndex].title) : null,
        body: SafeArea(
          top: !showAppBar,
          bottom: false,
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: safeIndex,
                onDestinationSelected: _onTab,
                labelType: NavigationRailLabelType.all,
                useIndicator: true,
                indicatorColor: AppColors.primary50,
                selectedIconTheme: const IconThemeData(
                  color: AppColors.primary,
                  size: 24,
                ),
                unselectedIconTheme: IconThemeData(
                  color: AppColors.textMuted,
                  size: 24,
                ),
                selectedLabelTextStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                backgroundColor: AppColors.cardBg,
                destinations: [
                  for (var i = 0; i < tabs.length; i++)
                    NavigationRailDestination(
                      icon: _navIcon(tabs[i].icon, badges[i] ?? 0),
                      selectedIcon:
                          _navIcon(tabs[i].activeIcon, badges[i] ?? 0),
                      label: Text(tabs[i].label),
                    ),
                ],
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.divider,
              ),
              Expanded(child: stack),
            ],
          ),
        ),
      );
    }

    // Phone layout — NavigationBar at the bottom. Theme handles colours;
    // each destination uses its outlined icon by default and the filled
    // variant when selected.
    return Scaffold(
      appBar: showAppBar ? _appBar(tabs[safeIndex].title) : null,
      body: SafeArea(top: !showAppBar, bottom: false, child: stack),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: _onTab,
        height: 68,
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary50,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (var i = 0; i < tabs.length; i++)
            NavigationDestination(
              icon: _navIcon(tabs[i].icon, badges[i] ?? 0),
              selectedIcon: _navIcon(tabs[i].activeIcon, badges[i] ?? 0),
              label: tabs[i].label,
              tooltip: tabs[i].title,
            ),
        ],
      ),
    );
  }
}