import 'package:hive/hive.dart';
part 'navigation_edge.g.dart';

@HiveType(typeId: 11)
class NavigationEdge extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String fromNodeId;

  @HiveField(2)
  String toNodeId;

  @HiveField(3)
  double distance; // Distance in meters

  @HiveField(4)
  String projectId;

  @HiveField(5)
  bool isBidirectional; // Can travel in both directions

  @HiveField(6)
  bool isAccessible; // For accessibility routing

  @HiveField(7)
  String? description; // Optional description for the path

  NavigationEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.distance,
    required this.projectId,
    this.isBidirectional = true,
    this.isAccessible = true,
    this.description,
  });

  @override
  String toString() {
    return 'NavigationEdge(id: $id, from: $fromNodeId, to: $toNodeId, distance: $distance, bidirectional: $isBidirectional)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationEdge && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}
