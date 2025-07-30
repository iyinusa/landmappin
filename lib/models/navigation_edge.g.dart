// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_edge.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NavigationEdgeAdapter extends TypeAdapter<NavigationEdge> {
  @override
  final int typeId = 11;

  @override
  NavigationEdge read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NavigationEdge(
      id: fields[0] as String,
      fromNodeId: fields[1] as String,
      toNodeId: fields[2] as String,
      distance: fields[3] as double,
      projectId: fields[4] as String,
      isBidirectional: fields[5] as bool,
      isAccessible: fields[6] as bool,
      description: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NavigationEdge obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fromNodeId)
      ..writeByte(2)
      ..write(obj.toNodeId)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.projectId)
      ..writeByte(5)
      ..write(obj.isBidirectional)
      ..writeByte(6)
      ..write(obj.isAccessible)
      ..writeByte(7)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationEdgeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
