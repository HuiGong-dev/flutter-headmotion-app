import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundpool/soundpool.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import './question.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<List<Question>> fetchQuestions(http.Client client) async {
  final randomNumber = Random();
// random question number from 5 to 10
  int questionNumber = 5 + randomNumber.nextInt(6);
  final response = await client.get(Uri.parse(
      'https://opentdb.com/api.php?amount=' +
          questionNumber.toString() +
          '&category=18&type=boolean'));

  return compute(parseQuestions, response.body);
}

List<Question> parseQuestions(String responseBody) {
  final parsed = jsonDecode(responseBody).cast<String, dynamic>();

  final responseCode = parsed['response_code'];
  if (responseCode != 0) {
    debugPrint("Error! API respond code: $responseCode");
  }
  final responseResults = parsed['results'];

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
  late StreamSubscription attitudeSubscription;
  List<Question>? questions;
  int currentQuestionIndex = 0;
  int headMotionCount = 0;
  int userCorrectCount = 0;
  bool isGameStarted = false;

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
      _isDeviceSupported =
          await methodChannel.invokeMethod('isSensorAvailable');
    } on PlatformException catch (e) {
      debugPrint(e.toString());
    }
  }

  // Future<void> _checkIsDeviceMotionActive() async {
  //   try {
  //     _isDeviceMotionActive =
  //         await methodChannel.invokeMethod('isDeviceMotionActive');
  //   } on PlatformException catch (e) {
  //     debugPrint(e.toString());
  //   }
  // }

  _startReading() {
    attitudeSubscription =
        attitudeChannel.receiveBroadcastStream().listen((event) {
      _currentAttitude = {
        "pitch": event["pitch"],
        "roll": event["roll"],
        "yaw": event["yaw"]
      };
      currentMotionType = _getMotionType(_currentAttitude);
      _attitudePitchReading = event["pitch"];
      _attitudeRollReading = event["roll"];
      _attitudeYawReading = event["yaw"];

      if (isGameStarted &&
          currentMotionType != lastMotionType &&
          currentMotionType != "still") {
        debugPrint('motion event: $currentMotionType');
        handleHeadMotionEvent();
      }

      //_isReading = true;
      _updateMotionType();
    });
  }

  void nextQuestion() {
    if (currentQuestionIndex + 1 < questions!.length) {
      currentQuestionIndex++;
      debugPrint(
          "increased index to: $currentQuestionIndex. correct answer: ${questions![currentQuestionIndex].correctAnswer}");
      _userAnswer = "unknown";
      setState(() {
        debugPrint("set state called from next question");
      });
    } else {
      //to show start button
      isGameStarted = false;
      _showScore();
    }
  }

  void showCorrectToast() {
    Fluttertoast.showToast(
        msg: "Correct!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  void showWrongToast() {
    Fluttertoast.showToast(
        msg:
            'Uh-oh, it\'s actually ${questions![currentQuestionIndex].correctAnswer} ',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> handleHeadMotionEvent() async {
    if (currentMotionType == "tilt left") {
      headMotionCount++;
      _userAnswer = "True";
      if (questions![currentQuestionIndex].correctAnswer == _userAnswer) {
        userCorrectCount++;
        showCorrectToast();
        await pool.play(soundCorrect);
      } else {
        showWrongToast();
        await pool.play(soundWrong);
      }
      setState(() {
        debugPrint("set state called from tilt left event");
      });

      Future.delayed(const Duration(milliseconds: 1000), () {
        nextQuestion();
      });
    }
    if (currentMotionType == "tilt right") {
      headMotionCount++;
      _userAnswer = "False";
      if (questions![currentQuestionIndex].correctAnswer == _userAnswer) {
        userCorrectCount++;
        showCorrectToast();
        await pool.play(soundCorrect);
      } else {
        showWrongToast();
        await pool.play(soundWrong);
      }
      setState(() {
        debugPrint("set state called from tilt right event");
      });

      Future.delayed(const Duration(milliseconds: 1000), () {
        nextQuestion();
      });
    }
  }

  void _updateMotionType() {
    lastMotionType = currentMotionType;
  }

  //todo: start game logic
  Future<void> _startGame() async {
    checkAirpods();
    // _checkIsDeviceMotionActive();
    //debugPrint("_checkIsDeviceMotionActive: $_isDeviceMotionActive");
    if (!_isDeviceSupported) {
      debugPrint('device: $_isDeviceSupported. pods: $_isAirpodsReady');
      _showMyDialog();
    } else {
      questions = await fetchQuestions(http.Client());

      questions == null ? isGameStarted = false : isGameStarted = true;
      setState(() {});
    }
  }

  void _gameOver() {
    questions = null;
    _userAnswer = 'unknown';
    _currentAttitude = {"pitch": 0.0, "roll": 0.0, "yaw": 0.0};
    lastMotionType = "still";
    currentMotionType = "still";
    _attitudePitchReading = 0;
    _attitudeRollReading = 0;
    _attitudeYawReading = 0;

    currentQuestionIndex = 0;
    headMotionCount = 0;
    userCorrectCount = 0;
    isGameStarted = false;
    setState(() {});
  }

  void checkAirpods() {
    if (_attitudeRollReading != 0 ||
        _attitudePitchReading != 0 ||
        _attitudeYawReading != 0) {
      _isAirpodsReady = true;
    }
  }

  Future<void> _showScore() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Game Over',
            softWrap: true,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              'Your Score is:'
              '$userCorrectCount/${questions!.length}',
              softWrap: true,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.purple,
              ),
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
                  color: Color(0xFF753188),
                ),
              ),
              onPressed: () {
                _gameOver();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
                  'Your device may not support Airpods Pro head motion.'
                  ' Please connect your phone with Airpods Pro and try again.',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF753188),
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

    if (maxValue.abs() < 0.4) {
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

  // _stopReading() {
  //   setState(() {
  //     _attitudePitchReading = 0;
  //     _attitudeRollReading = 0;
  //     _attitudeYawReading = 0;
  //   });
  //   attitudeSubscription.cancel();
  //   _isReading = false;
  // }

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
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.only(top: 20),
        alignment: Alignment.bottomLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              questions == null
                  ? 'Progress: 0/?'
                  : 'Progress: $headMotionCount /${questions!.length}',
              softWrap: true,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Color(0xFF753188),
              ),
            ),
            Text(
              'Correct: $userCorrectCount',
              softWrap: true,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Color(0xFF753188),
              ),
            )
          ],
        ));

    Widget buttonSection = Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Icon(
            (_userAnswer == "True"
                ? Icons.check_circle
                : Icons.check_circle_outline),
            color: Colors.purple,
            size: 70,
          ),
          Icon(
            (_userAnswer == "False"
                ? Icons.dangerous
                : Icons.dangerous_outlined),
            color: Theme.of(context).colorScheme.primary,
            size: 70,
          ),
        ],
      ),
    );

    Widget questionSection = Container(
      margin: const EdgeInsets.only(left: 20, bottom: 20, right: 20),
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
      child: Text(
        questions == null
            ? 'Press start button to start game'
            : HtmlUnescape().convert(questions![currentQuestionIndex].question),
        softWrap: true,
        style: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w400,
          color: Colors.purple,
        ),
      ),
    );

    Widget startButton = Container(
      alignment: Alignment.center,
      width: 200,
      height: 70,
      child: ElevatedButton(
          style: ElevatedButton.styleFrom(primary: const Color(0xFF753188)),
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
          textSection,
          questionSection,
          buttonSection,
          if (isGameStarted == false) startButton,
        ],
      ),
    );
  }
}
