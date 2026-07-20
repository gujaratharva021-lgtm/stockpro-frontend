import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final Widget? floatingActionButton;
  final bool showBottomBar;
  const MainShell({super.key, required this.child, required this.currentIndex, this.floatingActionButton, this.showBottomBar = true});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  void _onTap(int index) {
    if (index == widget.currentIndex) return;
    switch (index) {
      case 0: context.go('/watchlist'); break;
      case 1: context.push('/pending-orders'); break;
      case 2: context.go('/portfolio'); break;
      case 3: context.push('/ipo'); break;
      case 4: context.push('/profile'); break;
      case 5: context.go('/dashboard'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 768;
    return isWeb ? _webLayout() : _mobileLayout();
  }

  Widget _mobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: widget.child,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.showBottomBar ? Container(
        decoration: BoxDecoration(
          color: AppColors.navBackground,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              _navItem(Icons.bookmark_border, Icons.bookmark, 'Watchlist', 0),
              _navItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Orders', 1),
              _navItem(Icons.pie_chart_outline, Icons.pie_chart, 'Portfolio', 2),
              _navItem(Icons.gavel_outlined, Icons.gavel, 'Bids', 3),
              _navItem(Icons.account_circle_outlined, Icons.account_circle, 'Profile', 4),
            ],
          ),
        ),
      ) : null,
    );
  }

  Widget _webLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.trending_up, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'OneInvest',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 16),
                _sidebarItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 5),
                _sidebarItem(Icons.bookmark_border, Icons.bookmark, 'Watchlist', 0),
                _sidebarItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Orders', 1),
                _sidebarItem(Icons.pie_chart_outline, Icons.pie_chart, 'Portfolio', 2),
                _sidebarItem(Icons.gavel_outlined, Icons.gavel, 'Bids', 3),
                _sidebarItem(Icons.account_circle_outlined, Icons.account_circle, 'Profile', 4),
                const Spacer(),
                const Divider(color: AppColors.border, height: 1),
                // Profile link at bottom
                InkWell(
                  onTap: () => context.push('/profile'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Profile', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Vertical divider
          Container(width: 1, color: AppColors.border),
          // Main content
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = widget.currentIndex == index;
    return InkWell(
      onTap: () => _onTap(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primaryDark : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primaryDark : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = widget.currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? activeIcon : icon,
                  color: isActive ? AppColors.primaryDark : AppColors.textMuted, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    color: isActive ? AppColors.primaryDark : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}