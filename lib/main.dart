import 'package:flutter/material.dart';

import 'bluetooth_page.dart';

void main() {
	runApp(
		MyApp()
	);
}

class MyApp extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
	return MaterialApp(
		title: 'Vanhawks Controller',
		theme: ThemeData(
			primarySwatch: Colors.grey,
			visualDensity: VisualDensity.adaptivePlatformDensity,
		),
		home: BluetoothPage()
	);
  }
}

Color chosenSettingColor = Colors.green;
Color chosenSettingColorDisabled = Colors.grey.shade800;