// GENERATED CODE - DO NOT MODIFY BY HAND
// Bu dosya normalde `flutter pub run build_runner build` ile üretilir.
// Paketleri kurup build_runner'ı çalıştırdığınızda bu dosya otomatik
// yeniden oluşturulacaktır — elle yazılmış bu sürüm sadece ilk
// derlemenin build_runner olmadan da çalışması içindir.

part of 'bekleyen_foto.dart';

class BekleyenFotoAdapter extends TypeAdapter<BekleyenFoto> {
  @override
  final int typeId = 0;

  @override
  BekleyenFoto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BekleyenFoto(
      yerelDosyaYolu: fields[0] as String,
      isId: fields[1] as String,
      isletmeId: fields[2] as String,
      kayitId: fields[3] as String,
      denemeSayisi: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BekleyenFoto obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.yerelDosyaYolu)
      ..writeByte(1)
      ..write(obj.isId)
      ..writeByte(2)
      ..write(obj.isletmeId)
      ..writeByte(3)
      ..write(obj.kayitId)
      ..writeByte(4)
      ..write(obj.denemeSayisi);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BekleyenFotoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
