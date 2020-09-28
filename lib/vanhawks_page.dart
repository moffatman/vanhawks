import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bike.dart';
import 'bike_body.dart';
import 'bike_finder.dart';
import 'bike_finder_body.dart';

class VanhawksPage extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text("Vanhawks Controller")
			),
			body: Builder(
				builder: (BuildContext context) {
					if (BikeFinder.of(context).initialized) {
						if (Bike.of(context) != null) {
							return BikeBody();
						}
						else {
							return BikeFinderBody();
						}
					}
					else {
						return Center(
							child: CircularProgressIndicator()
						);
					}
				}
			)
		);
	}
}