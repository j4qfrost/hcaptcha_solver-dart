// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chrome.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Chrome _$ChromeFromJson(Map<String, dynamic> json) => Chrome(
      _$recordConvert(
        json['screenSize'],
        ($jsonValue) => (
          $jsonValue[r'$1'] as int,
          $jsonValue[r'$2'] as int,
        ),
      ),
      _$recordConvert(
        json['availScreenSize'],
        ($jsonValue) => (
          $jsonValue[r'$1'] as int,
          $jsonValue[r'$2'] as int,
        ),
      ),
      json['cpuCount'] as int,
      json['memorySize'] as int,
    )..unixOffset = json['unixOffset'] as int;

Map<String, dynamic> _$ChromeToJson(Chrome instance) => <String, dynamic>{
      'screenSize': {
        r'$1': instance.screenSize.$1,
        r'$2': instance.screenSize.$2,
      },
      'availScreenSize': {
        r'$1': instance.availScreenSize.$1,
        r'$2': instance.availScreenSize.$2,
      },
      'cpuCount': instance.cpuCount,
      'memorySize': instance.memorySize,
      'unixOffset': instance.unixOffset,
    };

$Rec _$recordConvert<$Rec>(
  Object? value,
  $Rec Function(Map) convert,
) =>
    convert(value as Map<String, dynamic>);
