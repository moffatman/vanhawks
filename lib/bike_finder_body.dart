import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vanhawks_page.dart';
import 'bike_finder.dart';
import 'bluetooth_row.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class BikeFinderBody extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return Column(
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
						child: (BikeFinder.of(context).bluetoothState == BluetoothState.on) ? ListView(
							shrinkWrap: true,
							children: [
								if (BikeFinder.of(context).neverConnected && BikeFinder.of(context).savedBluetoothName != null) ...[
									SizedBox(height: 32),
									Icon(Icons.directions_bike, size: 32),
									SizedBox(height: 8),
									Text(
										"Looking for ${BikeFinder.of(context).savedBluetoothName.length > 0 ? BikeFinder.of(context).savedBluetoothName : "previous device"}",
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
												onPressed: BikeFinder.of(context).forget
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
																onTap: (isConnected) async => BikeFinder.of(context).selectBike(result.device)
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
		);
	}
}