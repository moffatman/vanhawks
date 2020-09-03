import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:provider/provider.dart';

import 'lights_model.dart';

class BadDeviceException implements Exception {
	String _message;

	BadDeviceException([String message = "Device does not meet specifications"]) {
		this._message = message;
	}

	@override
	String toString() {
		return _message;
	}
}

class BluetoothPickerDialog extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return StreamBuilder(
			stream: FlutterBlue.instance.scanResults,
			initialData: null,
			builder: (BuildContext context, AsyncSnapshot<List<ScanResult>> snapshot) {
				List<ScanResult> results = snapshot.data;
				return SimpleDialog(
					title: const Text("Select device"),
					children: (results == null) ? [Center(
						child: CircularProgressIndicator()
					)] : results.where((result) => result.device.name.length > 0).map((result) {
						return SimpleDialogOption(
							child: Text("${result.device.name} [${result.device.id}]"),
							onPressed: () {
								Navigator.pop(context, result.device);
							}
						);
					}).toList()
				);
			}
		);
	}
}

Future<BluetoothDevice> pickBluetoothDevice(BuildContext context) async {
	return await showDialog<BluetoothDevice>(
		context: context,
		builder: (BuildContext context) {
			return BluetoothPickerDialog();
		}
	);
}