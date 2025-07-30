import 'package:hive/hive.dart';
part 'navigation_node.g.dart';

@HiveType(typeId: 10)
class NavigationNode extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String label;

  @HiveField(2)
  double lat;

  @HiveField(3)
  double lng;

  @HiveField(4)
  double dx; // Image coordinates

  @HiveField(5)
  double dy; // Image coordinates

  @HiveField(6)
  String projectId;

  @HiveField(7)
  bool isAccessible; // For accessibility routing

  NavigationNode({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    required this.dx,
    required this.dy,
    required this.projectId,
    this.isAccessible = true,
  });

  @override
  String toString() {
    return 'NavigationNode(id: $id, label: $label, lat: $lat, lng: $lng, dx: $dx, dy: $dy)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationNode && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}
