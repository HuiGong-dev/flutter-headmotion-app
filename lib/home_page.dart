import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './questions.dart';

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
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  static const methodChannel = MethodChannel('com.huigong.headmotion/method');
  static const attitudeChannel =
      EventChannel('com.huigong.headmotion/attitude');

  String _sensorAvailable = "Unknown";
  Map _currentAttitude = {"pitch": 0.0, "roll": 0.0, "yaw": 0.0};
  String lastMotionType = "still";
  String currentMotionType = "still";
  double _attitudePitchReading = 0;
  double _attitudeRollReading = 0;
  double _attitudeYawReading = 0;
  bool _isReading = false;
  late StreamSubscription attitudeSubscription;

  Future<void> _checkAvailability() async {
    try {
      var available = await methodChannel.invokeMethod('isSensorAvailable');
      setState(() {
        _sensorAvailable = available.toString();
      });
    } on PlatformException catch (e) {
      debugPrint(e.toString());
    }
  }

  _startReading() {
    attitudeSubscription =
        attitudeChannel.receiveBroadcastStream().listen((event) {
      setState(() {
        _currentAttitude = {
          "pitch": event["pitch"],
          "roll": event["roll"],
          "yaw": event["yaw"]
        };
        currentMotionType = _getMotionType(_currentAttitude);
        _attitudePitchReading = event["pitch"];
        _attitudeRollReading = event["roll"];
        _attitudeYawReading = event["yaw"];
      });

      _isReading = true;
      _updateMotionType();
    });
  }

  _updateMotionType() {
    lastMotionType = currentMotionType;
  }

  double _max(Map attitudeMap) {
    double pitch = attitudeMap["pitch"];
    double roll = attitudeMap["roll"];
    double yaw = attitudeMap["yaw"];

    if (pitch.abs() >= roll.abs()) {
      if (pitch.abs() >= yaw.abs()) {
        return pitch;
      } else {
        return yaw;
      }
    } else {
      if (roll.abs() >= yaw.abs()) {
        return roll;
      } else {
        return yaw;
      }
    }
  }

  String _getMotionType(Map attitudeMap) {
    double? pitch = attitudeMap["pitch"];
    double? roll = attitudeMap["roll"];
    double? yaw = attitudeMap["yaw"];

    double maxValue = _max(attitudeMap);

    if (maxValue.abs() < 0.5) {
      return "still";
    }
    if (maxValue == roll) {
      if (maxValue.isNegative) {
        return "tilt left";
      } else {
        return "tilt right";
      }
    }

    if (maxValue == pitch) {
      if (maxValue.isNegative) {
        return "tilt forward";
      } else {
        return "tilt backward";
      }
    }

    if (maxValue == yaw) {
      if (maxValue.isNegative) {
        return "look right";
      } else {
        return "look left";
      }
    }
    return "still";
  }

  _stopReading() {
    setState(() {
      _attitudePitchReading = 0;
      _attitudeRollReading = 0;
      _attitudeYawReading = 0;
    });
    attitudeSubscription.cancel();
    _isReading = false;
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
              Text('Device supported? : $_sensorAvailable'),
              ElevatedButton(
                  onPressed: () => _checkAvailability(),
                  child: const Text('Check Device Supported')),
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
                type: $currentMotionType
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
              const SizedBox(
                height: 50,
              ),
              if (_sensorAvailable == 'true' && _isReading == true)
                ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) =>
                              const Questions(title: 'test nav')));
                    },
                    child: const Text('Go to Answer Questions')),
            ],
          )),
    );
  }
}
