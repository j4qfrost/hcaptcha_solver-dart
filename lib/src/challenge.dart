import 'dart:convert';
import 'dart:math';

import 'package:hcaptcha_solver/src/screen/curve.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:vector_math/vector_math.dart';

import 'agents/agent.dart';
import 'algorithm/algorithm.dart';
import 'constants.dart';
import 'event.dart';
import 'screen/options.dart';

class Challenge {
  Challenge(
    this.host,
    this.siteKey,
    this.url,
    this.widgetID,
    this.logger,
    this.agent,
    this.tasks,
  );

  static final Random rand = Random(DateTime.now().millisecondsSinceEpoch);

  final String host, siteKey;
  final String url, widgetID;
  late final String id, token, category, question;

  final List<Task> tasks;

  final Logger logger;

  final Agent agent;
  late Proof proof;
  late final EventRecorder top, frame;

  bool _answered(Task task, List<Task> answers) {
    return answers.where((t) => task.key == t.key).isNotEmpty;
  }

  void _setupFrames() {
    top = EventRecorder(agent);
    top.record();
    top.setData('dr', '');
    top.setData('inv', false);
    top.setData('sc', agent.screenProperties());
    top.setData('nv', agent.navigatorProperties());
    top.setData('exec', false);
    agent.offsetUnix(rand.nextInt(200) + 200);
    frame = EventRecorder(agent);
    frame.record();
  }

  Future<void> _siteConfig() async {
    var url = Uri.parse(
        'https://hcaptcha.com/checksiteconfig?v=$version&host=$host&sitekey=$siteKey&sc=1&swa=1');
    var request = http.Request('GET', url);
    request.headers['Content-Type'] = 'application/json';
    request.headers['User-Agent'] = agent.agent;

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();
    var jsonResponse = jsonDecode(responseBody);

    if (!(jsonResponse['pass'] as bool)) {
      throw Exception('site key is invalid');
    }

    var requestJson = jsonResponse['c'];

    Solver solver =
        AlgorithmLoader.algorithms()[requestJson['type'] as String]! as Solver;
    proof = await solver.solve(requestJson['req'] as String);
  }

  Future<void> requestCaptcha() async {
    var prev = {
      'escaped': false,
      'passed': false,
      'expiredChallenge': false,
      'expiredResponse': false,
    };

    var motionData = {
      'v': 1,
      ...frame.data().map((key, value) => MapEntry(key, value)),
      'topLevel': top.data(),
      'session': {},
      'widgetList': [widgetID],
      'widgetId': widgetID,
      'href': this.url,
      'prev': prev,
    };

    var encodedMotionData = jsonEncode(motionData);

    var form = {
      'v': version,
      'sitekey': siteKey,
      'host': host,
      'hl': 'en',
      'motionData': encodedMotionData,
      'n': proof.proof,
      'c': proof.request,
    };

    var url = Uri.parse('https://hcaptcha.com/getcaptcha?s=$siteKey');
    var request = http.Request('POST', url);
    request.headers['Authority'] = 'hcaptcha.com';
    request.headers['Accept'] = 'application/json';
    request.headers['User-Agent'] = agent.agent;
    request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
    request.headers['Origin'] = 'https://newassets.hcaptcha.com';
    request.headers['Sec-Fetch-Site'] = 'same-site';
    request.headers['Sec-Fetch-Mode'] = 'cors';
    request.headers['Sec-Fetch-Dest'] = 'empty';
    request.headers['Accept-Language'] = 'en-US,en;q=0.9';
    request.bodyFields = form;

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();
    var jsonResponse = jsonDecode(responseBody);

    if (jsonResponse['pass'] != null) {
      token = jsonResponse['generated_pass_UUID'];
      return;
    }

    var success = jsonResponse['success'];
    if (success != null && !success) {
      throw Exception('challenge creation request was rejected');
    }

    id = jsonResponse['key'];
    category = jsonResponse['request_type'];
    question = jsonResponse['requester_question']['en'];

    var tasks = jsonResponse['tasklist'];
    if (tasks.isEmpty) {
      throw Exception('no tasks in challenge, most likely ratelimited');
    }

    for (var index = 0; index < tasks.length; index++) {
      var task = tasks[index];
      tasks.add(Task(
        task['datapoint_uri'],
        task['task_key'],
        index,
      ));
    }

    var requestJson = jsonResponse['c'];
    Solver solver =
        AlgorithmLoader.algorithms()[requestJson['type'] as String]! as Solver;
    proof = await solver.solve(requestJson['req']);
  }

