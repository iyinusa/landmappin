import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Modern animated dialog with professional animations
class AnimatedDialog extends StatefulWidget {
  final Widget child;
  final Duration animationDuration;
  final Curve animationCurve;
  final Color? barrierColor;
  final bool barrierDismissible;

  const AnimatedDialog({
    super.key,
    required this.child,
    this.animationDuration = const Duration(milliseconds: 400),
    this.animationCurve = Curves.easeOutCubic,
    this.barrierColor,
    this.barrierDismissible = true,
  });

  @override
  State<AnimatedDialog> createState() => _AnimatedDialogState();

  /// Show animated dialog with modern transitions
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    Duration animationDuration = const Duration(milliseconds: 400),
    Curve animationCurve = Curves.easeOutCubic,
    Color? barrierColor,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: barrierColor ?? Colors.black.withOpacity(0.5),
      barrierDismissible: barrierDismissible,
      builder: (context) => AnimatedDialog(
        animationDuration: animationDuration,
        animationCurve: animationCurve,
        barrierColor: barrierColor,
        barrierDismissible: barrierDismissible,
        child: child,
      ),
    );
  }
}

class _AnimatedDialogState extends State<AnimatedDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _blurAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Scale animation with overshoot
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    // Blur animation for backdrop
    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Subtle slide animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Animated backdrop with blur effect
            AnimatedBuilder(
              animation: _blurAnimation,
              builder: (context, child) {
                return BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: _blurAnimation.value,
                    sigmaY: _blurAnimation.value,
                  ),
                  child: Container(
                    color:
                        (widget.barrierColor ?? Colors.black.withOpacity(0.5))
                            .withOpacity(_fadeAnimation.value * 0.8),
                  ),
                );
              },
            ),

            // Dialog content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Material(
                      color: Colors.transparent,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Professional animated AlertDialog
class ModernAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final Color? backgroundColor;
  final double? borderRadius;
  final Widget? icon;

  const ModernAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.contentPadding,
    this.backgroundColor,
    this.borderRadius = 24,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(borderRadius ?? 24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null || title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      if (icon != null) ...[
                        icon!,
                        const SizedBox(height: 16),
                      ],
                      if (title != null)
                        DefaultTextStyle(
                          style:
                              Theme.of(context).textTheme.titleLarge!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                          textAlign: TextAlign.center,
                          child: title!,
                        ),
                    ],
                  ),
                ),
              if (content != null)
                Padding(
                  padding: contentPadding ??
                      const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Colors.black54,
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                    child: content!,
                  ),
                ),
              if (actions != null && actions!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    mainAxisAlignment: actions!.length == 1
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceEvenly,
                    children: actions!
                        .map((action) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: action,
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show modern alert dialog
  static Future<T?> show<T>({
    required BuildContext context,
    Widget? title,
    Widget? content,
    List<Widget>? actions,
    Widget? icon,
    Color? backgroundColor,
    double? borderRadius,
    bool barrierDismissible = true,
  }) {
    return AnimatedDialog.show<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      child: ModernAlertDialog(
        title: title,
        content: content,
        actions: actions,
        icon: icon,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Modern animated bottom sheet
class AnimatedBottomSheet extends StatefulWidget {
  final Widget child;
  final bool isScrollControlled;
  final bool enableDrag;
  final Color? backgroundColor;
  final double? borderRadius;

  const AnimatedBottomSheet({
    super.key,
    required this.child,
    this.isScrollControlled = true,
    this.enableDrag = true,
    this.backgroundColor,
    this.borderRadius = 24,
  });

  @override
  State<AnimatedBottomSheet> createState() => _AnimatedBottomSheetState();

  /// Show animated bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double? borderRadius = 24,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => AnimatedBottomSheet(
        isScrollControlled: isScrollControlled,
        enableDrag: enableDrag,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}

class _AnimatedBottomSheetState extends State<AnimatedBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(_controller),
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(widget.borderRadius ?? 24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Content
                  widget.child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Modern button styles for dialogs
class ModernDialogButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;

  const ModernDialogButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = backgroundColor ??
        (isPrimary
            ? Colors.black
            : isDestructive
                ? Colors.red.shade50
                : Colors.grey.shade100);

    Color txtColor = textColor ??
        (isPrimary
            ? Colors.white
            : isDestructive
                ? Colors.red.shade700
                : Colors.black87);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: isPrimary
                ? null
                : Border.all(
                    color: isDestructive
                        ? Colors.red.shade200
                        : Colors.grey.shade300,
                  ),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(txtColor),
                    ),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      color: txtColor,
                      fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
