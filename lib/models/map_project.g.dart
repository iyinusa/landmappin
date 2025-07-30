// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_project.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MapProjectAdapter extends TypeAdapter<MapProject> {
  @override
  final int typeId = 0;

  @override
  MapProject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MapProject(
      name: fields[0] as String,
      imagePath: fields[1] as String,
      id: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MapProject obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapProjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
