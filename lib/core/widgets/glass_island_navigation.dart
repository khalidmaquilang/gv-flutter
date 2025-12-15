import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GlassIslandNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const GlassIslandNavigation({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 30, // Floating 30px from bottom
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40), // Capsule shape
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Blur 10, 10
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1), // Semi-transparent white
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.home, "Home", 0),
                _buildNavItem(Icons.search, "Discover", 1),
                _buildPlusButton(2),
                _buildNavItem(Icons.message, "Inbox", 3),
                _buildNavItem(Icons.person, "Profile", 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: isSelected
                ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonCyan.withOpacity(0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlusButton(int index) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 45,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.neonPink.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(-2, 0),
            ),
            BoxShadow(
              color: AppColors.neonCyan.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: const Icon(FontAwesomeIcons.plus, color: Colors.black, size: 18),
      ),
    );
  }
}
