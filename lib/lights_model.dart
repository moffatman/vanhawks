import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:vanhawks/bluetooth_picker.dart';
import 'package:vanhawks/main.dart';

const String _FRONT_LIGHT_STATUS_KEY = "front_light_status";
const String _REAR_LIGHT_STATUS_KEY = "rear_light_status";
const String _LIGHTS_ON_KEY = "lights_on";
const String _BLUETOOTH_ID_KEY = "bluetooth_id";

const Duration _SCAN_TIMEOUT = Duration(seconds: 5);

Guid _VANHAWKS_LIGHTS_CHARACTERISTICS_UUID = Guid("9ac78e8d1e9943ce83637c1b1e003a11");

enum BluetoothStatus {
	NeverConnected,
	SearchingForKnownConnection,
	KnownConnectionNotFound,
	Disconnecting,
	Connecting,
	Connected
}

enum UILockoutStatus {
	Disabled,
	Loading,
	Enabled
}

class LightsModel extends ChangeNotifier {
	BluetoothDevice device;
	BluetoothCharacteristic characteristic;
	BluetoothStatus status;
	UILockoutStatus uiStatus = UILockoutStatus.Disabled;
	String get statusText {
		switch(status) {
			case BluetoothStatus.Connected:
				return "Connected to ${device.name}";
				break;
			case BluetoothStatus.Connecting:
				return "Connecting...";
				break;
			case BluetoothStatus.Disconnecting:
				return "Disconnecting...";
				break;
			case BluetoothStatus.KnownConnectionNotFound:
				return "Not Found...";
				break;
			case BluetoothStatus.SearchingForKnownConnection:
				return "Searching...";
				break;
			case BluetoothStatus.NeverConnected:
				return "Select your device";
				break;
		}
	}
	DeviceIdentifier _savedBluetoothIdentifier;
	DeviceIdentifier get savedBluetoothIdentifier {
		return _savedBluetoothIdentifier;
	}
	set savedBluetoothIdentifier(DeviceIdentifier id) {
		if (id != null) {
			_prefs.setString(_BLUETOOTH_ID_KEY, id.id);
		}
		else {
			_prefs.remove(_BLUETOOTH_ID_KEY);
		}
		_savedBluetoothIdentifier = id;
	}
	bool initialized = false;
	int _frontLight;
	int get frontLight {
		return _frontLight;
	}
	set frontLight(int value) {
		_frontLight = value;
		print("Set front light status to $value");
		_prefs.setInt(_FRONT_LIGHT_STATUS_KEY, value);
		_updateLightsBluetooth(false);
		notifyListeners();
	}
	int _rearLight;
	int get rearLight {
		return _rearLight;
	}
	set rearLight(int value) {
		_rearLight = value;
		print("Set rear light status to $value");
		_prefs.setInt(_REAR_LIGHT_STATUS_KEY, value);
		_updateLightsBluetooth(true);
		notifyListeners();
	}
	bool _lightsOn;
	bool get lightsOn {
		return _lightsOn;
	}
	set lightsOn(bool value) {
		_lightsOn = value;
		print("Set lights on status to $value");
		_prefs.setBool(_LIGHTS_ON_KEY, value);
		_updateLightsBluetooth(false);
		notifyListeners();
	}
	bool allowLightControl = false;
	bool get activelyScanningNow {
		return status == BluetoothStatus.SearchingForKnownConnection;
	}
	SharedPreferences _prefs;

	void requestScan() {
		if (!activelyScanningNow) {
			FlutterBlue.instance.scan(timeout: _SCAN_TIMEOUT);
		}
	}

	void handleAppPause() async {
		/*if (await FlutterBlue.instance.isScanning.first) {
			print("Stopping scanning due to app pause");
			FlutterBlue.instance.stopScan();
		}*/
	}

	void handleAppResume() async {
		print("resume()");
		/*if (activelyScanningNow && !(await FlutterBlue.instance.isScanning.first)) {
			print("Restarting scanning due to app resume");
			FlutterBlue.instance.startScan();
		}*/
	}

