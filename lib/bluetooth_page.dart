import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bike_page.dart';
import 'bluetooth_row.dart';
import 'mock_bluetooth.dart';

const String _BLUETOOTH_ID_KEY = "bluetooth_id";
const String _BLUETOOTH_NAME_KEY = "bluetooth_name";
const String _PASSED_FIRST_LAUNCH_KEY = "passed_first_launch";

class BluetoothPage extends StatefulWidget {
	final bool forgetPreviousDevice;

	BluetoothPage({
		this.forgetPreviousDevice = false
	});

	_BluetoothPageState createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
	SharedPreferences _prefs;
	bool _initialized = false;
	bool _beforeConnect = true;
	BluetoothState _bluetoothState;
	bool _withinFirstFiveSeconds = true;
	bool _mockBluetooth = false;

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
	String _savedBluetoothName;
	String get savedBluetoothName {
		return _savedBluetoothName;
	}
	set savedBluetoothName(String id) {
		if (id != null) {
			_prefs.setString(_BLUETOOTH_NAME_KEY, id);
		}
		else {
			_prefs.remove(_BLUETOOTH_NAME_KEY);
		}
		_savedBluetoothName = id;
	}
	bool _passedFirstLaunch;
	bool get passedFirstLaunch {
		return _passedFirstLaunch;
	}
	set passedFirstLaunch(bool value) {
		_prefs.setBool(_PASSED_FIRST_LAUNCH_KEY, value);
		_passedFirstLaunch = value;
	}

	StreamSubscription<BluetoothState> _stateSubscription;
	StreamSubscription<List<ScanResult>> _scanSubscription;
	Timer _recheckConnectedDevicesTimer;

	void _initialize() async {
		_prefs = await SharedPreferences.getInstance();
		savedBluetoothName = _prefs.getString(_BLUETOOTH_NAME_KEY);
		passedFirstLaunch = _prefs.getBool(_PASSED_FIRST_LAUNCH_KEY) ?? Platform.isIOS;
		String _previousBluetoothIdentifierString = _prefs.getString(_BLUETOOTH_ID_KEY);
		if (_previousBluetoothIdentifierString != null) {
			if (widget.forgetPreviousDevice) {
				savedBluetoothIdentifier = null;
				savedBluetoothName = null;
			}
			else {
				savedBluetoothIdentifier = DeviceIdentifier(_previousBluetoothIdentifierString);
			}
		}
		_bluetoothState = await FlutterBlue.instance.state.first;
		if (passedFirstLaunch && (_bluetoothState == BluetoothState.on) && !(await FlutterBlue.instance.isScanning.first)) {
			FlutterBlue.instance.startScan();
		}
		_initialized = true;
	}

	@override
	void initState() {
		super.initState();
		_initialize();
		_scanSubscription = FlutterBlue.instance.scanResults.listen((scanResults) async {
			if (savedBluetoothIdentifier != null) {
				Iterable<ScanResult> results = scanResults.where((result) => result.device.id == savedBluetoothIdentifier);
				if (results.length > 0 && _beforeConnect) {
					_tapBike(results.first.device, results.first.rssi);
				}
			}
		});
		_stateSubscription = FlutterBlue.instance.state.listen((newState) async {
			if (mounted) {
				setState(() {
					_bluetoothState = newState;
				});
				if (newState == BluetoothState.on) {
					if (passedFirstLaunch && !(await FlutterBlue.instance.isScanning.first)) {
						FlutterBlue.instance.startScan();
					}
				}
			}
		});
		_recheckConnectedDevicesTimer = Timer.periodic(Duration(seconds: 2), _recheckConnectedDevices);
		_recheckConnectedDevices(_recheckConnectedDevicesTimer);
		Timer(Duration(seconds: 5), () {
			if (mounted) {
				setState(() {
					_withinFirstFiveSeconds = false;
				});
			}
		});
	}

	void _recheckConnectedDevices(Timer timer) {
		FlutterBlue.instance.connectedDevices.then((devices) {
			if (savedBluetoothIdentifier != null) {
				BluetoothDevice targetDevice = devices.firstWhere((device) => device.id == savedBluetoothIdentifier, orElse: () => null);
				if (targetDevice != null && _beforeConnect) {
					_tapBike(targetDevice, null);
				}
			}
		}).catchError((error) {
			if (!kReleaseMode &&  error.runtimeType == PlatformException) {
				setState(() {
					_mockBluetooth = true;
					_initialized = true;
				});
			}
		});
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
	}

	@override
	void dispose() {
		FlutterBlue.instance.stopScan();
		_stateSubscription.cancel();
		_scanSubscription.cancel();
		_recheckConnectedDevicesTimer.cancel();
		super.dispose();
	}

	Future<void> _tapBike(BluetoothDevice device, int rssi) async {
		setState(() {
			savedBluetoothIdentifier = device.id;
			savedBluetoothName = device.name;
			_beforeConnect = false;
		});
		await Navigator.of(context).pushReplacement(
			PageTransition(
				type: PageTransitionType.fade,
				child: BikePage(
					device: device,
					rssi: rssi
				)
			)
		);
	}

