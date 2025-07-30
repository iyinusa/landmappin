// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_point.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MapPointAdapter extends TypeAdapter<MapPoint> {
  @override
  final int typeId = 1;

  @override
  MapPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MapPoint(
      label: fields[0] as String,
      dx: fields[1] as double,
      dy: fields[2] as double,
      lat: fields[3] as double,
      lng: fields[4] as double,
      projectId: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MapPoint obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.label)
      ..writeByte(1)
      ..write(obj.dx)
      ..writeByte(2)
      ..write(obj.dy)
      ..writeByte(3)
      ..write(obj.lat)
      ..writeByte(4)
      ..write(obj.lng)
      ..writeByte(5)
      ..write(obj.projectId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