  List<_Movement> _generateMouseMovements(
      Vector2 fromPoint, Vector2 toPoint, CurveOpts opts) {
    Curve curve = Curve(fromPoint, toPoint, opts);
    final List<_Movement> movements = [];

    for (Vector2 point in curve.points) {
      agent.offsetUnix(rand.nextInt(3) + 2);
      movements.add(_Movement(point, agent.unix()));
    }
    return movements;
  }

  void _simulateMouseMovements(List<Task> answers) {
    int totalPages = max(1, (tasks.length / tilesPerPage).floor());
    Vector2 cursorPos = Vector2(rand.nextInt(4) + 1, rand.nextInt(50) + 300);

    int rightBoundary = frameSize.$1;
    int upBoundary = frameSize.$2;
    CurveOpts opts =
        CurveOpts(rightBoundary: rightBoundary, upBoundary: upBoundary);

    for (int page = 0; page < totalPages; page++) {
      List<Task> pageTiles =
          tasks.sublist(page * tilesPerPage, (page + 1) * tilesPerPage);
      for (Task tile in pageTiles) {
        if (!_answered(tile, answers)) {
          continue;
        }

        Vector2 tilePos = Vector2(
          ((tileImageSize.$1 * tile.index % tilesPerRow) +
              tileImagePadding.$1 * tile.index % tilesPerRow +
              rand.nextInt(tileImageSize.$1 - 10) +
              10 +
              tileImageStartPosition.$1) as double,
          ((tileImageSize.$2 * tile.index % tilesPerRow) +
              tileImagePadding.$2 * tile.index % tilesPerRow +
              rand.nextInt(tileImageSize.$2 - 10) +
              10 +
              tileImageStartPosition.$2) as double,
        );

        List<_Movement> movements =
            _generateMouseMovements(cursorPos, tilePos, opts);
        _Movement lastMovement = movements.last;
        for (_Movement move in movements) {
          frame.recordEvent(Event(move.point, 'mm', move.timestamp));
        }
        // TODO: Add a delay for movement up and down.
        frame.recordEvent(
            Event(lastMovement.point, 'md', lastMovement.timestamp));
        frame.recordEvent(
            Event(lastMovement.point, 'mu', lastMovement.timestamp));
        cursorPos = tilePos;
      }

      Vector2 buttonPos = Vector2(
        verifyButtonPosition.$1 + rand.nextInt(45) + 5,
        verifyButtonPosition.$2 + rand.nextInt(10) + 5,
      );

      List<_Movement> movements =
          _generateMouseMovements(cursorPos, buttonPos, opts);
      _Movement lastMovement = movements.last;
      for (_Movement move in movements) {
        frame.recordEvent(Event(move.point, 'mm', move.timestamp));
      }
      frame
          .recordEvent(Event(lastMovement.point, 'md', lastMovement.timestamp));
      frame
          .recordEvent(Event(lastMovement.point, 'mu', lastMovement.timestamp));
      cursorPos = buttonPos;
    }
  }
}

class Task {
  const Task(this.image, this.key, this.index);

  final String image;
  final String key;
  final int index;
}

class ChallengeOptions {
  const ChallengeOptions(this.logger, this.proxy, this.timeout);

  factory ChallengeOptions.basicChallengeOptions() {
    Logger logger = Logger();
    return ChallengeOptions(
      logger,
      '',
      const Duration(seconds: 30),
    );
  }

  final Logger logger;
  final String proxy;
  final Duration timeout;
}

class _Movement {
  const _Movement(this.point, this.timestamp);

  final Vector2 point;
  final int timestamp;
}

// // NewChallenge creates a new hCaptcha challenge.
