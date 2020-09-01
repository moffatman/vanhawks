import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class MyHomePage extends StatefulWidget {
	MyHomePage({Key key, this.title}) : super(key: key);

	final String title;

	@override
	_MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text(widget.title),
			),
			body: Consumer<LightsModel>(
				builder: (context, lights, child) => Center(
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceEvenly,
								children: [
									RaisedButton.icon(
										icon: Icon(Icons.flash_off),
										label: Text("OFF"),
										color: (lights.frontLightStatus == FRONT_LIGHT_OFF) ? chosenSettingColor : null,
										disabledColor: (lights.frontLightStatus == FRONT_LIGHT_OFF) ? chosenSettingColorDisabled : null,
										onPressed: lights.lightsOn ? () => lights.setFrontLight(FRONT_LIGHT_OFF) : null
									),
									RaisedButton.icon(
										icon: Icon(Icons.wb_sunny),
										label: Text("LOW"),
										color: (lights.frontLightStatus == FRONT_LIGHT_ON_LOW) ? chosenSettingColor : null,
										disabledColor: (lights.frontLightStatus == FRONT_LIGHT_ON_LOW) ? chosenSettingColorDisabled : null,
										onPressed: lights.lightsOn ? () => lights.setFrontLight(FRONT_LIGHT_ON_LOW) : null
									),
									RaisedButton.icon(
										icon: Icon(Icons.wb_sunny),
										label: Text("HIGH"),
										color: (lights.frontLightStatus == FRONT_LIGHT_ON_HIGH) ? chosenSettingColor : null,
										disabledColor: (lights.frontLightStatus == FRONT_LIGHT_ON_HIGH) ? chosenSettingColorDisabled : null,
										onPressed: lights.lightsOn ? () => lights.setFrontLight(FRONT_LIGHT_ON_HIGH) : null
									)
								]
							),
							Text("Front light"),
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceEvenly,
								children: [
									RaisedButton.icon(
										icon: Icon(Icons.flash_off),
										label: Text("OFF"),
										color: (lights.rearLightStatus == REAR_LIGHT_OFF) ? chosenSettingColor : null,
										disabledColor: (lights.rearLightStatus == REAR_LIGHT_OFF) ? chosenSettingColorDisabled : null,
										onPressed: lights.lightsOn ? () => lights.setRearLight(REAR_LIGHT_OFF) : null
									),
									RaisedButton.icon(
										icon: Icon(Icons.flash_on),
										label: Text("SOLID"),
										color: (lights.rearLightStatus == REAR_LIGHT_ON_SOLID) ? chosenSettingColor : null,
										disabledColor: (lights.rearLightStatus == REAR_LIGHT_ON_SOLID) ? chosenSettingColorDisabled : null,
										onPressed: lights.lightsOn ? () => lights.setRearLight(REAR_LIGHT_ON_SOLID) : null
									),
									RaisedButton.icon(
										icon: Icon(Icons.wb_sunny),
										label: Text("BLINKING"),
										color: (lights.rearLightStatus == REAR_LIGHT_ON_BLINKING) ? chosenSettingColor : null,
										disabledColor: (lights.rearLightStatus == REAR_LIGHT_ON_BLINKING) ? chosenSettingColorDisabled : null,
										onPressed: lights.lightsOn ? () => lights.setRearLight(REAR_LIGHT_ON_BLINKING) : null
									)
								]
							),
							Text("Rear light"),
							SizedBox(height: 32),
							Transform.scale(
								scale: 2.0,
								child: Switch(
									value: lights.lightsOn,
									onChanged: lights.setLightsOn
								)
							),
							SizedBox(height: 16),
							Text(
								lights.lightsOn ? "Lights are on" : "Lights are off",
								style: TextStyle(fontSize: 24)
							),
						],
					),
				)
			),
		);
	}
}