	String _getNoBluetoothMessage() {
		if (_bluetoothState == BluetoothState.off) {
			return "Bluetooth is off";
		}
		else if (_bluetoothState == BluetoothState.unauthorized) {
			return "Bluetooth permissions are not granted";
		}
		else if (_bluetoothState == BluetoothState.unavailable) {
			return "Bluetooth is unavailable";
		}
		else {
			if (_withinFirstFiveSeconds) {
				return "Waiting for Bluetooth permission";
			}
			return "Unknown problem with bluetooth";
		}
	}

	Widget _cardContents(BuildContext context) {
		if (!_passedFirstLaunch) {
			return Container(
				padding: EdgeInsets.all(16),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						SizedBox(height: 32),
						Icon(Icons.new_releases, size: 32),
						SizedBox(height: 8),
						Text(
							"Setup",
							textAlign: TextAlign.center,
							style: TextStyle(
								fontSize: 20
							)
						),
						SizedBox(height: 24),
						Text(
							"Location permissions are required to scan for nearby Bluetooth devices. Please accept the permissions dialog for this app to function.",
							style: TextStyle(
								fontSize: 16
							)
						),
						SizedBox(height: 24),
						Row(
							mainAxisSize: MainAxisSize.max,
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								ElevatedButton(
									child: Text("OK"),
									onPressed: () {
										setState(() {
											passedFirstLaunch = true;
											if (_bluetoothState == BluetoothState.on) {
												FlutterBlue.instance.startScan();
											}
										});
									}
								)
							]
						),
						SizedBox(height: 32)
					]
				)
			);
		}
		else if (_bluetoothState == BluetoothState.on || _mockBluetooth) {
			return Column(
				children: [
					if (_beforeConnect && savedBluetoothName != null) ...[
						SizedBox(height: 32),
						Icon(Icons.directions_bike, size: 32),
						SizedBox(height: 8),
						Text(
							"Looking for ${savedBluetoothName.length > 0 ? savedBluetoothName : "previous device"}",
							textAlign: TextAlign.center,
							style: TextStyle(
								fontSize: 20
							)
						),
						SizedBox(height: 24),
						Row(
							mainAxisSize: MainAxisSize.max,
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								ElevatedButton(
									child: Text("Choose a different device"),
									onPressed: () {
										setState(() {
											savedBluetoothName = null;
											savedBluetoothIdentifier = null;
										});
									}
								)
							]
						),
						SizedBox(height: 32)
					]
					else StreamBuilder(
						stream: _mockBluetooth ? MockFlutterBlue.instance.scanResults : FlutterBlue.instance.scanResults,
						builder: (BuildContext context, AsyncSnapshot<List<ScanResult>> snapshot) {
							if (snapshot.hasData) {
								List<Widget> rows = [];
								if (snapshot.data.length > 0) {
									snapshot.data.sort((a, b) => b.rssi - a.rssi);
									mergeSort(snapshot.data, compare: (a, b) {
										bool aName = ((a.device.name != null) && (a.device.name.length > 0));
										bool bName = ((b.device.name != null) && (b.device.name.length > 0));
										return aName ? (bName ? 0 : -1) : (bName ? 1 : 0);
									});
									rows.addAll(snapshot.data.map((result) {
										return BluetoothRow(
											device: result.device,
											rssi: result.rssi,
											onTap: (isConnected) async {
												await _tapBike(result.device, result.rssi);
											}
										);
									}));
								}
								else {
									rows.add(ListTile(
										title: Text(
											"No Bluetooth devices are currently visible",
											textAlign: TextAlign.center
										)
									));
								}
								return Expanded(
									child: ListView(
										shrinkWrap: true,
										children: rows
									)
								);
							}
							else {
								return Expanded(
									child: Center(
										child: CircularProgressIndicator()
									)
								);
							}
						}
					),
					LinearProgressIndicator()
				]
			);
		}
		else {
			return Container(
				padding: EdgeInsets.all(16),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Icon(Icons.error, size: 48),
						SizedBox(height: 16),
						Text(_getNoBluetoothMessage(), style: TextStyle(
							fontSize: 24
						)),
						if (!kReleaseMode) ...[
							SizedBox(height: 16),
							ElevatedButton(
								child: Text("Use Mock Bluetooth"),
								onPressed: () {
									setState(() {
										_mockBluetooth = true;
									});
								}
							)
						]
					]
				)
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text("Vanhawks Controller"),
				automaticallyImplyLeading: false
			),
			backgroundColor: Colors.grey.shade200,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					SizedBox(height: 32),
					Icon(
						Icons.bluetooth,
						size: 48,
						color: Colors.grey.shade800
					),
					SizedBox(height: 16),
					Text(
						"Connect to your bicycle",
						textAlign: TextAlign.center,
						style: TextStyle(
							fontSize: 24,
							color: Colors.grey.shade800
						)
					),
					SizedBox(height: 32),
					if (
						_initialized && ((_bluetoothState == BluetoothState.on && !(_beforeConnect && savedBluetoothName != null)) || _mockBluetooth) // results list
					) Expanded(
						child: Card(
							child: _cardContents(context),
						),
					)
					else if (_initialized) Card(
						child: _cardContents(context)
					),
					SizedBox(height: 16)
				]
			)
		);
	}
}