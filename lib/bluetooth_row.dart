import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'icons.dart';

class BluetoothRow extends StatefulWidget {
	final int rssi;
	final BluetoothDevice device;
	final Future<void> Function(bool) onTap;
	final Function() beforeDisconnect;
	final void Function() onForget;
	final List<String> info;

	BluetoothRow({
		@required this.device,
		this.rssi,
		@required this.onTap,
		this.onForget,
		this.info = const [],
		this.beforeDisconnect
	});

	@override
	_BluetoothRowState createState() => _BluetoothRowState();
}

class _BluetoothRowState extends State<BluetoothRow> {
	BluetoothDeviceState _state;
	StreamSubscription<BluetoothDeviceState> _stateSubscription;

	void _initStateSubscription() {
		_stateSubscription = widget.device.state.listen((newState) {
			_state = newState;
		});
	}

	@override
	void initState() {
		super.initState();
		_initStateSubscription();
	}

	@override
	void didUpdateWidget(BluetoothRow oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.device != widget.device) {
			_stateSubscription.cancel();
			_initStateSubscription();
		}
	}

	@override
	void dispose() {
		super.dispose();
		_stateSubscription.cancel();
	}

	void _showInfo(BuildContext context) {
		showDialog(
			context: context,
			barrierDismissible: true,
			builder: (BuildContext context) {
				return AlertDialog(
					title: Text((widget.device.name.length > 0) ? widget.device.name : "Unknown device"),
					content: SingleChildScrollView(
						child: ListBody(
							children: [
								Text("Address: ${widget.device.id}"),
								if (widget.rssi != null) Text("RSSI: widget.rssi dBm"),
								...widget.info.map((line) => Text(line))
							]
						)
					),
					actions: [
						if (_state == BluetoothDeviceState.connected) ...[
							FlatButton(
								child: Text("Disconnect"),
								onPressed: () {
									if (widget.beforeDisconnect != null) {
										widget.beforeDisconnect();
									}
									widget.device.disconnect();
									Navigator.of(context).pop();
								}
							)
						],
						if (widget.onForget != null) FlatButton(
							child: Text("Forget"),
							onPressed: () {
								widget.onForget();
								Navigator.of(context).pop();
							}
						)
					]
				);
			}
		);
	}

	IconData _pickIconData() {
		if (widget.rssi == null || _state == BluetoothDeviceState.connected) {
			return Icons.bluetooth_connected;
		}
		else {
			if (widget.rssi < -85) {
				return SignalIcons.signal_1;
			}
			else if (widget.rssi < -75) {
				return SignalIcons.signal_2;
			}
			else {
				return SignalIcons.signal_3;
			}
		}
	}
	
	@override
	Widget build(BuildContext context) {
		return Hero(
			tag: widget.device.id,
			child: Material(
				child: ListTile(
					leading: Icon(_pickIconData()),
					title: widget.device.name.length > 0 ? 
						Text(widget.device.name) :
						Text(widget.device.id.id, style: TextStyle(
							color: Colors.grey
						)),
					trailing: GestureDetector(
						child: Icon(Icons.info),
						onTap: () => _showInfo(context)
					),
					onTap: (widget.onTap != null) ? () => widget.onTap(_state == BluetoothDeviceState.connected) : null
				)
			)
		);
	}
}