	void _updateLightsBluetooth(bool rearFirst) async {
		if (characteristic != null) {
			uiStatus = UILockoutStatus.Loading;
			notifyListeners();
			if (lightsOn) {
				if (!rearFirst) {
					await characteristic.write([FRONT_LIGHT_ID, frontLight, frontLight]);
					print("Wrote front lights");
				}
				await characteristic.write([REAR_LIGHT_ID, rearLight, rearLight]);
				print("Wrote rear lights");
				if (rearFirst) {
					await characteristic.write([FRONT_LIGHT_ID, frontLight, frontLight]);
					print("Wrote front lights");
				}
			}
			else {
				await characteristic.write([FRONT_LIGHT_ID, FRONT_LIGHT_OFF, FRONT_LIGHT_OFF]);
				await characteristic.write([REAR_LIGHT_ID, REAR_LIGHT_OFF, REAR_LIGHT_OFF]);
				print("Wrote both lights off");
			}
			uiStatus = UILockoutStatus.Enabled;
			notifyListeners();
		}
	}

	void _initialize() async {
		_prefs = await SharedPreferences.getInstance();
		frontLight = _prefs.getInt(_FRONT_LIGHT_STATUS_KEY) ?? FRONT_LIGHT_OFF;
		rearLight = _prefs.getInt(_REAR_LIGHT_STATUS_KEY) ?? REAR_LIGHT_OFF;
		lightsOn = _prefs.getBool(_LIGHTS_ON_KEY) ?? false;
		String persistentBluetoothIdentifier = _prefs.getString(_BLUETOOTH_ID_KEY);
		if (persistentBluetoothIdentifier != null) {
			print("Trying to connect to previously known Bluetooth device: $persistentBluetoothIdentifier");
			savedBluetoothIdentifier = DeviceIdentifier(persistentBluetoothIdentifier);
			status = BluetoothStatus.SearchingForKnownConnection;
		}
		else {
			status = BluetoothStatus.NeverConnected;
		}
		if (savedBluetoothIdentifier != null) {
			List<BluetoothDevice> currentDevices = await FlutterBlue.instance.connectedDevices;
			for (BluetoothDevice currentDevice in currentDevices) {
				if (currentDevice.id == savedBluetoothIdentifier) {
					await setBluetoothDevice(currentDevice);
					break;
				}
			}
		}
		if (this.device == null) {
			FlutterBlue.instance.startScan();
			FlutterBlue.instance.scanResults.listen((results) {
				for (ScanResult result in results) {
					if ((device == null) && (savedBluetoothIdentifier != null) && (result.device.id == savedBluetoothIdentifier)) {
						setBluetoothDevice(result.device);
					}
				}
			});
		}
		initialized = true;
		notifyListeners();
	}

	Future<void> setBluetoothDevice(BluetoothDevice device) async {
		print("Connecting to ${device.id}");
		status = BluetoothStatus.Connecting;
		notifyListeners();
		if (await device.state.first != BluetoothDeviceState.connected) {
			await device.connect().timeout(Duration(seconds: 5));
		}
		else {
			print("Already connected");
		}
		print("Device: ${device.name}");
		List<BluetoothService> services = await device.discoverServices();
		for (BluetoothService service in services) {
			for (BluetoothCharacteristic characteristic in service.characteristics) {
				if (characteristic.uuid == _VANHAWKS_LIGHTS_CHARACTERISTICS_UUID) {
					this.characteristic = characteristic;
				}
			}
		}
		if (this.characteristic == null) {
			device.disconnect();
			status = BluetoothStatus.NeverConnected;
			throw BadDeviceException("Device did not have correct characteristic");
		}
		device.state.listen((newState) {
			if (newState == BluetoothDeviceState.disconnecting) {
				// notify UI
			}
		});
		this.device = device;
		savedBluetoothIdentifier = device.id;
		FlutterBlue.instance.stopScan();
		status = BluetoothStatus.Connected;
		uiStatus = UILockoutStatus.Enabled;
		notifyListeners();
	}

	Future<void> disconnectBluetoothDevice() async {
		print("Disconnecting from ${device.id}");
		status = BluetoothStatus.Disconnecting;
		notifyListeners();
		await device.disconnect();
		this.device = null;
		this.characteristic = null;
		savedBluetoothIdentifier = null;
		status = BluetoothStatus.NeverConnected;
		uiStatus = UILockoutStatus.Disabled;
		FlutterBlue.instance.startScan();
		notifyListeners();
	}

	LightsModel() {
		_initialize();
	}
}