import 'algorithm.dart';
import 'package:puppeteer/puppeteer.dart';

class HSW extends Algorithm with Prover {
  Future init() async {
    final browser = await puppeteer.launch(headless: true);
    page = await browser.newPage();

    page!.addScriptTag(content: await source());
  }

  Page? page;

  @override
  String get name => 'hsw';

  @override
  Future<String> prove(String request) async {
    if (page == null) {
      await init();
    }
    return page!.evaluate<String>('hsw("$request")');
  }
}
