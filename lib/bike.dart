import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bike_finder.dart';
import 'utils.dart';

const Duration _CONNECT_TIMEOUT = Duration(seconds: 5);
const String _FRONT_LIGHT_STATUS_KEY = "front_light_status";
const String _REAR_LIGHT_STATUS_KEY = "rear_light_status";
const Duration _BATTERY_CHECK_INTERVAL = Duration(seconds: 30);
Guid _VANHAWKS_LIGHTS_CHARACTERISTICS_UUID = Guid("9ac78e8d1e9943ce83637c1b1e003a11");
const int FRONT_LIGHT_ID = 3;
const int FRONT_LIGHT_OFF = 0;
const int FRONT_LIGHT_ON_LOW = 1;
const int FRONT_LIGHT_ON_HIGH = 2;
const int REAR_LIGHT_ID = 2;
const int REAR_LIGHT_OFF = 0;
const int REAR_LIGHT_ON_SOLID = 1;
const int REAR_LIGHT_ON_BLINKING = 2;

enum BikeConnectionState {
	Connecting,
	Disconnected,
	BadDevice,
	Good
}

class Bike extends ChangeNotifier {
	bool initialized = false;

	int _frontLight;
	int get frontLight {
		return _frontLight;
	}
	set frontLight(int value) {
		_frontLight = value;
		notifyListeners();
		_preferences.setInt(_FRONT_LIGHT_STATUS_KEY, value);
	}
	int _rearLight;
	int get rearLight {
		return _rearLight;
	}
	set rearLight(int value) {
		_rearLight = value;
		notifyListeners();
		_preferences.setInt(_REAR_LIGHT_STATUS_KEY, value);
	}
	int batteryMillivolts;
	int batteryMilliamps;
	bool get isConnected {
		return connectionState == BikeConnectionState.Good || connectionState == BikeConnectionState.BadDevice;
	}

	BluetoothDevice device;
	BikeConnectionState connectionState;

	SharedPreferences _preferences;

	StreamSubscription<BluetoothDeviceState> _stateSubscription;
	BluetoothCharacteristic _characteristic;
	StreamSubscription<List<int>> _characteristicSubscription;
	Completer<void> _firstBatteryRead;
	Timer _batteryCheckTimer;
	String connectionErrorMessage;

	@override
	void dispose() {
		super.dispose();
		_stateSubscription.cancel();
		_characteristicSubscription.cancel();
		device.disconnect();
	}

	Future<void> requestBatteryUpdate([Timer timer]) async {
		await _characteristic.write([0x14, 0x04]);
	}

	void _handleCharacteristicValue(List<int> value) {
		ByteData bytes = Uint8List.fromList(value).buffer.asByteData();
		if ((bytes.lengthInBytes > 2) && (bytes.getUint8(1) == 4)) {
			print('$value');
			batteryMillivolts = bytes.getUint16(2, Endian.little);
			batteryMilliamps = ((bytes.getUint8(6) != 1) ? 1 : -1) * bytes.getUint16(4, Endian.little);
			if (!_firstBatteryRead.isCompleted) {
				_firstBatteryRead.complete();
			}
		}
		else {
			print("Got unknown value response: $value");
		}
	}

	Future<void> connect() async {
		try {
			connectionState = BikeConnectionState.Connecting;
			notifyListeners();
			await device.connect(autoConnect: true).timeout(_CONNECT_TIMEOUT);
		}
		catch (e) {
			connectionState = BikeConnectionState.Disconnected;
			if (e.runtimeType == TimeoutException) {
				connectionErrorMessage = "Timed out";
			}
			else {
				connectionErrorMessage = e.toString();
			}
			notifyListeners();
		}
	}

	Future<void> _initialize() async {
		_frontLight = _preferences.getInt(_FRONT_LIGHT_STATUS_KEY) ?? FRONT_LIGHT_OFF;
		_rearLight = _preferences.getInt(_REAR_LIGHT_STATUS_KEY) ?? REAR_LIGHT_OFF;
		_stateSubscription = device.state.listen((newState) async {
			if (newState == BluetoothDeviceState.connected) {
				List<BluetoothService> services = await device.discoverServices();
				for (BluetoothService service in services) {
					for (BluetoothCharacteristic characteristic in service.characteristics) {
						if (characteristic.uuid == _VANHAWKS_LIGHTS_CHARACTERISTICS_UUID) {
							_characteristic = characteristic;
						}
					}
				}
				if (this._characteristic != null) {
					await _characteristic.setNotifyValue(true);
					if (_characteristicSubscription != null) {
						_characteristicSubscription.cancel();
						_firstBatteryRead = Completer();
					}
					_characteristicSubscription = _characteristic.value.listen(_handleCharacteristicValue);
					if (_batteryCheckTimer != null) {
						_batteryCheckTimer.cancel();
					}
					_batteryCheckTimer = Timer.periodic(_BATTERY_CHECK_INTERVAL, requestBatteryUpdate);
					try {
						retry(
							function: () async => await requestBatteryUpdate(_batteryCheckTimer),
							delayBetweenRetries: Duration(milliseconds: 100)
						);
					}
					catch (e) {
						print("Error sending initial battery request: ${e.toString()}");
					}
					print("Waiting for first battery result");
					await _firstBatteryRead.future;
					print("Got first battery result");
					try {
						retry(
							function: () async {
								await Future.wait([
									_characteristic.write([FRONT_LIGHT_ID, frontLight, frontLight]),
									_characteristic.write([REAR_LIGHT_ID, rearLight, 0])
								]);
							},
							delayBetweenRetries: Duration(milliseconds: 100)
						);
					}
					catch (e) {
						print("Error setting initial values: ${e.toString()}");
					}
					connectionErrorMessage = null;
					connectionState =  BikeConnectionState.Good;
					notifyListeners();
				}
				else {
					connectionState = BikeConnectionState.BadDevice;
					notifyListeners();
				}
			}
			else if (newState == BluetoothDeviceState.connecting) {
				connectionState = BikeConnectionState.Connecting;
				notifyListeners();
			}
			else {
				connectionState = BikeConnectionState.Disconnected;
				notifyListeners();
			}
		});
		initialized = true;
		notifyListeners();
		if (await device.state.first != BluetoothDeviceState.connected) {
			await connect();
		}
		notifyListeners();
	}

	Future<void> setFrontLight(int value) async {
		frontLight = value;
		await _characteristic.write([FRONT_LIGHT_ID, value, value]);
	}

	Future<void> setRearLight(int value) async {
		rearLight = value;
		await _characteristic.write([REAR_LIGHT_ID, value, 0]);
	}

	Bike(this.device, this._preferences) {
		_initialize();
	}

	static Bike of(BuildContext context) {
		return Provider.of<BikeFinder>(context).bike;
	}
}