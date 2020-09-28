import 'package:flutter/material.dart';

import 'bike.dart';
import 'bluetooth_info_popup.dart';
import 'icons.dart';

class BikeBody extends StatelessWidget {
	IconData _getBatteryIcon(BuildContext context) {
		int mV = Bike.of(context).batteryMillivolts;
		int mA = Bike.of(context).batteryMilliamps;
		if (mA == null || mV == null) {
			return Icons.error;
		}
		else if (mA > 0) {
			return BatteryIcons.charging;
		}
		else {
			if (mV >= 4000) {
				return BatteryIcons.level4;
			}
			else if (mV>= 3272) {
				return BatteryIcons.level3;
			}
			else if (mV >= 3200) {
				return BatteryIcons.level2;
			}
			else {
				return BatteryIcons.level1;
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				Hero(
					tag: Bike.of(context).device.id,
					child: Material(
						child: ListTile(
							leading: Icon(Icons.directions_bike),
							title: Bike.of(context).device.name.length > 0 ? 
								Text(Bike.of(context).device.name) :
								Text(Bike.of(context).device.id.id, style: TextStyle(
									color: Colors.grey
								)),
							trailing: GestureDetector(
								child: Icon(Icons.info),
								onTap: () => showBluetoothInfo(context)
							)
						)
					)
				),
				if (Bike.of(context).connectionState == BikeConnectionState.Good) Expanded(
					child: Column(
						mainAxisAlignment: MainAxisAlignment.spaceAround,
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							BikeUIGroup(
								title: "Battery",
								child: Column(
									children: [
										Icon(_getBatteryIcon(context), size: 48),
										RaisedButton.icon(
											icon: Icon(Icons.refresh),
											label: Text("Update"),
											onPressed: Bike.of(context).requestBatteryUpdate
										)
									]
								)
							),
							BikeUIGroup(
								title: "Front Light",
								child: BikeLightButton(
									options: [
										BikeLightOption(
											bluetoothValue: FRONT_LIGHT_OFF,
											icon: SunIcons.sun_filled_off,
											text: "Off"
										),
										BikeLightOption(
											bluetoothValue: FRONT_LIGHT_ON_LOW,
											icon: SunIcons.sun_filled,
											text: "Low"
										),
										BikeLightOption(
											bluetoothValue: FRONT_LIGHT_ON_HIGH,
											icon: SunIcons.sun_filled_brighter,
											text: "High"
										)
									],
									currentSelection: Bike.of(context).frontLight,
									onTap: Bike.of(context).setFrontLight
								)
							),
							BikeUIGroup(
								title: "Rear Lights",
								child: BikeLightButton(
									options: [
										BikeLightOption(
											bluetoothValue: REAR_LIGHT_OFF,
											icon: SunIcons.sun_filled_off,
											text: "Off"
										),
										BikeLightOption(
											bluetoothValue: REAR_LIGHT_ON_SOLID,
											icon: SunIcons.sun_filled,
											text: "Solid"
										),
										BikeLightOption(
											bluetoothValue: REAR_LIGHT_ON_BLINKING,
											icon: SunIcons.sun,
											text: "Blinking"
										)
									],
									currentSelection: Bike.of(context).rearLight,
									onTap: Bike.of(context).setRearLight
								)
							)
						]
					)
				)
				else if (Bike.of(context).connectionState == BikeConnectionState.BadDevice) ...[
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
				else if (Bike.of(context).connectionState == BikeConnectionState.Connecting) ...[
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
								if (Bike.of(context).connectionErrorMessage != null) ...[
									Text("Error: ${Bike.of(context).connectionErrorMessage}"),
									SizedBox(height: 16)
								],
								RaisedButton(
									child: Text("Connect"),
									onPressed: Bike.of(context).connect
								)
							],
						)
					)
				]
			]
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
						child: selected ? RaisedButton(
							child: _buildChild(
								option: option,
								selected: selected
							),
							disabledColor: Colors.grey,
							disabledTextColor: Colors.white,
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
					),
					SizedBox(width: 32)
				];
			}).take((widget.options.length * 2) - 1).toList()
		);
	}
}