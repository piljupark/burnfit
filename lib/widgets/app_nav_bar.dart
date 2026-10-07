import 'package:flutter/material.dart';
import '../core/app_colors.dart';


class AppNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const AppNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class AppNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final List<AppNavItem> items;

  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        border: Border.all(
          color: const Color(0xFFEEEEEE),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 70,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == currentIndex;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          active ? item.activeIcon : item.icon,
                          key: ValueKey(active),
                          size: 27,
                          color: active ? const Color(0xFF111111) : const Color(0xFFBBBBBB),
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontFamily: 'WantedSans',
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? const Color(0xFF111111) : const Color(0xFFBBBBBB),
                          height: 1.0,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class AppFloatingPlusButton extends StatelessWidget {
  final VoidCallback onTap;
  const AppFloatingPlusButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
