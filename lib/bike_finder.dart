import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bike.dart';

const String _BLUETOOTH_ID_KEY = "bluetooth_id";
const String _BLUETOOTH_NAME_KEY = "bluetooth_name";

class BikeFinder extends ChangeNotifier {
	bool initialized = false;
	bool neverConnected = true;

	bool searching;
	Guid targetId;
	BluetoothState bluetoothState;
	Bike bike;

	DeviceIdentifier _savedBluetoothIdentifier;
	DeviceIdentifier get savedBluetoothIdentifier {
		return _savedBluetoothIdentifier;
	}
	set savedBluetoothIdentifier(DeviceIdentifier id) {
		if (id != null) {
			_preferences.setString(_BLUETOOTH_ID_KEY, id.id);
		}
		else {
			_preferences.remove(_BLUETOOTH_ID_KEY);
		}
		_savedBluetoothIdentifier = id;
	}
	String _savedBluetoothName;
	String get savedBluetoothName {
		return _savedBluetoothName;
	}
	set savedBluetoothName(String id) {
		if (id != null) {
			_preferences.setString(_BLUETOOTH_NAME_KEY, id);
		}
		else {
			_preferences.remove(_BLUETOOTH_NAME_KEY);
		}
		_savedBluetoothName = id;
	}

	SharedPreferences _preferences;

	void _initialize() async {
		_preferences = await SharedPreferences.getInstance();
		_savedBluetoothName = _preferences.getString(_BLUETOOTH_NAME_KEY);
		String _previousBluetoothIdentifierString = _preferences.getString(_BLUETOOTH_ID_KEY);
		if (_previousBluetoothIdentifierString != null) {
			_savedBluetoothIdentifier = DeviceIdentifier(_previousBluetoothIdentifierString);
		}
		FlutterBlue.instance.startScan();
		FlutterBlue.instance.scanResults.listen((scanResults) async {
			if (savedBluetoothIdentifier != null) {
				ScanResult result = scanResults.firstWhere((result) => result.device.id == savedBluetoothIdentifier);
				if (result != null && neverConnected) {
					selectBike(result.device);
				}
			}
		});
		FlutterBlue.instance.state.listen((newState) {
			bluetoothState = newState;
			notifyListeners();
		});
		FlutterBlue.instance.connectedDevices.then((devices) {
			if (savedBluetoothIdentifier != null) {
				BluetoothDevice targetDevice = devices.firstWhere((device) => device.id == savedBluetoothIdentifier);
				if (targetDevice != null && neverConnected) {
					selectBike(targetDevice);
				}
			}
		});
		initialized = true;
		notifyListeners();
	}

	BikeFinder() {
		_initialize();
	}

	@override
	void dispose() {
		super.dispose();
		FlutterBlue.instance.stopScan();
	}

	void disconnect() {
		bike.dispose();
	}

	void forget() {
		savedBluetoothName = null;
		savedBluetoothIdentifier = null;
		disconnect();
	}

	void selectBike(BluetoothDevice newDevice) async {
		FlutterBlue.instance.stopScan();
		savedBluetoothIdentifier = newDevice.id;
		savedBluetoothName = newDevice.name;
		neverConnected = false;
		if (bike != null) {
			bike.dispose();
		}
		bike = Bike(newDevice, _preferences);
		bike.addListener(() {
			notifyListeners();
		});
		notifyListeners();
	}

	static BikeFinder of(BuildContext context) {
		return Provider.of<BikeFinder>(context);
	}
}