// ignore_for_file: prefer_collection_literals

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'dart:collection';
import 'dart:io';

import 'agent.dart';

class Chrome implements Agent {
  Chrome._internal(this._agent) {
    Random rand = Random(DateTime.now().millisecondsSinceEpoch);
    const possibleScreenSizes = [
      ((1920, 1080), (1920, 1040)),
      ((2560, 1440), (2560, 1400)),
    ];
    const possibleCpuCounts = [2, 4, 8, 16];
    const possibleMemorySizes = [2, 4, 8, 16];

    int i = rand.nextInt(possibleScreenSizes.length);
    screenSize = possibleScreenSizes[i].$1;
    availScreenSize = possibleScreenSizes[i].$2;

    i = rand.nextInt(possibleCpuCounts.length);
    cpuCount = possibleCpuCounts[i];

    i = rand.nextInt(possibleMemorySizes.length);
    memorySize = possibleMemorySizes[i];
  }

  static Future<Chrome> init() async {
    var url =
        Uri.parse('https://jnrbsn.github.io/user-agents/user-agents.json');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // Handle the JSON response here

        return Chrome._internal(jsonResponse[0]);
      } else {
        print('Request failed with status: ${response.statusCode}.');
        throw response.body;
      }
    } catch (e) {
      print('Request failed with error: $e.');
      rethrow;
    }
  }

  @override
  LinkedHashMap<String, dynamic> screenProperties() {
    var m = LinkedHashMap<String, dynamic>();
    m['availWidth'] = availScreenSize.$1;
    m['availHeight'] = availScreenSize.$2;
    m['width'] = screenSize.$1;
    m['height'] = screenSize.$2;
    m['colorDepth'] = 24;
    m['pixelDepth'] = 24;
    m['availLeft'] = 0;
    m['availTop'] = 0;
    return m;
  }

  @override
  LinkedHashMap<String, dynamic> navigatorProperties() {
    final String chromeVersion = agent.split('Chrome/')[1].split(' ')[0];
    final String shortChromeVersion = chromeVersion.split('.')[0];

    final chromium = LinkedHashMap<String, dynamic>();
    chromium['brand'] = 'Chromium';
    chromium['version'] = shortChromeVersion;

    final chrome = LinkedHashMap<String, dynamic>();
    chrome['brand'] = 'Google Chrome';
    chrome['version'] = shortChromeVersion;

    final notAnyBrand = LinkedHashMap<String, dynamic>();
    notAnyBrand['brand'] = ';Not A Brand';
    notAnyBrand['version'] = '99';

    final userAgentData = LinkedHashMap<String, dynamic>();
    userAgentData['brands'] = [chromium, chrome, notAnyBrand];
    userAgentData['mobile'] = false;

    final m = LinkedHashMap<String, dynamic>();
    m['vendorSub'] = '';
    m['productSub'] = '20030107';
    m['vendor'] = 'Google Inc.';
    m['maxTouchPoints'] = 0;
    m['userActivation'] = {};
    m['doNotTrack'] = '1';
    m['geolocation'] = {};
    m['connection'] = {};
    m['webkitTemporaryStorage'] = {};
    m['webkitPersistentStorage'] = {};
    m['hardwareConcurrency'] = cpuCount;
    m['cookieEnabled'] = true;
    m['appCodeName'] = 'Mozilla';
    m['appName'] = 'Netscape';
    m['appVersion'] =
        '5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chromeVersion Safari/537.36';
    m['platform'] = 'Win32';
    m['product'] = 'Gecko';
    m['userAgent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chromeVersion Safari/537.36';
    m['language'] = 'en-US';
    m['languages'] = ['en-US'];
    m['onLine'] = true;
    m['webdriver'] = false;
    m['pdfViewerEnabled'] = true;
    m['scheduling'] = {};
    m['bluetooth'] = {};
    m['clipboard'] = {};
    m['credentials'] = {};
    m['keyboard'] = {};
    m['managed'] = {};
    m['mediaDevices'] = {};
    m['storage'] = {};
    m['serviceWorker'] = {};
    m['wakeLock'] = {};
    m['deviceMemory'] = memorySize;
    m['ink'] = {};
    m['hid'] = {};
    m['locks'] = {};
    m['mediaCapabilities'] = {};
    m['mediaSession'] = {};
    m['permissions'] = {};
    m['presentation'] = {};
    m['serial'] = {};
    m['virtualKeyboard'] = {};
    m['usb'] = {};
    m['xr'] = {};
    m['userAgentData'] = userAgentData;
    m['plugins'] = [
      'internal-pdf-viewer',
      'internal-pdf-viewer',
      'internal-pdf-viewer',
      'internal-pdf-viewer',
      'internal-pdf-viewer'
    ];

    return m;
  }

  @override
  int unix() {
    var now = DateTime.now().millisecondsSinceEpoch;
    var t = now + unixOffset;

    return t;
  }

  @override
  void offsetUnix(int offset) {
    unixOffset += offset;
  }

  @override
  void resetUnix() {
    if (unixOffset > 0) {
      sleep(Duration(milliseconds: unixOffset));
    }
  }

  late final (int, int) screenSize;
  late final (int, int) availScreenSize;

  late final int cpuCount;
  late final int memorySize;
  final String _agent;

  @override
  String get agent => _agent;

  int unixOffset = 0;
}
