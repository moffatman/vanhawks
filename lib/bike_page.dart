import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:page_transition/page_transition.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

import 'bluetooth_page.dart';
import 'bluetooth_row.dart';
import 'icons.dart';

const Duration _CONNECT_TIMEOUT = Duration(seconds: 5);
const Duration _BATTERY_CHECK_INTERVAL = Duration(seconds: 30);
// ignore: non_constant_identifier_names
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

Future<T> retry<T>({
	Future<T> Function() function,
	int numberOfRetries = 3,
	Duration delayBetweenRetries = const Duration(milliseconds: 500)
}) async {
	for (int i = 0; i < numberOfRetries; i++) {
		try {
			return await function();
		}
		catch (e) {
			print("Got error on attempt ${i + 1}/$numberOfRetries: ${e.toString()}");
		}
		await Future.delayed(delayBetweenRetries);
	}
	throw Exception("Retries exhausted");
}

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
	StreamSubscription<List<int>> _characteristicSubscription;
	Completer<void> _firstBatteryRead = Completer();
	Timer _batteryCheckTimer;
	int batteryMillivolts;
	int batteryMilliamps;
	BluetoothCharacteristic _characteristic;
	bool _expectedDisconnect = false;

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
			await widget.device.connect(autoConnect: true).timeout(_CONNECT_TIMEOUT);
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
	}

	Future<void> _checkBattery(timer) async {
		if (mounted) {
			if (await widget.device.state.first == BluetoothDeviceState.connected) {
				await _characteristic.write([0x14, 0x04]);
			}
		}
		else {
			timer.cancel();
		}
	}

	void _handleCharacteristicValue(List<int> value) {
		if (mounted) {
			ByteData bytes = Uint8List.fromList(value).buffer.asByteData();
			if ((bytes.lengthInBytes > 2) && (bytes.getUint8(1) == 4)) {
				print('$value');
				setState(() {
					batteryMillivolts = bytes.getUint16(2, Endian.little);
					batteryMilliamps = ((bytes.getUint8(6) != 1) ? 1 : -1) * bytes.getUint16(4, Endian.little);
				});
				if (!_firstBatteryRead.isCompleted) {
					_firstBatteryRead.complete();
				}
			}
			else {
				print("Got unknown value response: $value");
			}
		}
	}

	IconData _getBatteryIcon() {
		if (batteryMillivolts == null || batteryMilliamps == null) {
			return Icons.battery_unknown;
		}
		else if (batteryMilliamps > 0) {
			return BatteryIcons.charging;
		}
		else {
			if (batteryMillivolts >= 4000) {
				return BatteryIcons.level4;
			}
			else if (batteryMillivolts >= 3272) {
				return BatteryIcons.level3;
			}
			else if (batteryMillivolts >= 3200) {
				return BatteryIcons.level2;
			}
			else {
				return BatteryIcons.level1;
			}
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
						await _characteristic.setNotifyValue(true);
						if (_characteristicSubscription != null) {
							_characteristicSubscription.cancel();
							_firstBatteryRead = Completer();
							Timer(Duration(seconds: 5), () {
								if (!_firstBatteryRead.isCompleted) {
									print("Timing out on battery read");
									_firstBatteryRead.complete();
								}
							});
						}
						_characteristicSubscription = _characteristic.value.listen(_handleCharacteristicValue);
						if (_batteryCheckTimer != null) {
							_batteryCheckTimer.cancel();
						}
						_batteryCheckTimer = Timer.periodic(_BATTERY_CHECK_INTERVAL, _checkBattery);
						try {
							retry(
								function: () async => await _checkBattery(_batteryCheckTimer),
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
										_characteristic.write([_FRONT_LIGHT_ID, frontLight, frontLight]),
										_characteristic.write([_REAR_LIGHT_ID, rearLight, 0])
									]);
								},
								delayBetweenRetries: Duration(milliseconds: 100)
							);
						}
						catch (e) {
							print("Error setting initial values: ${e.toString()}");
						}
						setState(() {
							_expectedDisconnect = false;
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
					if (_expectedDisconnect) {
						setState(() {
							_connectionState = _ConnectionState.Disconnected;
						});
					}
					else {
						// reconnnect, it must be bike's fault
						_connect();
					}
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
			_characteristicSubscription.cancel();
			_initializeStateSubscription();
		}
	}

	@override
	void dispose() {
		super.dispose();
		_stateSubscription?.cancel();
		_characteristicSubscription?.cancel();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text("Vanhawks Controller"),
				automaticallyImplyLeading: false
			),
			body: Column(
				children: [
					BluetoothRow(
						device: widget.device,
						onTap: null,
						rssi: widget.rssi,
						info: [
							if (batteryMillivolts != null) "Battery Potential: $batteryMillivolts mV",
							if (batteryMilliamps != null) "Battery Current: $batteryMilliamps mA"
						],
						infoButton: true,
						beforeDisconnect: () {
							setState(() {
								_expectedDisconnect = true;
							});
						},
						onForget: () {
							setState(() {
								_expectedDisconnect = true;
							});
							widget.device.disconnect();
							Navigator.of(context).pushReplacement(
									PageTransition(
										type: PageTransitionType.fade,
										child: BluetoothPage(
											forgetPreviousDevice: true
										)
									)
								);
							}
					),
					if (_connectionState == _ConnectionState.Good) Expanded(
						child: Column(
							mainAxisAlignment: MainAxisAlignment.spaceAround,
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								BikeUIGroup(
									title: "Battery",
									child: Icon(_getBatteryIcon(), size: 48)
								),
								BikeUIGroup(
									title: "Front Light",
									child: BikeLightButton(
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
									)
								),
								BikeUIGroup(
									title: "Rear Lights",
									child: BikeLightButton(
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
											await _characteristic.write([_REAR_LIGHT_ID, choice, 0]);
										}
									)
								)
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
									Text("This device is not a Vanhawks Valour bicycle"),
									SizedBox(height: 16),
									ElevatedButton(
										child: Text("Report Error"),
										onPressed: () async {
											List<BluetoothService> services = await widget.device.discoverServices();
											String bluetoothText = services.map((service) {
												return '- Service with ID ${service.uuid}\n' + ((service.characteristics != null) ? service.characteristics.map((characteristic) {
													return '-- Characteristic with ID ${characteristic.uuid}\n' + ((characteristic.descriptors != null) ? characteristic.descriptors.map((descriptor) {
														return '--- Descriptor with ID ${descriptor.uuid}\n';
													}).join('') : '');
												}).join('') : '');
											}).join('');
											print(bluetoothText);
											FlutterEmailSender.send(Email(
												body: '''
													Hi Callum,
													Your app, Vanhawks Bike Light Controller, did not recognize my bike
													Here is the Bluetooth data that will help you figure this out:
													$bluetoothText
													Thanks!
												''',
												subject: 'Vanhawks app did not recognize my bike',
												recipients: ['callum@moffatman.com'],
												isHTML: false
											));
										}
									)
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
									ElevatedButton(
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

class BikeUIGroup extends StatelessWidget {
	final Widget child;
	final String title;

	BikeUIGroup({
		@required this.child,
		@required this.title
	});

	@override
	Widget build(BuildContext context) {
		return Card(
			child: Container(
				padding: EdgeInsets.all(8),
				child: Column(
					children: [
						Text(title, style: TextStyle(
							fontSize: 20
						)),
						SizedBox(height: 8),
						child
					]
				)
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
			padding: EdgeInsets.only(top: 8, bottom: 8),
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
						fontSize: 14
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
			mainAxisSize: MainAxisSize.min,
			children: widget.options.expand((option) {
				bool selected = (widget.currentSelection == option.bluetoothValue);
				return [
					Container(
						child: selected ? ElevatedButton(
							child: _buildChild(
								option: option,
								selected: selected
							),
							style: ButtonStyle(
								backgroundColor: MaterialStateProperty.resolveWith<Color>(
									(Set <MaterialState> states) {
										if (states.contains(MaterialState.disabled)) {
											return Theme.of(context).disabledColor;
										}
										return null;
									}
								),
								foregroundColor: MaterialStateProperty.resolveWith<Color>(
									(Set <MaterialState> states) {
										if (states.contains(MaterialState.disabled)) {
											return Theme.of(context).colorScheme.onSurface;
										}
										return null;
									}
								)
							),
							onPressed: _buildOnPressed(
								option: option,
								selected: selected
							)
						) : OutlinedButton(
							child: _buildChild(
								option: option,
								selected: selected
							),
							style: ButtonStyle(
								foregroundColor: MaterialStateProperty.resolveWith<Color>(
									(Set <MaterialState> states) {
										if (states.contains(MaterialState.disabled)) {
											return Theme.of(context).disabledColor;
										}
										return Theme.of(context).colorScheme.onSurface;
									}
								)
							),
							onPressed: _buildOnPressed(
								option: option,
								selected: selected
							)
						)
					),
					SizedBox(width: 32)
				];
			}).take((widget.options.length * 2) - 1).toList()
		);
	}
}