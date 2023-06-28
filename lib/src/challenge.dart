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
import 'solver.dart';

const List<String> _widgetCharacters = [
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9'
];

// WidgetID generates a new random widget ID.
String _widgetID() {
  final random = Random();
  final length = random.nextInt(3) + 10;
  final buffer = StringBuffer();

  for (int i = 0; i < length; i++) {
    final charIndex = random.nextInt(_widgetCharacters.length);
    buffer.write(_widgetCharacters[charIndex]);
  }

  return buffer.toString();
}

class Challenge {
  Challenge._({
    required this.host,
    required this.siteKey,
    required this.url,
    required this.widgetID,
    required this.logger,
    required this.agent,
  });

  static Future<Challenge> init(String url, String siteKey,
      {ChallengeOptions? opts}) async {
    opts ??= ChallengeOptions.basicChallengeOptions();
    // if (opts.proxy.isNotEmpty) {
    //   final Uri proxyUrl = Uri.parse(opts.proxy);
    // }

    final String host = url.split('://')[1].split('/')[0];
    final String widgetID = _widgetID();
    final Agent agent = await Chrome.init();
    agent.offsetUnix(-10);

    final Challenge c = Challenge._(
      host: host,
      siteKey: siteKey,
      url: url,
      widgetID: widgetID,
      logger: opts.logger,
      agent: agent,
    );

    c._setupFrames();

    c.logger.log(Level.debug, 'Verifying site configuration...');
    await c._siteConfig();
    c.logger.log(Level.info, 'Requesting captcha...');
    await c._requestCaptcha();

    return c;
  }

  static final Random _rand = Random(DateTime.now().millisecondsSinceEpoch);

  final String host, siteKey;
  final String url, widgetID;
  late final String id, token, category, question;

  final List<Task> _tasks = [];

  final Logger logger;

  final Agent agent;
  late Proof proof;
  late final EventRecorder top, frame;

