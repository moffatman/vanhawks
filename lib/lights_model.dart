import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:vanhawks/main.dart';

const String _FRONT_LIGHT_STATUS_KEY = "front_light_status";
const String _REAR_LIGHT_STATUS_KEY = "rear_light_status";
const String _LIGHTS_ON_KEY = "lights_on";

class LightsModel extends ChangeNotifier {
	bool initialized = false;
	int frontLightStatus;
	int rearLightStatus;
	bool lightsOn;
	SharedPreferences _prefs;

	void setLightsOn(bool value) {
		lightsOn = value;
		_prefs.setBool(_LIGHTS_ON_KEY, value);
		notifyListeners();
	}

	void setFrontLight(int status) {
		frontLightStatus = status;
		print("Set front light status to " + status.toString());
		_prefs.setInt(_FRONT_LIGHT_STATUS_KEY, status);
		notifyListeners();
	}

	void setRearLight(int status) {
		rearLightStatus = status;
		print("Set rear light status to " + status.toString());
		_prefs.setInt(_REAR_LIGHT_STATUS_KEY, status);
		notifyListeners();
	}

	void _initialize() async {
		_prefs = await SharedPreferences.getInstance();
		setFrontLight(_prefs.getInt(_FRONT_LIGHT_STATUS_KEY) ?? FRONT_LIGHT_OFF);
		setRearLight(_prefs.getInt(_REAR_LIGHT_STATUS_KEY) ?? REAR_LIGHT_OFF);
		setLightsOn(_prefs.getBool(_LIGHTS_ON_KEY) ?? false);
		initialized = true;
		notifyListeners();
	}

	LightsModel() {
		_initialize();
	}
}