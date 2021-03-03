import 'dart:async';
import 'dart:convert';

import 'package:dobdroid/direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:intl/intl.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOB@STL',
      theme: ThemeData(
        brightness: Brightness.dark,
        backgroundColor: Colors.black54,
        dialogBackgroundColor: Colors.black12,
        scaffoldBackgroundColor: Colors.black54,
        primarySwatch: Colors.orange,
        accentColor: Colors.orange,
      ),
      home: MyHomePage(title: 'DOB@STL'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

enum Command { LEFT, RIGHT, UP, DOWN }

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  NumberFormat fmtAngle = new NumberFormat('###.00');
  NumberFormat fmtSpeed = new NumberFormat('#.00');
  FlutterBlue _flutterBlue = FlutterBlue.instance;
  BluetoothDevice _dobastl;
  BluetoothCharacteristic rxCharacteristic;
  BluetoothCharacteristic txCharacteristic;
  GlobalKey<DirectionState> _keyDir = GlobalKey();

  bool _scanning = false;
  bool _connected = false;

  String tx1 = "";
  String tx2 = "";

  @override
  void initState() {
    super.initState();
    _flutterBlue.setLogLevel(LogLevel.info);
    print('Flutter blue log level: ${_flutterBlue.logLevel}');
    WidgetsBinding.instance.addObserver(this);
    _connectBLE();
  }

  @override
  void dispose() async {
    await _disconnectBLE();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        {
          print('Detached');
          await _disconnectBLE();
          break;
        }
      case AppLifecycleState.inactive:
        {
          print('Inactive');
          break;
        }
      case AppLifecycleState.paused:
        {
          print('Paused');
          await _disconnectBLE();
          break;
        }
      case AppLifecycleState.resumed:
        {
          print('Resumed');
          _connectBLE();
          break;
        }
    }
    super.didChangeAppLifecycleState(state);
  }

  void _connectBLE() {
    StreamSubscription<ScanResult> scanSubscription;

    try {
      scanSubscription = _flutterBlue.scan().listen((scanResult) async {
        setState(() {
          _scanning = true;
          _connected = false;
        });

        final BluetoothDevice device = scanResult.device;
        if (device.name == 'DOBastl') {
          scanSubscription.cancel();
          _flutterBlue.stopScan();
          await device.connect();
          print('DOBastl found');

          setState(() {
            _dobastl = device;
          });

          List<BluetoothService> services = await device.discoverServices();
          services.forEach((service) async {
            await _handleBLEService(service);
          });
        }
      });

    } catch (e) {
      print('Kunda');
    }
  }

  Future _disconnectBLE() async {
    if ((null != txCharacteristic) && (txCharacteristic.isNotifying)) {
      await txCharacteristic.setNotifyValue(false);
    }
    if (null != _dobastl) {
      await _dobastl.disconnect();
    }
    setState(() {
      txCharacteristic = null;
      rxCharacteristic = null;
      _dobastl = null;
      _scanning = false;
      _connected = false;
      print('BLE disconnected');
    });
  }

  Future _handleBLEService(BluetoothService service) async {
    if (service.uuid.toString() == '6e400001-b5a3-f393-e0a9-e50e24dcca9e') {
      print(service.uuid.toString());
      var characteristics = service.characteristics;
      for (BluetoothCharacteristic c in characteristics) {
        if (c.uuid.toString() == '6e400002-b5a3-f393-e0a9-e50e24dcca9e') {
          rxCharacteristic = c;
        }
        if (c.uuid.toString() == '6e400003-b5a3-f393-e0a9-e50e24dcca9e') {
          txCharacteristic = c;
        }
      }
      await txCharacteristic.setNotifyValue(true);
      txCharacteristic.value.listen((value) {
        _updateDeviceStatus(value);
      });
      if ((null != rxCharacteristic) && (null != txCharacteristic)) {
        setState(() {
          _scanning = false;
          _connected = true;
          print('BLE connected');
        });
      }
    }
  }

  void _updateDeviceStatus(List<int> value) {
    setState(() {
      String t = utf8.decode(value);
      //print('[$t]');
      if (t.startsWith('A')) {
        tx1 = t;
        final idxA = t.indexOf('A');
        final idxS = t.indexOf('S');
        final idxZ = t.indexOf('Z');
        final idxL = t.indexOf('L');
        if ((idxA >= 0) && (idxS >= 0) && (idxZ >= 0) && (idxL >= 0)) {
          final aAngleDeg = double.parse(t.substring(idxA + 1, idxS));
          final aSpeedDegSec = double.parse(t.substring(idxS + 1, idxZ));
          final aMsAzi = int.parse(t.substring(idxZ + 1, idxL));
          final aMsAlt = int.parse(t.substring(idxL + 1));
          _keyDir.currentState.setActualDynamicParams(aAngleDeg, aSpeedDegSec);
        }
      } else if (t.startsWith('P')) {
          tx2 = t;
          final idxPosAzi = t.indexOf('PZ');
          final idxPosAlt = t.indexOf('PL');
          final aPosAziDeg = double.parse(t.substring(idxPosAzi + 2, idxPosAlt));
          final aPosAltDeg = double.parse(t.substring(idxPosAlt + 2));
      }
    });
  }

  void _onPointerMove(double angleDeg, double speedDegSec) {
    _sendBLEMessage('M ${fmtAngle.format(angleDeg)} ${fmtSpeed.format(speedDegSec)}');
  }

  void _onPointerIdle() {
    _sendBLEMessage('I ');
  }

  void _onHardStop() {
    _sendBLEMessage('X ');
  }

  void _sendBLEMessage(String msg) async {
    if (null != rxCharacteristic) {
      await rxCharacteristic.write(utf8.encode(msg));
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
          leading: Icon(
            _scanning ? Icons.bluetooth_searching : _connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: _connected ? Colors.lightBlueAccent : Colors.white70,
            //size: 24,
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            IconButton(
                icon: Icon(Icons.block),
                tooltip: 'Hard stop',
                onPressed: () {
                  _onHardStop();
                }),
            Text(tx1),
            Text(tx2),
            Expanded(
                child: Direction(
              key: _keyDir,
              onMove: (double angleDeg, double speedDegSec) {
                _onPointerMove(angleDeg, speedDegSec);
              },
              onIdle: () {
                _onPointerIdle();
              },
              maxSpeedDegSec: 2.5,
            ))
          ],
        ));
  }
}
