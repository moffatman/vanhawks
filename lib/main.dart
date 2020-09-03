import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:provider/provider.dart';

import 'bluetooth_picker.dart';
import 'lights_model.dart';

void main() {
	runApp(
		ChangeNotifierProvider(
			create: (context) => LightsModel(),
			child: MyApp()
		)
	);
}

class MyApp extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
	return MaterialApp(
		title: 'Flutter Demo',
		theme: ThemeData(
			primarySwatch: Colors.grey,
			visualDensity: VisualDensity.adaptivePlatformDensity,
		),
		home: MyHomePage(title: 'Vanhawks Controller'),
	);
  }
}

const int FRONT_LIGHT_ID = 3;
const int FRONT_LIGHT_OFF = 0;
const int FRONT_LIGHT_ON_LOW = 1;
const int FRONT_LIGHT_ON_HIGH = 2;
const int REAR_LIGHT_ID = 2;
const int REAR_LIGHT_OFF = 0;
const int REAR_LIGHT_ON_SOLID = 1;
const int REAR_LIGHT_ON_BLINKING = 2;

Color chosenSettingColor = Colors.green;
Color chosenSettingColorDisabled = Colors.grey.shade800;

class LifecycleListener extends StatefulWidget {
	final LightsModel model;
	final Widget child;
	LifecycleListener({this.model, this.child});

	@override
	_LifecycleListenerState createState() => _LifecycleListenerState();
}

class _LifecycleListenerState extends State<LifecycleListener> with WidgetsBindingObserver {
	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addObserver(this);
	}

	@override
	void didChangeAppLifecycleState(AppLifecycleState state) {
		if (state == AppLifecycleState.paused) {
			widget.model.handleAppPause();
		}
		else if (state == AppLifecycleState.resumed) {
			widget.model.handleAppResume();
		}
	}

	@override
	Widget build(BuildContext context) {
		return widget.child;		
	}
}

class MyHomePage extends StatefulWidget {
	MyHomePage({Key key, this.title}) : super(key: key);

	final String title;

	@override
	_MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
	void _showBluetoothDevicePopup(LightsModel lights) {
		showDialog(
			context: context,
			barrierDismissible: true,
			builder: (BuildContext context) {
				return AlertDialog(
					title: Text(lights.device.name),
					content: SingleChildScrollView(
						child: ListBody(
							children: [
								Text("Currently connected")
							]
						)
					),
					actions: [
						FlatButton(
							child: Text("Disconnect"),
							onPressed: () {
								lights.disconnectBluetoothDevice();
								Navigator.of(context).pop();
							}
						)
					]
				);
			}
		);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text(widget.title),
			),
			body: Consumer<LightsModel>(
				builder: (context, lights, child) {
					return LifecycleListener(
						model: lights,
						child: lights.initialized ? Center(
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									(lights.device == null) ? RaisedButton.icon(
										icon: Icon(Icons.bluetooth_searching),
										label: Text(lights.statusText),
										onPressed: () async {
											BluetoothDevice device = await pickBluetoothDevice(context);
											if (device != null) {
												try {
													await lights.setBluetoothDevice(device);
												}
												on TimeoutException {
													Scaffold.of(context).showSnackBar(SnackBar(content: Text("Timed out connecting to device")));
												}
												on BadDeviceException {
													Scaffold.of(context).showSnackBar(SnackBar(content: Text("Device was not a Vanhawks Valour")));
												}
											}
										}
									) : RaisedButton.icon(
										icon: Icon(Icons.bluetooth_connected),
										label: Text(lights.statusText),
										onPressed: () {
											if (lights.status == BluetoothStatus.Connected) {
												_showBluetoothDevicePopup(lights);
											}
										}
									),
									SizedBox(height: 32),
									UILocker(
										status: lights.uiStatus,
										child: Column(
											children: [
												Row(
													mainAxisAlignment: MainAxisAlignment.spaceEvenly,
													children: [
														LightButton(
															icon: Icon(Icons.flash_off),
															label: Text("OFF"),
															selected: lights.frontLight == FRONT_LIGHT_OFF,
															enabled: lights.lightsOn,
															onPressed: () => lights.frontLight = FRONT_LIGHT_OFF
														),
														LightButton(
															icon: Icon(Icons.wb_sunny),
															label: Text("LOW"),
															selected: lights.frontLight == FRONT_LIGHT_ON_LOW,
															enabled: lights.lightsOn,
															onPressed: () => lights.frontLight = FRONT_LIGHT_ON_LOW
														),
														LightButton(
															icon: Icon(Icons.wb_sunny),
															label: Text("HIGH"),
															selected: lights.frontLight == FRONT_LIGHT_ON_HIGH,
															enabled: lights.lightsOn,
															onPressed: () => lights.frontLight = FRONT_LIGHT_ON_HIGH
														)
													]
												),
												Text("Front light"),
												Row(
													mainAxisAlignment: MainAxisAlignment.spaceEvenly,
													children: [
														LightButton(
															icon: Icon(Icons.flash_off),
															label: Text("OFF"),
															selected: lights.rearLight == REAR_LIGHT_OFF,
															enabled: lights.lightsOn,
															onPressed: () => lights.rearLight = REAR_LIGHT_OFF
														),
														LightButton(
															icon: Icon(Icons.flash_on),
															label: Text("SOLID"),
															selected: lights.rearLight == REAR_LIGHT_ON_SOLID,
															enabled: lights.lightsOn,
															onPressed: () => lights.rearLight = REAR_LIGHT_ON_SOLID
														),
														LightButton(
															icon: Icon(Icons.wb_sunny),
															label: Text("BLINKING"),
															selected: lights.rearLight == REAR_LIGHT_ON_BLINKING,
															enabled: lights.lightsOn,
															onPressed: () => lights.rearLight = REAR_LIGHT_ON_BLINKING
														)
													]
												),
												Text("Rear light"),
												SizedBox(height: 32),
												Row(
													mainAxisAlignment: MainAxisAlignment.center,
													children: [
														Icon(Icons.power_settings_new),
														Switch(
															value: lights.lightsOn,
															onChanged: (val) => lights.lightsOn = val
														)
													]
												)
											]
										)
									)
								]
							),
						) : Center(
							child: CircularProgressIndicator()
						)
					);
				}
			),
		);
	}
}

class LightButton extends StatelessWidget {
	final Widget icon;
	final Widget label;
	final bool selected;
	final bool enabled;
	final void Function() onPressed;

	LightButton({
		@required this.icon,
		@required this.label,
		@required this.selected,
		@required this.enabled,
		@required this.onPressed
	});

	@override
	Widget build(BuildContext context) {
		return Expanded(
			child: RaisedButton.icon(
				icon: icon,
				label: label,
				color: selected ? chosenSettingColor : null,
				disabledColor: selected ? chosenSettingColorDisabled : null,
				onPressed: enabled ? onPressed : null
			)
		);
	}
}

class UILocker extends StatelessWidget {
	final UILockoutStatus status;
	final Widget child;

	UILocker({
		@required this.status,
		@required this.child
	});

	@override
	Widget build(BuildContext context) {
		return Stack(
			children: [
				child,
				if (status != UILockoutStatus.Enabled)
					Positioned.fill(
						child: DecoratedBox(
							decoration: BoxDecoration(
								color: Colors.black.withAlpha(100)
							),
							child: Center(
								child: status == UILockoutStatus.Loading ? CircularProgressIndicator(
									valueColor: AlwaysStoppedAnimation(Colors.black),
								) : null
							)
						)
					)
			]
		);
	}
}