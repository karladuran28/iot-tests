#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#include "/opt/homebrew/include/MQTTClient.h"

@interface BluetoothManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *peripheral;
@end

@implementation BluetoothManager

- (instancetype)init {
    self = [super init];
    if (self) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
        NSLog(@"Escaneando dispositivos BLE...");
    } else {
        NSLog(@"Bluetooth no está disponible");
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if ([peripheral.name isEqualToString:@"HC-08"]) {
        self.peripheral = peripheral;
        [self.centralManager stopScan];
        [self.centralManager connectPeripheral:peripheral options:nil];
        NSLog(@"Conectando a HC-08...");
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Conectado a HC-08");
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        NSLog(@"Servicio encontrado: %@", service.UUID);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"Característica encontrada: %@", characteristic.UUID);
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"FFE1"]]) { // UUID de la característica TX
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSData *data = characteristic.value;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // NSLog(@"Dato recibido: %@", text);

    const char *mqtt_broker = "tcp://localhost:1883";
    const char *mqtt_topic = "sensores/datos";
    const char *mqtt_clientid = "mac_bluetooth_gateway";

    // Conectar a MQTT
    MQTTClient client;
    MQTTClient_connectOptions conn_opts = MQTTClient_connectOptions_initializer;
    conn_opts.keepAliveInterval = 20;
    conn_opts.cleansession = 1;

    MQTTClient_create(&client, mqtt_broker, mqtt_clientid, MQTTCLIENT_PERSISTENCE_NONE, NULL);
    if (MQTTClient_connect(client, &conn_opts) != MQTTCLIENT_SUCCESS) {
        NSLog(@"Error: No se pudo conectar al broker MQTT");
        return;
    }

    // Publicar datos en MQTT
    NSString *message = [NSString stringWithFormat: @"%@", text];
    if ((int)strlen([message UTF8String]) > 0) {
      MQTTClient_message pubmsg = MQTTClient_message_initializer;
      pubmsg.payload = (void *)[message UTF8String];
      pubmsg.payloadlen = (int)strlen([message UTF8String]);
      pubmsg.qos = 1;
      pubmsg.retained = 0;

      MQTTClient_deliveryToken token;
      if (MQTTClient_publishMessage(client, mqtt_topic, &pubmsg, &token) != MQTTCLIENT_SUCCESS) {
          NSLog(@"Error: No se pudo publicar el mensaje en MQTT");
      } else {
          NSLog(@"Mensaje publicado en MQTT: %@", message);
      }
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        BluetoothManager *manager = [[BluetoothManager alloc] init];
        [[NSRunLoop currentRunLoop] run]; // Mantener el programa en ejecución
    }
    return 0;
}