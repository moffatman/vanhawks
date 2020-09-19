import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bluetooth_row.dart';
import 'icons.dart';

const Duration _CONNECT_TIMEOUT = Duration(seconds: 5);
Guid _VANHAWKS_LIGHTS_CHARACTERISTICS_UUID = Guid("9ac78e8d1e9943ce83637c1b1e003a11");
const String _FRONT_LIGHT_STATUS_KEY = "front_light_status";
const String _REAR_LIGHT_STATUS_KEY = "rear_light_status";
const int _FRONT_LIGHT_ID = 3;
const int _FRONT_LIGHT_OFF = 0;
const int _FRONT_LIGHT_ON_LOW = 1;
const int _FRONT_LIGHT_ON_HIGH = 2;
const int _REAR_LIGHT_ID = 2;
const int _REAR_LIGHT_OFF = 0;
const int _REAR_LIGHT_ON_SOLID = 1;
const int _REAR_LIGHT_ON_BLINKING = 2;

enum _ConnectionState {
	Connecting,
	Disconnected,
	BadDevice,
	Good
}

class BikePage extends StatefulWidget {
	final BluetoothDevice device;
	final int rssi;

	BikePage({
		@required this.device,
		@required this.rssi
	});

	@override
	_BikePageState createState() => _BikePageState();
}

class _BikePageState extends State<BikePage> {
	int _frontLight;
	int get frontLight {
		return _frontLight;
	}
	set frontLight(int value) {
		setState(() {
			_frontLight = value;
		});
		_prefs.setInt(_FRONT_LIGHT_STATUS_KEY, value);
	}
	int _rearLight;
	int get rearLight {
		return _rearLight;
	}
	set rearLight(int value) {
		setState(() {
			_rearLight = value;
		});
		_prefs.setInt(_REAR_LIGHT_STATUS_KEY, value);
	}
	SharedPreferences _prefs;
	
	_ConnectionState _connectionState = _ConnectionState.Connecting;
	String _connectionErrorMessage;
	StreamSubscription<BluetoothDeviceState> _stateSubscription;
	BluetoothCharacteristic _characteristic;

	void _initializePrefs() async {
		_prefs = await SharedPreferences.getInstance();
		setState(() {
			_frontLight = _prefs.getInt(_FRONT_LIGHT_STATUS_KEY) ?? _FRONT_LIGHT_OFF;
			_rearLight = _prefs.getInt(_REAR_LIGHT_STATUS_KEY) ?? _REAR_LIGHT_OFF;
		});
	}

	void _connect() async {
		try {
			setState(() {
				_connectionState = _ConnectionState.Connecting;
			});
			await widget.device.connect().timeout(_CONNECT_TIMEOUT);
		}
		catch (e) {
			if (mounted) {
				setState(() {
					_connectionState = _ConnectionState.Disconnected;
					if (e.runtimeType == TimeoutException) {
						_connectionErrorMessage = "Timed out";
					}
					else {
						_connectionErrorMessage = e.toString();
					}
				});
			}
		}
	}

	void _connectIfNeeded() async {
		if (await widget.device.state.first != BluetoothDeviceState.connected) {
			_connect();
		}
		else {
		}
	}

	void _initializeStateSubscription() {
		_stateSubscription = widget.device.state.listen((newState) async {
			if (mounted) {
				if (newState == BluetoothDeviceState.connected) {
					List<BluetoothService> services = await widget.device.discoverServices();
					for (BluetoothService service in services) {
						for (BluetoothCharacteristic characteristic in service.characteristics) {
							if (characteristic.uuid == _VANHAWKS_LIGHTS_CHARACTERISTICS_UUID) {
								_characteristic = characteristic;
							}
						}
					}
					if (this._characteristic != null) {
						_characteristic.write([_FRONT_LIGHT_ID, frontLight, frontLight]);
						_characteristic.write([_REAR_LIGHT_ID, rearLight, rearLight]);
						setState(() {
							_connectionState =  _ConnectionState.Good;
						});
					}
					else {
						setState(() {
 							_connectionState = _ConnectionState.BadDevice;
						});
					}
				}
				else if (newState == BluetoothDeviceState.connecting) {
					setState(() {
						_connectionState = _ConnectionState.Connecting;
					});
				}
				else {
					setState(() {
						_connectionState = _ConnectionState.Disconnected;
					});
				}
			}
		});
	}

	@override
	void initState() {
		super.initState();
		_initializePrefs();
		_initializeStateSubscription();
		_connectIfNeeded();
	}

