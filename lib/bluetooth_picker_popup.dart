import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class BluetoothPickerPopup extends StatefulWidget {
	@override
	createState() => _BluetoothPickerPopupState();
}

class _BluetoothPickerPopupState extends State<BluetoothPickerPopup> {
	StreamSubscription<List<ScanResult>> _scanSubscription;
	bool _startedScanningHere;
	List<_BluetoothChoice> _scanChoices;

	Timer _checkConnectedDevicesTimer;
	List<_BluetoothChoice> _connectedChoices;

	List<_BluetoothChoice> choices;
	bool showHiddenDevices;
	
	void _initiateScanning() async {
		if (!await FlutterBlue.instance.isScanning.first) {
			FlutterBlue.instance.startScan(
				withServices: [
					Guid("9ac78e8d1e9943ce83637c1b1e003a10")
				]
			);
			_startedScanningHere = true;
		}
		_scanSubscription = FlutterBlue.instance.scanResults.listen((results) {
			_scanChoices = results.map((result) => _BluetoothChoice.fromScan(result));
			_regenerateChoiceList();
		});
	}

	void _checkConnectedDevices() async {
		List<BluetoothDevice> devices = await FlutterBlue.instance.connectedDevices;
		_connectedChoices = devices.map((device) => _BluetoothChoice.fromDevice(device));
		_regenerateChoiceList();
		_checkConnectedDevicesTimer = Timer(const Duration(seconds: 2), _checkConnectedDevices);
	}

	void _regenerateChoiceList() {
		List<_BluetoothChoice> newChoices = [..._connectedChoices, ..._scanChoices];
		newChoices.sort((a, b) {
			if (a.rssi != null) {
				if (b.rssi != null) {
					return b.rssi - a.rssi;
				}
				return -1;
			}
			else if (b.rssi != null) {
				return 1;
			}
			else {
				return b.device.name.compareTo(a.device.name);
			}
		});
		setState(() {
			choices = newChoices;
		});
	}

	@override
	void initState() {
		super.initState();
		_initiateScanning();
		_checkConnectedDevices();
	}

	@override
	void dispose() {
		super.dispose();
		if (_checkConnectedDevicesTimer != null) {
			_checkConnectedDevicesTimer.cancel();
		}
		if (_scanSubscription != null) {
			_scanSubscription.cancel();
		}
		if (_startedScanningHere) {
			FlutterBlue.instance.stopScan();
		}
	}

	@override
	Widget build(BuildContext context) {
		return SimpleDialog(
			title: Text("Select device"),
			children: [
				...choices.where((choice) => (showHiddenDevices || choice.device.name.length > 0)).map((choice) {
					return SimpleDialogOption(
						child: choice.device.name.length > 0 ? Text(
							choice.device.name
						) : Text(
							choice.device.id.toString(),
							style: TextStyle(
								color: Colors.grey
							)
						),
						onPressed: () {
							Navigator.of(context).pop(choice.device);
						}
					);
				}).toList(),
				LinearProgressIndicator()
			]
		);
	}
}

class _BluetoothChoice {
	BluetoothDevice device;
	int rssi;

	_BluetoothChoice.fromDevice(BluetoothDevice device): device = device, rssi = null;
	_BluetoothChoice.fromScan(ScanResult result): device = result.device, rssi = result.rssi;
}