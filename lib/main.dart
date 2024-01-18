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
			brightness: Brightness.light,
			primarySwatch: Colors.grey,
			visualDensity: VisualDensity.adaptivePlatformDensity,
			useMaterial3: false
		),
		darkTheme: ThemeData(
			brightness: Brightness.dark,
			primarySwatch: Colors.grey,
			visualDensity: VisualDensity.adaptivePlatformDensity,
			useMaterial3: false
		),
		themeMode: ThemeMode.system,
		home: BluetoothPage()
	);
  }
}