	@override
	void didUpdateWidget(oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.device != widget.device) {
			print("new device");
			_stateSubscription.cancel();
			_initializeStateSubscription();
		}
	}

	@override
	void dispose() {
		super.dispose();
		_stateSubscription.cancel();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text("Vanhawks Controller")
			),
			body: Column(
				children: [
					BluetoothRow(
						device: widget.device,
						onTap: null,
						rssi: widget.rssi
					),
					if (_connectionState == _ConnectionState.Good) Expanded(
						child: Column(
							mainAxisAlignment: MainAxisAlignment.spaceAround,
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								Text("Front Light", style: TextStyle(
									fontSize: 28
								)),
								BikeLightButton(
									options: [
										BikeLightOption(
											bluetoothValue: _FRONT_LIGHT_OFF,
											icon: SunIcons.sun_filled_off,
											text: "Off"
										),
										BikeLightOption(
											bluetoothValue: _FRONT_LIGHT_ON_LOW,
											icon: SunIcons.sun_filled,
											text: "Low"
										),
										BikeLightOption(
											bluetoothValue: _FRONT_LIGHT_ON_HIGH,
											icon: SunIcons.sun_filled_brighter,
											text: "High"
										)
									],
									currentSelection: frontLight,
									onTap: (choice) async {
										setState(() {
											frontLight = choice;
										});
										await _characteristic.write([_FRONT_LIGHT_ID, choice, choice]);
									}
								),
								Container(),
								Text("Rear Lights", style: TextStyle(
									fontSize: 28
								)),
								BikeLightButton(
									options: [
										BikeLightOption(
											bluetoothValue: _REAR_LIGHT_OFF,
											icon: SunIcons.sun_filled_off,
											text: "Off"
										),
										BikeLightOption(
											bluetoothValue: _REAR_LIGHT_ON_SOLID,
											icon: SunIcons.sun_filled,
											text: "Solid"
										),
										BikeLightOption(
											bluetoothValue: _REAR_LIGHT_ON_BLINKING,
											icon: SunIcons.sun,
											text: "Blinking"
										)
									],
									currentSelection: rearLight,
									onTap: (choice) async {
										setState(() {
											rearLight = choice;
										});
										await _characteristic.write([_REAR_LIGHT_ID, choice, choice]);
									}
								),
								Container()
							]
						)
					)
					else if (_connectionState == _ConnectionState.BadDevice) ...[
						Expanded(
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Icon(Icons.error, size: 48),
									SizedBox(height: 16),
									Text("This device is not a Vanhawks Valour bicycle")
								]
							)
						)
					]
					else if (_connectionState == _ConnectionState.Connecting) ...[
						Expanded(
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									CircularProgressIndicator(),
									SizedBox(height: 16),
									Text("Connecting...")
								]
							)
						)
					]
					else ...[
						Expanded(
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Icon(Icons.error, size: 48),
									SizedBox(height: 16),
									Text("Not connected"),
									SizedBox(height: 16),
									if (_connectionErrorMessage != null) ...[
										Text("Error: $_connectionErrorMessage"),
										SizedBox(height: 16)
									],
									RaisedButton(
										child: Text("Connect"),
										onPressed: _connect
									)
								],
							)
						)
					]
				]
			)
		);
	}
}

class BikeLightOption {
	final int bluetoothValue;
	final IconData icon;
	final String text;

	const BikeLightOption({
		@required this.bluetoothValue,
		@required this.icon,
		@required this.text
	});
}

class BikeLightButton extends StatefulWidget {
	final Function(int) onTap;
	final List<BikeLightOption> options;
	final int currentSelection;

	BikeLightButton({
		@required this.onTap,
		@required this.options,
		@required this.currentSelection
	});

	@override
	_BikeLightButtonState createState() => _BikeLightButtonState();
}

class _BikeLightButtonState extends State<BikeLightButton> {
	bool _loading = false;

	Widget _buildChild({BikeLightOption option, bool selected}) {
		return Container(
			padding: EdgeInsets.all(8),
			child: Column(
				mainAxisAlignment: MainAxisAlignment.center,
				children: [
					Container(
						width: 50,
						height: 50,
						child: Icon(option.icon, size: 48)
					),
					SizedBox(height: 8),
					Text(option.text, style: TextStyle(
						fontSize: 20
					))
				]
			)
		);
	}

	Function() _buildOnPressed({BikeLightOption option, bool selected}) {
		return (_loading || selected) ? null : () async {
			setState(() {
				_loading = true;
			});
			try {
				await widget.onTap(option.bluetoothValue);
			}
			finally {
				setState(() {
					_loading = false;
				});
			}
		};
	}

	@override
	Widget build(BuildContext context) {
		return Row(
			mainAxisAlignment: MainAxisAlignment.spaceEvenly,
			children: widget.options.expand((option) {
				bool selected = (widget.currentSelection == option.bluetoothValue);
				return [
					SizedBox(width: 32),
					Expanded(
						child: selected ? RaisedButton(
							child: _buildChild(
								option: option,
								selected: selected
							),
							//disabledColor: selected ? Colors.red.shade400 : null,
							disabledTextColor: Colors.black,
							onPressed: _buildOnPressed(
								option: option,
								selected: selected
							)
						) : OutlineButton(
							child: _buildChild(
								option: option,
								selected: selected
							),
							//disabledColor: selected ? Colors.red.shade400 : null,
							disabledTextColor: Colors.black,
							onPressed: _buildOnPressed(
								option: option,
								selected: selected
							)
						)
					)
				];
			}).followedBy([
				SizedBox(width: 32)
			]).toList()
		);
	}
}