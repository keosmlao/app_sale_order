import 'package:flutter/material.dart';
import '../app_theme.dart';
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

  static const _tabs = <_NavTab>[
    _NavTab(
      title: 'ໜ້າຫຼັກ',
      label: 'ໜ້າຫຼັກ',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      page: MyDashboardScreen(),
    ),
    _NavTab(
      title: 'Sale Order',
      label: 'ຂາຍ',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      page: OrdersScreen(),
    ),
    _NavTab(
      title: 'ສິນຄ້າຄົງເຫຼືອ',
      label: 'ສິນຄ້າ',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      page: InventoryScreen(),
    ),
    _NavTab(
      title: 'ໂປຣໄຟລ໌',
      label: 'ຂ້ອຍ',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      page: ProfileScreen(),
    ),
  ];

  void _onTab(int i) {
    setState(() => _index = i);
  }

  PreferredSizeWidget _appBar(String title) {
    return premiumAppBar(context, title);
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _index >= _tabs.length ? 0 : _index;
    final useRail = isTablet(context);
    // Tabs 0 (dashboard), 1 (orders) and 2 (inventory) render their own custom
    // headers inline, so only the profile tab keeps the shared app bar.
    final showAppBar = safeIndex != 0 && safeIndex != 1 && safeIndex != 2;

    final stack = IndexedStack(
      index: safeIndex,
      children: _tabs.map((t) => t.page).toList(),
    );

    if (useRail) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: showAppBar ? _appBar(_tabs[safeIndex].title) : null,
        body: SafeArea(
          top: !showAppBar,
          bottom: false,
          child: Row(
            children: [
              _SideRail(
                index: safeIndex,
                items: _tabs
                    .map(
                      (t) => (
                        icon: t.icon,
                        activeIcon: t.activeIcon,
                        label: t.label,
                      ),
                    )
                    .toList(),
                onTap: _onTab,
              ),
              Expanded(child: _HomeContentSurface(child: stack)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: false,
      appBar: showAppBar ? _appBar(_tabs[safeIndex].title) : null,
      body: SafeArea(
        top: !showAppBar,
        bottom: false,
        child: _HomeContentSurface(child: stack),
      ),
      bottomNavigationBar: _HomeBottomNav(
        index: safeIndex,
        items: _tabs
            .map(
              (t) => (icon: t.icon, activeIcon: t.activeIcon, label: t.label),
            )
            .toList(),
        onTap: _onTab,
      ),
    );
  }
}

class _HomeContentSurface extends StatelessWidget {
  const _HomeContentSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.bg, child: child);
  }
}

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.index,
    required this.items,
    required this.onTap,
  });

  final int index;
  final List<({IconData icon, IconData activeIcon, String label})> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(kSpace3, kSpace2, kSpace3, bottomInset),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    icon: items[i].icon,
                    activeIcon: items[i].activeIcon,
                    label: items[i].label,
                    selected: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: kMotionMed,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(
                      alpha: ThemeService.isDark ? 0.22 : 0.11,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? activeIcon : icon, color: color, size: 21),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OdooRailBrand extends StatelessWidget {
  const _OdooRailBrand();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: const Text(
              'O',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Sale',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _OdooRailFooter extends StatelessWidget {
  const _OdooRailFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(
          alpha: ThemeService.isDark ? 0.18 : 0.1,
        ),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Icon(Icons.storefront_rounded, color: AppColors.accent, size: 22),
    );
  }
}

class _OdooRailBackground extends StatelessWidget {
  const _OdooRailBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ThemeService.isDark ? AppColors.cardBg : AppColors.primary50,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: child,
    );
  }
}

class _RailItemSurface extends StatelessWidget {
  const _RailItemSurface({
    required this.selected,
    required this.child,
    required this.onTap,
  });

  final bool selected;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: AnimatedContainer(
          duration: kMotionMed,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? AppColors.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: selected
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.18))
                : null,
          ),
          child: Stack(
            children: [
              if (selected)
                Positioned(
                  left: 0,
                  top: 10,
                  bottom: 10,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(kRadiusPill),
                    ),
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItemIcon extends StatelessWidget {
  const _RailItemIcon({
    required this.selected,
    required this.icon,
    required this.activeIcon,
  });

  final bool selected;
  final IconData icon;
  final IconData activeIcon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kMotionMed,
      width: 42,
      height: 34,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      alignment: Alignment.center,
      child: Icon(
        selected ? activeIcon : icon,
        color: selected ? AppColors.primary : AppColors.textMuted,
        size: 22,
      ),
    );
  }
}

class _RailItemLabel extends StatelessWidget {
  const _RailItemLabel({required this.selected, required this.label});

  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: selected ? AppColors.primary : AppColors.textMuted,
        fontSize: 11,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
      ),
    );
  }
}

// Tablet-only side rail in Odoo-style purple navigation.
class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.index,
    required this.items,
    required this.onTap,
  });
  final int index;
  final List<({IconData icon, IconData activeIcon, String label})> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: _OdooRailBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            kSpace2,
            kSpace3,
            kSpace2,
            kSpace3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _OdooRailBrand(),
              const SizedBox(height: kSpace4),
              for (var i = 0; i < items.length; i++) ...[
                _RailItem(
                  icon: items[i].icon,
                  activeIcon: items[i].activeIcon,
                  label: items[i].label,
                  selected: i == index,
                  onTap: () => onTap(i),
                ),
                const SizedBox(height: kSpace2),
              ],
              const Spacer(),
              const _OdooRailFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RailItemSurface(
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: kSpace2),
        child: Column(
          children: [
            _RailItemIcon(
              selected: selected,
              icon: icon,
              activeIcon: activeIcon,
            ),
            const SizedBox(height: 4),
            _RailItemLabel(selected: selected, label: label),
          ],
        ),
      ),
    );
  }
}
