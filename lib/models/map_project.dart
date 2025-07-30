import 'package:hive/hive.dart';
part 'map_project.g.dart';

@HiveType(typeId: 0)
class MapProject extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String imagePath;

  @HiveField(2)
  String id; // Unique identifier for the project

  MapProject({required this.name, required this.imagePath, required this.id});
}
