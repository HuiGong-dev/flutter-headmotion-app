import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter CM Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Core Motion Airpods Pro'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const methodChannel = MethodChannel('com.huigong.headmotion/method');
  static const attitudeChannel =
      EventChannel('com.huigong.headmotion/attitude');

  String _sensorAvailable = "Unknown";
  double _attitudePitchReading = 0;
  double _attitudeRollReading = 0;
  double _attitudeYawReading = 0;
  late StreamSubscription attitudeSubscription;

  Future<void> _checkAvailability() async {
    try {
      var available = await methodChannel.invokeMethod('isSensorAvailable');
      setState(() {
        _sensorAvailable = available.toString();
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  _startReading() {
    attitudeSubscription =
        attitudeChannel.receiveBroadcastStream().listen((event) {
      setState(() {
        _attitudePitchReading = event["pitch"];
        _attitudeRollReading = event["roll"];
        _attitudeYawReading = event["yaw"];
      });
    });
  }

  _stopReading() {
    setState(() {
      _attitudePitchReading = 0;
      _attitudeRollReading = 0;
      _attitudeYawReading = 0;
    });
    attitudeSubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Sensor available? : $_sensorAvailable'),
              ElevatedButton(
                  onPressed: () => _checkAvailability(),
                  child: const Text('Check Sensor Available')),
              const SizedBox(
                height: 50.0,
              ),
              if (_attitudeRollReading != 0 ||
                  _attitudePitchReading != 0 ||
                  _attitudeYawReading != 0)
                Text('''
                Pitch: $_attitudePitchReading 
                Roll: $_attitudeRollReading 
                Yaw: $_attitudeYawReading
                '''),
              if (_sensorAvailable == 'true' &&
                  _attitudeRollReading == 0 &&
                  _attitudePitchReading == 0 &&
                  _attitudeYawReading == 0)
                ElevatedButton(
                    onPressed: () => _startReading(),
                    child: const Text('Start Reading')),
              if (_attitudeRollReading != 0 ||
                  _attitudePitchReading != 0 ||
                  _attitudeYawReading != 0)
                ElevatedButton(
                    onPressed: () => _stopReading(),
                    child: const Text('Stop Reading')),
            ],
          )),
    );
  }
}
