import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundpool/soundpool.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import './question.dart';

Future<List<Question>> fetchQuestions(http.Client client) async {
  final response = await client.get(Uri.parse(
      'https://opentdb.com/api.php?amount=3&category=9&type=boolean'));

  return compute(parseQuestions, response.body);
}

List<Question> parseQuestions(String responseBody) {
  final parsed = jsonDecode(responseBody).cast<String, dynamic>();

  final responseCode = parsed['response_code'];
  final responseResults = parsed['results'];
  debugPrint(responseResults[0].toString());
  return responseResults
      .map<Question>((json) => Question.fromJson(json))
      .toList();
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

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

    soundWrong =
        await rootBundle.load("sounds/wrong.mp3").then((ByteData soundData) {
      return pool.load(soundData);
    });

    _isSoundInited = true;
  }

  Future<void> _checkAvailability() async {
    try {
      var available = await methodChannel.invokeMethod('isSensorAvailable');
      setState(() {
        _isDeviceSupported = available;
      });
      //test fetch questions
      var questions = await fetchQuestions(http.Client());
      debugPrint("questions:" + HtmlUnescape().convert(questions[0].question));
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

    Widget textSection = Container(
        margin: const EdgeInsets.all(20),
        alignment: Alignment.bottomLeft,
        child: Text(
          '''
         Device supported:  $_isDeviceSupported
        Airpods Pro ready: $_isAirpodsReady
        ''',
          softWrap: true,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.purple,
          ),
        ));

    Widget buttonSection = Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Icon(
            (_userAnswer == "true"
                ? Icons.check_circle
                : Icons.check_circle_outline),
            color: Colors.purple,
            size: 70,
          ),
          Icon(
            (_userAnswer == "false"
                ? Icons.dangerous
                : Icons.dangerous_outlined),
            color: Colors.purple,
            size: 70,
          ),
        ],
      ),
    );

    Widget questionSection = Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerLeft,
      child: const Text(
        'Furby was released in 1998.',
        softWrap: true,
        style: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w400,
          color: Colors.purple,
        ),
      ),
    );

    Widget startButton = Container(
      child: Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 200,
            height: 70,
            child: ElevatedButton(
                onPressed: () => _startGame(),
                child: const Padding(
                  padding: EdgeInsets.all(15),
                  child: Text(
                    "Start",
                    style: TextStyle(
                      fontSize: 32,
                    ),
                  ),
                )),
          )),
    );

    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: ListView(
        // alignment: Alignment.centerLeft,
        children: [
          questionSection,
          buttonSection,
          startButton,
          textSection,

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
      ),
    );
  }
}