  Future solve(Solver solver) async {
    logger.log(Level.debug, 'Solving challenge with ${solver.runtimeType}...');
    if (token.isNotEmpty) {
      return;
    }

    final split = question.split(' ');
    final object = split.last
        .replaceAll('motorbus', 'bus')
        .replaceAll('airplane', 'aeroplane')
        .replaceAll('motorcycle', 'motorbike');

    logger.log(Level.debug, 'The type of challenge is "$category"');
    logger.log(Level.debug, 'The target object is "$object"');

    final answers = solver.solve(category, object, _tasks);

    logger.log(Level.debug,
        'Decided on ${answers.length}/${_tasks.length} of the tasks given!');
    logger.log(Level.debug, 'Simulating mouse movements on tiles...');

    _simulateMouseMovements(answers);
    agent.resetUnix();

    final answersAsMap = <String, Task>{};
    for (final Task answer in _tasks) {
      answersAsMap[answer.key] = _answered(answer, answers) as Task;
    }

    final motionData = <String, dynamic>{};
    final frameData = frame.data();
    for (final key in frameData.keys) {
      final value = frameData[key];
      motionData[key] = value;
    }
    motionData['topLevel'] = top.data();
    motionData['v'] = 1;

    final encodedMotionData = json.encode(motionData);

    final m = <String, dynamic>{};
    m['v'] = version;
    m['job_mode'] = category;
    m['answers'] = answersAsMap;
    m['serverdomain'] = host;
    m['sitekey'] = siteKey;
    m['motionData'] = encodedMotionData;
    m['n'] = proof.proof;
    m['c'] = proof.request;

    final b = utf8.encode(json.encode(m));

    final req = http.Request(
      'POST',
      Uri.parse('https://hcaptcha.com/checkcaptcha/$id?s=$siteKey'),
    );
    req.headers['Authority'] = 'hcaptcha.com';
    req.headers['Accept'] = '*/*';
    req.headers['User-Agent'] = agent.agent;
    req.headers['Content-Type'] = 'application/json';
    req.headers['Origin'] = 'https://newassets.hcaptcha.com';
    req.headers['Sec-Fetch-Site'] = 'same-site';
    req.headers['Sec-Fetch-Mode'] = 'cors';
    req.headers['Sec-Fetch-Dest'] = 'empty';
    req.headers['Accept-Language'] = 'en-US,en;q=0.9';
    req.bodyBytes = b;

    final response = await http.Response.fromStream(await req.send());
    final responseBody = jsonDecode(response.body);

    if (!responseBody.get('pass').boolValue) {
      throw Exception('Incorrect answers');
    }

    logger.log(Level.info, 'Successfully completed challenge!');
    token = responseBody.get('generated_pass_UUID').stringValue;
  }

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
    agent.offsetUnix(_rand.nextInt(200) + 200);
    frame = EventRecorder(agent);
    frame.record();
  }

  Future _siteConfig() async {
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

    Prover solver =
        AlgorithmLoader.algorithms()[requestJson['type'] as String]! as Prover;
    proof = await solver.solve(requestJson['req'] as String);
  }

  Future _requestCaptcha() async {
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

    final Map<String, String> form = {
      'v': version,
      'sitekey': siteKey,
      'host': host,
      'hl': 'en',
      'motionData': encodedMotionData,
      'n': proof.proof,
      'c': proof.request,
    };

    final Uri url = Uri.parse('https://hcaptcha.com/getcaptcha?s=$siteKey');
    final http.Request request = http.Request('POST', url);
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

    final List<Map<String, String>> tasks = jsonResponse['tasklist'];
    if (tasks.isEmpty) {
      throw Exception('no tasks in challenge, most likely ratelimited');
    }

    for (int index = 0; index < tasks.length; index++) {
      final Map<String, String> task = tasks[index];
      _tasks.add(Task(
        task['datapoint_uri']!,
        task['task_key']!,
        index,
      ));
    }

    var requestJson = jsonResponse['c'];
    Prover solver =
        AlgorithmLoader.algorithms()[requestJson['type'] as String]! as Prover;
    proof = await solver.solve(requestJson['req']);
  }

  List<_Movement> _generateMouseMovements(
      Vector2 fromPoint, Vector2 toPoint, CurveOpts opts) {
    Curve curve = Curve(fromPoint, toPoint, opts);
    final List<_Movement> movements = [];

    for (Vector2 point in curve.points) {
      agent.offsetUnix(_rand.nextInt(3) + 2);
      movements.add(_Movement(point, agent.unix()));
    }
    return movements;
  }

  void _simulateMouseMovements(List<Task> answers) {
    int totalPages = max(1, (_tasks.length / tilesPerPage).floor());
    Vector2 cursorPos = Vector2(_rand.nextInt(4) + 1, _rand.nextInt(50) + 300);

    int rightBoundary = frameSize.$1;
    int upBoundary = frameSize.$2;
    CurveOpts opts =
        CurveOpts(rightBoundary: rightBoundary, upBoundary: upBoundary);

    for (int page = 0; page < totalPages; page++) {
      List<Task> pageTiles =
          _tasks.sublist(page * tilesPerPage, (page + 1) * tilesPerPage);
      for (Task tile in pageTiles) {
        if (!_answered(tile, answers)) {
          continue;
        }

        Vector2 tilePos = Vector2(
          ((tileImageSize.$1 * tile.index % tilesPerRow) +
              tileImagePadding.$1 * tile.index % tilesPerRow +
              _rand.nextInt(tileImageSize.$1 - 10) +
              10 +
              tileImageStartPosition.$1) as double,
          ((tileImageSize.$2 * tile.index % tilesPerRow) +
              tileImagePadding.$2 * tile.index % tilesPerRow +
              _rand.nextInt(tileImageSize.$2 - 10) +
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
        verifyButtonPosition.$1 + _rand.nextInt(45) + 5,
        verifyButtonPosition.$2 + _rand.nextInt(10) + 5,
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
