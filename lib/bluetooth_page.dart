import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bike_page.dart';
import 'bluetooth_row.dart';

const String _BLUETOOTH_ID_KEY = "bluetooth_id";
const String _BLUETOOTH_NAME_KEY = "bluetooth_name";

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class BluetoothPage extends StatefulWidget {
	_BluetoothPageState createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> with RouteAware {
	SharedPreferences _prefs;
	bool _beforeConnect = true;
	BluetoothState _bluetoothState;

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

	void _initialize() async {
		_prefs = await SharedPreferences.getInstance();
		savedBluetoothName = _prefs.getString(_BLUETOOTH_NAME_KEY);
		String _previousBluetoothIdentifierString = _prefs.getString(_BLUETOOTH_ID_KEY);
		if (_previousBluetoothIdentifierString != null) {
			savedBluetoothIdentifier = DeviceIdentifier(_previousBluetoothIdentifierString);
		}
		_bluetoothState = await FlutterBlue.instance.state.first;
	}

	@override
	void initState() {
		super.initState();
		_initialize();
		FlutterBlue.instance.startScan();
		FlutterBlue.instance.scanResults.listen((scanResults) async {
			if (savedBluetoothIdentifier != null) {
				ScanResult result = scanResults.firstWhere((result) => result.device.id == savedBluetoothIdentifier);
				if (result != null && _beforeConnect) {
					_tapBike(result.device, result.rssi);
				}
			}
		});
		FlutterBlue.instance.state.listen((newState) {
			if (mounted) {
				setState(() {
					_bluetoothState = newState;
				});
			}
		});
		FlutterBlue.instance.connectedDevices.then((devices) {
			if (savedBluetoothIdentifier != null) {
				BluetoothDevice targetDevice = devices.firstWhere((device) => device.id == savedBluetoothIdentifier);
				if (targetDevice != null && _beforeConnect) {
					_tapBike(targetDevice, null);
				}
			}
		});
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		routeObserver.subscribe(this, ModalRoute.of(context));
	}

	@override
	void dispose() {
		routeObserver.unsubscribe(this);
		super.dispose();
	}

	@override
	void didPushNext() {
		FlutterBlue.instance.stopScan();
	}

	@override
	void didPopNext() {
		FlutterBlue.instance.startScan();
	}

	Future<void> _tapBike(BluetoothDevice device, int rssi) async {
		setState(() {
			savedBluetoothIdentifier = device.id;
			savedBluetoothName = device.name;
			_beforeConnect = false;
		});
		await Navigator.of(context).push(
			MaterialPageRoute(
				builder: (context) => BikePage(
					device: device,
					rssi: rssi
				)
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text("Vanhawks Controller")
			),
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
					Expanded(
						child: Card(
							child: (_bluetoothState == BluetoothState.on) ? ListView(
								shrinkWrap: true,
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
												RaisedButton(
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
									else ...[
										StreamBuilder(
											stream: FlutterBlue.instance.scanResults,
											builder: (BuildContext context, AsyncSnapshot<List<ScanResult>> snapshot) {
												if (snapshot.hasData) {
													if (snapshot.data.length > 0) {
														snapshot.data.sort((a, b) => b.rssi - a.rssi);
														snapshot.data.sort((a, b) {
															bool aName = ((a.device.name != null) && (a.device.name.length > 0));
															bool bName = ((b.device.name != null) && (b.device.name.length > 0));
															return aName ? (bName ? 0 : -1) : (bName ? 1 : 0);
														});
														return Column(
															children: snapshot.data.map((result) {
																return BluetoothRow(
																	device: result.device,
																	rssi: result.rssi,
																	onTap: (isConnected) async {
																		await _tapBike(result.device, result.rssi);
																	}
																);
															}).toList()
														);
													}
													else {
														return ListTile(
															title: Text(
																"No Bluetooth devices are currently visible",
																textAlign: TextAlign.center
															)
														);
													}
												}
												else {
													return Center(
														child: CircularProgressIndicator()
													);
												}
											}
										)
									],
									LinearProgressIndicator()
								]
							) : Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Icon(Icons.error, size: 48),
									SizedBox(height: 16),
									Text("Bluetooth is not on", style: TextStyle(
										fontSize: 24
									))
								]
							)
						)
					),
					SizedBox(height: 16)
				]
			)
		);
	}
}