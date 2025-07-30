import 'package:flutter/material.dart';
import '../services/navigation_controller.dart';

/// Widget for displaying navigation instructions and progress
class NavigationPanel extends StatelessWidget {
  final NavigationController controller;
  final VoidCallback? onStopNavigation;

  const NavigationPanel({
    super.key,
    required this.controller,
    this.onStopNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (controller.state == NavigationState.idle) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main navigation card
              _buildNavigationCard(context),

              // Navigation controls
              if (controller.state == NavigationState.navigating)
                const SizedBox(height: 8),
              if (controller.state == NavigationState.navigating)
                _buildNavigationControls(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationCard(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStateContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStateContent(BuildContext context) {
    switch (controller.state) {
      case NavigationState.loading:
        return _buildLoadingContent();
      case NavigationState.navigating:
        return _buildNavigatingContent(context);
      case NavigationState.finished:
        return _buildFinishedContent(context);
      case NavigationState.error:
        return _buildErrorContent(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLoadingContent() {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text(
          'Getting directions...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildNavigatingContent(BuildContext context) {
    final currentStep = controller.currentStep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress indicator
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: controller.directions != null
                    ? (controller.currentStepIndex + 1) /
                        controller.directions!.steps.length
                    : 0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${controller.currentStepIndex + 1}/${controller.directions?.steps.length ?? 0}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Current instruction
        if (currentStep != null) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getInstructionIcon(currentStep.instruction),
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStep.instruction,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'in ${_formatDistance(controller.distanceToNextTurn)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Distance and time info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: controller.remainingDistance,
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey[300],
                ),
                _buildInfoItem(
                  icon: Icons.access_time,
                  label: 'Time',
                  value: controller.remainingTime,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFinishedContent(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destination Reached!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'You have arrived at your destination.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error,
                color: Colors.red,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Navigation Error',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      controller.errorMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationControls(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onStopNavigation,
            icon: const Icon(Icons.stop, color: Colors.white),
            label: const Text(
              'Stop Navigation',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  IconData _getInstructionIcon(String instruction) {
    final lowerInstruction = instruction.toLowerCase();

    if (lowerInstruction.contains('turn left')) {
      return Icons.turn_left;
    } else if (lowerInstruction.contains('turn right')) {
      return Icons.turn_right;
    } else if (lowerInstruction.contains('straight') ||
        lowerInstruction.contains('continue')) {
      return Icons.straight;
    } else if (lowerInstruction.contains('u-turn')) {
      return Icons.u_turn_left;
    } else if (lowerInstruction.contains('merge')) {
      return Icons.merge;
    } else if (lowerInstruction.contains('roundabout')) {
      return Icons.roundabout_left;
    } else {
      return Icons.navigation;
    }
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters > 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${distanceInMeters.round()} m';
    }
  }
}
