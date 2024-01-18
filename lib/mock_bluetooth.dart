import 'dart:async';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';

DeviceIdentifier _makeRandomId() {
	String idString = "";
	for (int i = 0; i < 16; i++) {
		idString += Random().nextInt(16).toRadixString(16);
	}
	return DeviceIdentifier(idString);
}

class MockBike extends BluetoothDevice {
	List<BluetoothService> _services = [];

	MockBike(this.platformName, {isVanhawks = false}) : super(
		remoteId: _makeRandomId()
	) {
		_state.add(BluetoothConnectionState.disconnected);
		if (isVanhawks) {
			_services.add(MockBikeService());
		}
		else {
			_services.add(MockInvalidService());
		}
	}

	String platformName;

	Future<void> connect({
		Duration? timeout,
		int? mtu,
		bool autoConnect = true,
	}) async {
		print("connect()");
		await Future.delayed(Duration(seconds: 1), () => null);
		_state.add(BluetoothConnectionState.connected);
		print("set state");
	}

	Future disconnect({bool queue = true, int timeout = 35}) async {
		_state.add(BluetoothConnectionState.disconnected);
	}

	Future<List<BluetoothService>> discoverServices({bool subscribeToServicesChanged = true, int timeout = 15}) async => _services;

	Stream<List<BluetoothService>> get services async* {
		
	}

	BehaviorSubject<BluetoothConnectionState> _state = BehaviorSubject<BluetoothConnectionState>();
	Stream<BluetoothConnectionState> get connectionState {
		return _state;
	}

	Future<bool> get canSendWriteWithoutResponse async {
		return true;
	}
}

class _MockBluetoothService implements BluetoothService {
	get characteristics => throw UnimplementedError();
	get includedServices => [];
	get remoteId => throw UnimplementedError();
	get deviceId => remoteId;
	get isPrimary => throw UnimplementedError();
	get serviceUuid => throw UnimplementedError();
	get uuid => serviceUuid;
}

class MockBikeService extends _MockBluetoothService {
	get characteristics {
		return [
			MockBikeCharacteristic()
		];
	}
	get includedServices => [];
	get uuid => Guid("9ac78e8d1e9943ce83637c1b1e003a10");
}

class MockInvalidService extends _MockBluetoothService {
	get characteristics {
		return [
			MockInvalidCharacteristic()
		];
	}
	get includedServices => [];
	get uuid => Guid("a0000e8d1e9943ce83637c1b1e003a11");
}

class _MockBluetoothCharacteristic implements BluetoothCharacteristic {
	get isNotifying => throw UnimplementedError();
	get descriptors => [];
	get properties => throw UnimplementedError();
	get serviceUuid => throw UnimplementedError();
	get secondaryServiceUuid => throw UnimplementedError();
	get lastValue => throw UnimplementedError();
	get uuid => throw UnimplementedError();
	get deviceId => throw UnimplementedError();
	get value => throw UnimplementedError();
	Future<bool> setNotifyValue(bool notify, {bool forceIndications = false, int timeout = 15}) async => true;
	Future<List<int>> read({int timeout = 15}) async => [];
	Future<Null> write(List<int> value, {bool withoutResponse = false, bool allowLongWrite = false, int timeout = 15}) async => null;
	Guid get characteristicUuid => throw UnimplementedError();
	BluetoothDevice get device => throw UnimplementedError();
	Stream<List<int>> get lastValueStream => throw UnimplementedError();
	Stream<List<int>> get onValueChangedStream => throw UnimplementedError();
	Stream<List<int>> get onValueReceived => throw UnimplementedError();
	 DeviceIdentifier get remoteId => throw UnimplementedError();
}

class MockInvalidCharacteristic extends _MockBluetoothCharacteristic {
	get uuid => Guid("90000e8d1e9943ce83637c1b1e003a11");
}

class MockBikeCharacteristic extends _MockBluetoothCharacteristic {
	BehaviorSubject<List<int>> _value = BehaviorSubject<List<int>>();
	get uuid => Guid("9ac78e8d1e9943ce83637c1b1e003a11");
	get lastValueStream => _value;
	Future<Null> write(List<int> value, {bool withoutResponse = false, bool allowLongWrite = false, int timeout = 15}) async {
		print("wrote to mock");
		print(value);
		if (value.length == 2 && value[0] == 0x14 && value[1] == 0x04) {
			_value.add([0, 4, 160, 15, 10, 0, 1]);
		}
	}
}

class MockFlutterBluePlus {
	MockFlutterBluePlus._();
	static Stream<List<ScanResult>> get scanResults async* {
		while (true) {
			yield [
				MockScanResult(MockBike("Vanhawks Valour", isVanhawks: true)),
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
	get advertisementData => throw UnimplementedError();
	MockBike device;
	int rssi = Random().nextInt(50) - 90;
	DateTime get timeStamp => throw UnimplementedError();
}