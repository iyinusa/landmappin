import 'package:hive/hive.dart';
part 'map_point.g.dart';

@HiveType(typeId: 1)
class MapPoint extends HiveObject {
  @HiveField(0)
  String label;

  @HiveField(1)
  double dx;

  @HiveField(2)
  double dy;

  @HiveField(3)
  double lat;

  @HiveField(4)
  double lng;

  @HiveField(5)
  String projectId; // Reference to the project this point belongs to

  MapPoint({
    required this.label,
    required this.dx,
    required this.dy,
    required this.lat,
    required this.lng,
    required this.projectId,
  });
}
