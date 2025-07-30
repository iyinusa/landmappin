// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_node.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NavigationNodeAdapter extends TypeAdapter<NavigationNode> {
  @override
  final int typeId = 10;

  @override
  NavigationNode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NavigationNode(
      id: fields[0] as String,
      label: fields[1] as String,
      lat: fields[2] as double,
      lng: fields[3] as double,
      dx: fields[4] as double,
      dy: fields[5] as double,
      projectId: fields[6] as String,
      isAccessible: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NavigationNode obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.lat)
      ..writeByte(3)
      ..write(obj.lng)
      ..writeByte(4)
      ..write(obj.dx)
      ..writeByte(5)
      ..write(obj.dy)
      ..writeByte(6)
      ..write(obj.projectId)
      ..writeByte(7)
      ..write(obj.isAccessible);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationNodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
