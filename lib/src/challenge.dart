import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:hcaptcha_solver/src/screen/curve.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:vector_math/vector_math.dart';

import 'agents/agent.dart';
import 'algorithm/algorithm.dart';
import 'utils.dart';
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
  final length = random.nextInt(2) + 10;
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

  final String host, siteKey;
  final String url, widgetID;
  late final String id, category, question;
  String? token;

  final List<Task> _tasks = [];

  final Logger logger;

  final Agent agent;
  late Proof proof;
  late final EventRecorder top, frame;

  Future solve(Solver solver) async {
    logger.log(Level.debug, 'Solving challenge with ${solver.runtimeType}...');
    if (token != null && token!.isNotEmpty) {
      return;
    }

    final split = question.split(' ');
    final object = split.last
        .replaceFirst('motorbus', 'bus')
        .replaceFirst('airplane', 'aeroplane')
        .replaceFirst('motorcycle', 'motorbike');

    logger.log(Level.debug, 'The type of challenge is "$category"');
    logger.log(Level.debug, 'The target object is "$object"');

    final List<Task> answers = solver.solve(category, object, _tasks);

    logger.log(Level.debug,
        'Decided on ${answers.length}/${_tasks.length} of the tasks given!');
    logger.log(Level.debug, 'Simulating mouse movements on tiles...');

    _simulateMouseMovements(answers);
    agent.resetUnix();

    final LinkedHashMap<String, String> answersAsMap =
        LinkedHashMap<String, String>();
    for (Task answer in _tasks) {
      answersAsMap[answer.key] = _answered(answer, answers).toString();
    }

    final LinkedHashMap<String, dynamic> motionData =
        LinkedHashMap<String, dynamic>();
    motionData.addAll(frame.data());
    motionData['topLevel'] = top.data();
    motionData['v'] = 1;

    final String encodedMotionData = jsonEncode(motionData);

    LinkedHashMap<String, dynamic> m = LinkedHashMap<String, dynamic>();
    m['v'] = version;
    m['job_mode'] = category;
    m['answers'] = answersAsMap;
    m['serverdomain'] = host;
    m['sitekey'] = siteKey;
    m['motionData'] = encodedMotionData;
    m['n'] = proof.proof;
    m['c'] = proof.request;

    final req = http.Request(
      'POST',
      Uri.parse('https://hcaptcha.com/checkcaptcha/$id?s=$siteKey'),
    );
    req.headers['Authority'] = 'hcaptcha.com';
    req.headers['Accept'] = 'application/json';
    req.headers['User-Agent'] = agent.agent;
    req.headers['Content-Type'] = 'application/json';
    req.headers['Origin'] = 'https://newassets.hcaptcha.com';
    req.headers['Sec-Fetch-Site'] = 'same-site';
    req.headers['Sec-Fetch-Mode'] = 'cors';
    req.headers['Sec-Fetch-Dest'] = 'empty';
    req.headers['Accept-Language'] = 'en-US,en;q=0.9';
    req.body = jsonEncode(m);

    final response = await http.Response.fromStream(await req.send());
    final responseBody = jsonDecode(response.body);

    if (!responseBody['pass']) {
      throw Exception('Incorrect answers');
    }

    logger.log(Level.info, 'Successfully completed challenge!');
    token = responseBody['generated_pass_UUID'];
  }

  bool _answered(Task task, List<Task> answers) {
    return answers.any((t) => task.key == t.key);
  }

  void _setupFrames() {
    top = EventRecorder(agent);
    top.record();
    top.setData('dr', '');
    top.setData('inv', false);
    top.setData('sc', agent.screenProperties());
    top.setData('nv', agent.navigatorProperties());
    top.setData('exec', false);
    agent.offsetUnix(Seed.between(200, 400));
    frame = EventRecorder(agent);
    frame.record();
  }

  Future _siteConfig() async {
    final Uri url = Uri.parse(
        'https://hcaptcha.com/checksiteconfig?v=$version&host=$host&sitekey=$siteKey&sc=1&swa=1');
    final http.Request request = http.Request('GET', url);
    request.headers['Content-Type'] = 'application/json';
    request.headers['User-Agent'] = agent.agent;

    final http.StreamedResponse response = await request.send();
    final String responseBody = await response.stream.bytesToString();
    final jsonResponse = jsonDecode(responseBody);

    if (!(jsonResponse['pass'] as bool)) {
      throw Exception('site key is invalid');
    }

    final requestJson = jsonResponse['c'];

    Prover solver =
        AlgorithmLoader.algorithms()[requestJson['type'] as String]! as Prover;
    proof = await solver.solve(requestJson['req'] as String);
  }

  Future _requestCaptcha() async {
    final LinkedHashMap<String, bool> prev = LinkedHashMap();
    prev.addAll({
      'escaped': false,
      'passed': false,
      'expiredChallenge': false,
      'expiredResponse': false,
    });

    final LinkedHashMap<String, dynamic> motionData = LinkedHashMap();

    motionData.addAll({
      'v': 1,
      ...frame.data(),
      'topLevel': top.data(),
      'session': {},
      'widgetList': [widgetID],
      'widgetId': widgetID,
      'href': this.url,
      'prev': prev,
    });

    final LinkedHashMap<String, String> form = LinkedHashMap();

    form.addAll({
      'v': version,
      'sitekey': siteKey,
      'host': host,
      'hl': 'en',
      'motionData': jsonEncode(motionData),
      'n': proof.proof,
      'c': proof.request,
    });

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

    final http.StreamedResponse response = await request.send();
    final String responseBody = await response.stream.bytesToString();
    final jsonResponse = jsonDecode(responseBody);

    if (jsonResponse['pass'] != null) {
      token = jsonResponse['generated_pass_UUID'];
      return;
    }

    final success = jsonResponse['success'];
    if (success != null && !success) {
      throw requestToCurl(request);
    }

    id = jsonResponse['key'];
    category = jsonResponse['request_type'];
    question = jsonResponse['requester_question']['en'];

    final List tasks = jsonResponse['tasklist'];
    if (tasks.isEmpty) {
      throw Exception('no tasks in challenge, most likely ratelimited');
    }

    for (int index = 0; index < tasks.length; index++) {
      final Map<String, dynamic> task = tasks[index];
      _tasks.add(Task(
        task['datapoint_uri']!,
        task['task_key']!,
        index,
      ));
    }

    final requestJson = jsonResponse['c'];
    Prover solver =
        AlgorithmLoader.algorithms()[requestJson['type'] as String]! as Prover;
    proof = await solver.solve(requestJson['req']);
  }

  List<_Movement> _generateMouseMovements(
      Vector2 fromPoint, Vector2 toPoint, CurveOpts opts) {
    Curve curve = Curve(fromPoint, toPoint, opts);
    List<_Movement> movements = [];

    for (Vector2 point in curve.points) {
      agent.offsetUnix(Seed.between(2, 5));
      movements.add(_Movement(point, agent.unix()));
    }
    return movements;
  }

  void _simulateMouseMovements(List<Task> answers) {
    int totalPages = max(1, (_tasks.length / tilesPerPage).floor());
    Vector2 cursorPos = Vector2(
        Seed.between(1, 5).toDouble(), Seed.between(300, 350).toDouble());

    int rightBoundary = frameSize.$1;
    int upBoundary = frameSize.$2;
    CurveOpts opts =
        CurveOpts(rightBoundary: rightBoundary, upBoundary: upBoundary);

    for (int page = 0; page < totalPages; page++) {
      List<Task> pageTiles = (_tasks.length < tilesPerPage)
          ? _tasks
          : _tasks.sublist(page * tilesPerPage, (page + 1) * tilesPerPage);
      for (Task tile in pageTiles) {
        if (!_answered(tile, answers)) {
          continue;
        }

        Vector2 tilePos = Vector2(
          ((tileImageSize.$1 * tile.index % tilesPerRow) +
                  tileImagePadding.$1 * tile.index % tilesPerRow +
                  Seed.between(10, tileImageSize.$1) +
                  tileImageStartPosition.$1)
              .toDouble(),
          ((tileImageSize.$2 * tile.index % tilesPerRow) +
                  tileImagePadding.$2 * tile.index % tilesPerRow +
                  Seed.between(10, tileImageSize.$2) +
                  tileImageStartPosition.$2)
              .toDouble(),
        );

        List<_Movement> movements =
            _generateMouseMovements(cursorPos, tilePos, opts);
        if (movements.isEmpty) continue;
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
        verifyButtonPosition.$1 + Seed.between(5, 50).toDouble(),
        verifyButtonPosition.$2 + Seed.between(5, 15).toDouble(),
      );

      List<_Movement> movements =
          _generateMouseMovements(cursorPos, buttonPos, opts);
      if (movements.isEmpty) continue;
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
