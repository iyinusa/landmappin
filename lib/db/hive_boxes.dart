import 'package:hive/hive.dart';
import '../models/map_project.dart';
import '../models/map_point.dart';

class HiveBoxes {
  static const String mapProjects = 'mapProjects';
  static const String mapPoints = 'mapPoints';

  static Box<MapProject> getMapProjectsBox() =>
      Hive.box<MapProject>(mapProjects);
  static Box<MapPoint> getMapPointsBox() => Hive.box<MapPoint>(mapPoints);
}
