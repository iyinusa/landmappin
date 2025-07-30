import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class AnimatedFabMenu extends StatefulWidget {
  final List<FabMenuItem> menuItems;
  final Color primaryColor;
  final Color backgroundColor;
  final IconData toggleIcon;
  final IconData closeIcon;

  const AnimatedFabMenu({
    super.key,
    required this.menuItems,
    this.primaryColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.toggleIcon = Icons.add,
    this.closeIcon = Icons.close,
  });

  @override
  State<AnimatedFabMenu> createState() => _AnimatedFabMenuState();
}

class _AnimatedFabMenuState extends State<AnimatedFabMenu>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late List<Animation<double>> _itemAnimations;

  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees rotation
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutBack,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    // Create smooth staggered animations for menu items
    _itemAnimations = List.generate(
      widget.menuItems.length,
      (index) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          index * 0.08, // Reduced stagger delay for smoother effect
          0.5 + (index * 0.08),
          curve: Curves.easeOutBack,
        ),
      )),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });

    if (_isMenuOpen) {
      _animationController.forward();
      _rotationController.forward();
    } else {
      _animationController.reverse();
      _rotationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop overlay when menu is open
        if (_isMenuOpen)
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isMenuOpen ? 1.0 : 0.0,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

        // Main FAB Menu
        Positioned(
          bottom: 16,
          left: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Menu Items with smooth vertical animations
              ...widget.menuItems
                  .asMap()
                  .entries
                  .map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final itemPosition =
                        index + 1; // Position from bottom (1, 2, 3, etc.)

                    return AnimatedBuilder(
                      animation: _itemAnimations[index],
                      builder: (context, child) {
                        final animationValue = _itemAnimations[index].value;

                        return Transform.translate(
                          offset: Offset(
                            0,
                            // Smooth slide up animation - items start from main button position
                            5.0 * itemPosition * animationValue,
                          ),
                          child: Transform.scale(
                            scale: animationValue,
                            child: Opacity(
                              opacity: animationValue,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: _buildMenuItem(item, index),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  })
                  .toList()
                  .reversed
                  .toList(), // Reverse to show items in correct order

              // Main Toggle Button with smooth animations
              AnimatedBuilder(
                animation:
                    Listenable.merge([_rotationAnimation, _scaleAnimation]),
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value * 2 * math.pi,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isMenuOpen
                              ? [
                                  widget.primaryColor,
                                  widget.primaryColor.withOpacity(0.8),
                                ]
                              : [
                                  widget.primaryColor,
                                  widget.primaryColor.withOpacity(0.9),
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.primaryColor.withOpacity(0.3),
                            blurRadius: _isMenuOpen ? 20 : 12,
                            offset: Offset(0, _isMenuOpen ? 8 : 4),
                            spreadRadius: _isMenuOpen ? 2 : 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _toggleMenu();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: _isMenuOpen ? 60 : 56,
                            height: _isMenuOpen ? 60 : 56,
                            alignment: Alignment.center,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: child,
                                );
                              },
                              child: Icon(
                                _isMenuOpen
                                    ? widget.closeIcon
                                    : widget.toggleIcon,
                                key: ValueKey(_isMenuOpen),
                                color: widget.backgroundColor,
                                size: _isMenuOpen ? 26 : 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(FabMenuItem item, int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Clean Mini FAB with subtle shadow
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: item.backgroundColor ?? widget.primaryColor,
            boxShadow: [
              BoxShadow(
                color: (item.backgroundColor ?? widget.primaryColor)
                    .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                HapticFeedback.lightImpact();
                item.onPressed();
                if (item.closeOnTap) {
                  Future.delayed(const Duration(milliseconds: 50), _toggleMenu);
                }
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  item.icon,
                  color: item.iconColor ?? widget.backgroundColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Clean label with minimal styling
        if (item.label != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              item.label!,
              style: TextStyle(
                color: widget.primaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class FabMenuItem {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool closeOnTap;

  const FabMenuItem({
    required this.icon,
    required this.onPressed,
    this.label,
    this.backgroundColor,
    this.iconColor,
    this.closeOnTap = true,
  });
}
