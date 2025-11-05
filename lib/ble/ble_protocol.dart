/// BLE协议配置类 - 简化版
class BLEProtocolConfig {
  final String serviceUuid;
  final String writeCharacteristicUuid;
  final String readCharacteristicUuid;

  const BLEProtocolConfig({
    required this.serviceUuid,
    required this.writeCharacteristicUuid,
    required this.readCharacteristicUuid,
  });

  /// DYJV2设备默认配置
  static const BLEProtocolConfig dyjV2Config = BLEProtocolConfig(
    serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
    writeCharacteristicUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
    readCharacteristicUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  );

  /// 调试信息
  @override
  String toString() {
    return 'BLEProtocolConfig('
        'serviceUuid: $serviceUuid, '
        'writeCharacteristicUuid: $writeCharacteristicUuid, '
        'readCharacteristicUuid: $readCharacteristicUuid'
        ')';
  }
}