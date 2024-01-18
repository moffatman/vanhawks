import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'icons.dart';

class BluetoothRow extends StatefulWidget {
	final int? rssi;
	final BluetoothDevice device;
	final Future<void> Function(bool)? onTap;
	final VoidCallback? beforeDisconnect;
	final VoidCallback? onForget;
	final List<String> info;
	final bool infoButton;

	BluetoothRow({
		required this.device,
		this.rssi,
		this.onTap,
		this.onForget,
		this.info = const [],
		this.beforeDisconnect,
		this.infoButton = false
	});

	@override
	_BluetoothRowState createState() => _BluetoothRowState();
}

class _BluetoothRowState extends State<BluetoothRow> {
	BluetoothConnectionState? _state;
	late StreamSubscription<BluetoothConnectionState> _stateSubscription;

	void _initStateSubscription() {
		_stateSubscription = widget.device.connectionState.listen((newState) {
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
					title: Text((widget.device.platformName.length > 0) ? widget.device.platformName : "Unknown device"),
					content: SingleChildScrollView(
						child: ListBody(
							children: [
								if (widget.rssi != null) Text("RSSI: ${widget.rssi} dBm"),
								...widget.info.map((line) => Text(line)),
								Text(""),
								Text("MAC Address: ${widget.device.remoteId}", style: TextStyle(fontSize: 14), textAlign: TextAlign.left)
							]
						)
					),
					actions: [
						if (_state == BluetoothConnectionState.connected) ...[
							TextButton(
								child: Text("Disconnect"),
								onPressed: () {
									Navigator.of(context).pop();
									widget.beforeDisconnect?.call();
									widget.device.disconnect();
								}
							)
						],
						if (widget.onForget != null) TextButton(
							child: Text("Forget"),
							onPressed: () {
								Navigator.of(context).pop();
								widget.onForget?.call();
							}
						)
					]
				);
			}
		);
	}

	IconData _pickIconData() {
		if (widget.rssi == null || _state == BluetoothConnectionState.connected) {
			return Icons.bluetooth_connected;
		}
		else {
			if (widget.rssi! < -85) {
				return SignalIcons.signal_1;
			}
			else if (widget.rssi! < -75) {
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
			tag: widget.device.remoteId,
			child: Material(
				child: ListTile(
					leading: Icon(_pickIconData()),
					title: widget.device.platformName.length > 0 ? 
						Text(widget.device.platformName) :
						Text(widget.device.remoteId.str, style: TextStyle(
							color: Colors.grey
						)),
					trailing: widget.infoButton ? GestureDetector(
						child: Icon(Icons.info),
						onTap: () => _showInfo(context)
					) : null,
					onTap: (widget.onTap != null) ? () => widget.onTap!(_state == BluetoothConnectionState.connected) : null
				)
			)
		);
	}
}