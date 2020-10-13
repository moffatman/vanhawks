import 'dart:async';
import 'dart:math';

import 'package:flutter_blue/flutter_blue.dart';
import 'package:rxdart/rxdart.dart';

class MockBike implements BluetoothDevice {
	MockBike(this.name) {
		_state.add(BluetoothDeviceState.disconnected);
		String idString = "";
		for (int i = 0; i < 16; i++) {
			idString += Random().nextInt(16).toRadixString(16);
		}
		id = DeviceIdentifier(idString);
	}

	DeviceIdentifier id;

	Stream<bool> get isDiscoveringServices async* {
		yield false;
	}

	String name;

	BluetoothDeviceType get type {
		return BluetoothDeviceType.le;
	}

	Future<void> connect({
		Duration timeout,
		bool autoConnect = true,
	}) async {
		print("connect()");
		await Future.delayed(Duration(seconds: 1), () => null);
		_state.add(BluetoothDeviceState.connected);
		print("set state");
	}

	Future disconnect() async {
		_state.add(BluetoothDeviceState.disconnected);
	}

	Future<List<BluetoothService>> discoverServices() async {
		return [
			MockBikeService()
		];
	}

	Stream<List<BluetoothService>> get services async* {
		
	}

	BehaviorSubject<BluetoothDeviceState> _state = BehaviorSubject<BluetoothDeviceState>();
	Stream<BluetoothDeviceState> get state {
		return _state;
	}

	Stream<int> get mtu async* {
		
	}

	Future<void> requestMtu(int desiredMtu) async {

	}

	Future<bool> get canSendWriteWithoutResponse async {
		return true;
	}
}

class MockBikeService implements BluetoothService {
	get characteristics {
		return [
			MockBikeCharacteristic()
		];
	}
	get includedServices => [];
	get deviceId => null;
	get isPrimary => null;
	get uuid => null;
}

class MockBikeCharacteristic implements BluetoothCharacteristic {
	BehaviorSubject<List<int>> _value = BehaviorSubject<List<int>>();
	get isNotifying => null;
	get descriptors => null;
	get properties => null;
	get serviceUuid => null;
	get secondaryServiceUuid => null;
	get lastValue => null;
	get uuid => Guid("9ac78e8d1e9943ce83637c1b1e003a11");
	get deviceId => null;
	get value => _value;
	Future<bool> setNotifyValue(bool notify) async => true;
	Future<List<int>> read() async => [];
	Future<Null> write(List<int> value, {bool withoutResponse = false}) async {
		print("wrote to mock");
		print(value);
		if (value.length == 2 && value[0] == 0x14 && value[1] == 0x04) {
			_value.add([0, 4, 160, 15, 10, 0, 1]);
		}
	}
}

class MockFlutterBlue {
	MockFlutterBlue._();
	static MockFlutterBlue _instance = MockFlutterBlue._();
	static MockFlutterBlue get instance => _instance;
	Stream<List<ScanResult>> get scanResults async* {
		while (true) {
			yield [
				MockScanResult(MockBike("Vanhawks Valour")),
				MockScanResult(MockBike("")),
				MockScanResult(MockBike("")),
				MockScanResult(MockBike(""))
			];
			await Future.delayed(Duration(seconds: 5), () => null);
		}
	}
}

class MockScanResult implements ScanResult {
	MockScanResult(this.device);
	get advertisementData => null;
	MockBike device;
	int rssi = Random().nextInt(50) - 90;
}