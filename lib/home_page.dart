import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './questions.dart';
import 'package:soundpool/soundpool.dart';

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

  Soundpool pool = Soundpool.fromOptions();
  late int soundCorrect;
  late int soundWrong;

  bool _isSoundInited = false;
  bool _isDeviceSupported = false;
  bool _isAirpodsReady = false;
  String _userAnswer = 'unknown';
  Map _currentAttitude = {"pitch": 0.0, "roll": 0.0, "yaw": 0.0};
  String lastMotionType = "still";
  String currentMotionType = "still";
  double _attitudePitchReading = 0;
  double _attitudeRollReading = 0;
  double _attitudeYawReading = 0;
  bool _isReading = false;
  late StreamSubscription attitudeSubscription;

  Future<void> _initSound() async {
    soundCorrect =
        await rootBundle.load("sounds/correct.mp3").then((ByteData soundData) {
      return pool.load(soundData);
    });
    await pool.play(soundCorrect);
    soundWrong =
        await rootBundle.load("sounds/wrong.mp3").then((ByteData soundData) {
      return pool.load(soundData);
    });
    await pool.play(soundWrong);
    _isSoundInited = true;
  }

  Future<void> _checkAvailability() async {
    try {
      var available = await methodChannel.invokeMethod('isSensorAvailable');
      setState(() {
        _isDeviceSupported = available;
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

        if (currentMotionType != lastMotionType &&
            currentMotionType != "still") {
          debugPrint('motion event: $currentMotionType');
          handleHeadMotionEvent();
        }

        // Future.delayed(const Duration(milliseconds: 200), () {
        //   _userAnswer = "unknown";
        // });
      });

      _isReading = true;
      _updateMotionType();
    });
  }

  void nextQuestion() {
    _userAnswer = "unknown";
  }

  Future<void> handleHeadMotionEvent() async {
    if (currentMotionType == "tilt left") {
      _userAnswer = "true";
      await pool.play(soundCorrect);
    }
    if (currentMotionType == "tilt right") {
      _userAnswer = "false";
      await pool.play(soundWrong);
    }
  }

  void _updateMotionType() {
    lastMotionType = currentMotionType;
  }

  //todo: start game logic
  void _startGame() {
    if (!_isAirpodsReady || !_isAirpodsReady) {
      _showMyDialog();
    }
  }

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Alert',
            softWrap: true,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Colors.purple,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text(
                  'Your device or Airpods pro may not be ready.'
                  ' Please try later.',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    // color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Got it',
                softWrap: true,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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

    if (maxValue.abs() < 0.45) {
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
    if (!_isSoundInited) {
      _initSound();
    }

    if (_isDeviceSupported == false) {
      _checkAvailability();
    }
    if (_isDeviceSupported) {
      _startReading();
    }
    if (_isDeviceSupported == true && _attitudeRollReading != 0 ||
        _attitudePitchReading != 0 ||
        _attitudeYawReading != 0) {
      _isAirpodsReady = true;
    }

    Widget textSection = Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        '''
         Device supported:  $_isDeviceSupported
        Airpods Pro ready: $_isAirpodsReady
        ''',
        softWrap: true,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: Colors.purple,
        ),
      ),
    );

    Widget buttonSection = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Icon(
          (_userAnswer == "true"
              ? Icons.check_circle
              : Icons.check_circle_outline),
          color: Colors.purple,
          size: 60,
        ),
        Icon(
          (_userAnswer == "false" ? Icons.dangerous : Icons.dangerous_outlined),
          color: Colors.purple,
          size: 60,
        ),
      ],
    );

    Widget questionSection = const Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        'qestions section qestions section qestions section qestions section',
        softWrap: true,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: Colors.purple,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              questionSection,
              buttonSection,
              textSection,
              ElevatedButton(
                  onPressed: () => _startGame(),
                  child: const Padding(
                    padding: EdgeInsets.all(15),
                    child: Text(
                      "Start",
                      style: TextStyle(
                        fontSize: 30,
                      ),
                    ),
                  ))
              // if (_attitudeRollReading != 0 ||
              //     _attitudePitchReading != 0 ||
              //     _attitudeYawReading != 0)
              //   Text('''
              //   Pitch: $_attitudePitchReading
              //   Roll: $_attitudeRollReading
              //   Yaw: $_attitudeYawReading
              //   type: $currentMotionType
              //   '''),
              // if (_isDeviceSupported == true &&
              //     _attitudeRollReading == 0 &&
              //     _attitudePitchReading == 0 &&
              //     _attitudeYawReading == 0)
              //   ElevatedButton(
              //       onPressed: () => _startReading(),
              //       child: const Text('Start Reading')),
              // if (_attitudeRollReading != 0 ||
              //     _attitudePitchReading != 0 ||
              //     _attitudeYawReading != 0)
              //   ElevatedButton(
              //       onPressed: () => _stopReading(),
              //       child: const Text('Stop Reading')),

              // if (_isDeviceSupported == true && _isReading == true)
              //   ElevatedButton(
              //       onPressed: () {
              //         Navigator.of(context).push(MaterialPageRoute(
              //             builder: (context) =>
              //                 const Questions(title: 'test nav')));
              //       },
              //       child: const Text('Go to Answer Questions')),
            ],
          )),
    );
  }
}
