import 'dart:async';

import 'package:flutter/material.dart';

import 'bike.dart';
import 'bike_finder.dart';

class BluetoothInfoPopup extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: Text("Device Info"),
			content: ListView(
				children: [
					ListTile(
						title: Text("Address: ${Bike.of(context).device.id}")
					),
					ListTile(
						title: Text("Connection state: ${Bike.of(context).connectionState.toString()}")
					),
					if (Bike.of(context).connectionState == BikeConnectionState.Good) ...[
						ListTile(
							title: Text("Battery potential: ${Bike.of(context).batteryMillivolts} mV")
						),
						ListTile(
							title: Text("Battery current: ${Bike.of(context).batteryMilliamps} mA")
						)
					]
				]
			),
			actions: [
				if (Bike.of(context).isConnected) ...[
					TextButton(
						child: Text("Disconnect", textAlign: TextAlign.end),
						onPressed: BikeFinder.of(context).disconnect
					)
				],
				TextButton(
					child: Text("Forget", textAlign: TextAlign.end),
					onPressed: BikeFinder.of(context).forget
				)
			],
		);
	}
}

Future<void> showBluetoothInfo(BuildContext context) async {
	await showDialog(
		context: context,
		builder: (BuildContext context) {
			return BluetoothInfoPopup();
		}
	);
}