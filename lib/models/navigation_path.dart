/// Custom path result class for navigation
class NavigationPath {
  final List<String> nodeIds;
  final double totalDistance;
  final double estimatedTime; // in minutes
  final List<NavigationInstruction> instructions;

  NavigationPath({
    required this.nodeIds,
    required this.totalDistance,
    required this.estimatedTime,
    required this.instructions,
  });

  @override
  String toString() {
    return 'NavigationPath(nodes: ${nodeIds.length}, distance: ${totalDistance}m, time: ${estimatedTime}min)';
  }
}

/// Navigation instruction for turn-by-turn guidance
class NavigationInstruction {
  final String nodeId;
  final String instruction;
  final double distanceFromStart;
  final NavigationDirection direction;

  NavigationInstruction({
    required this.nodeId,
    required this.instruction,
    required this.distanceFromStart,
    required this.direction,
  });
}

/// Direction types for navigation
enum NavigationDirection {
  straight,
  turnLeft,
  turnRight,
  turnSlightLeft,
  turnSlightRight,
  turnSharpLeft,
  turnSharpRight,
  uturn,
  arrive,
  start,
}
