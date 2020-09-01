import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue/flutter_blue.dart';

class LightsModel extends ChangeNotifier {
	int frontLightStatus = 0;
	int rearLightStatus = 0;
	bool lightsOn = false;

	void setLightsOn(bool value) {
		lightsOn = value;
		notifyListeners();
	}

	void setFrontLight(int status) {
		frontLightStatus = status;
		print("Set front light status to " + status.toString());
		notifyListeners();
	}

	void setRearLight(int status) {
		rearLightStatus = status;
		print("Set rear light status to " + status.toString());
		notifyListeners();
	}
}