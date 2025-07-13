import 'package:file_picker/file_picker.dart';
import 'package:mangayomi/src/rust/api/tokenizer_wrapper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> pickFileAbsPath() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    withData: true, // not sure what this entails!
  );

  if ((result != null) && result.files.single.path != null) {
    return result.files.single.path!;
  }
  return null;
}

Future<void> setupSudachiDic({reset = false}) async {
  // this is just the path to the config, not the real dic
  // the config json should have the real path within it
  String? configPath;

  // check for previous stored path
  if (reset) {
    configPath = await pickFileAbsPath();
  } else {
    final prefs = await SharedPreferences.getInstance();
    configPath = prefs.get("sudachi_config") as String;
  }

  if (configPath == null) {
    print("Invalid sudachi config.json path!");
  }
  print("Recieved path : ${configPath}");
  initTokenizer(configPath: configPath!);

  // save the path to use
  final prefs = await SharedPreferences.getInstance();
  prefs.setString("sudachi_config", configPath);

  // final appDirectory = getApplicationDocumentsDirectory();
}

Future<void> setupJMdict({reset = false}) async {
  // this is just the path to the config, not the real dic
  // the config json should have the real path within it
  String? configPath;

  // check for previous stored path
  if (reset) {
    configPath = await pickFileAbsPath();
  } else {
    final prefs = await SharedPreferences.getInstance();
    configPath = prefs.get("JMDict") as String;
  }

  if (configPath == null) {
    print("JMDICT path error!");
  }
  print("Recieved path : ${configPath}");

  // save the path to use
  final prefs = await SharedPreferences.getInstance();
  prefs.setString("jmdict", configPath!);

  // final appDirectory = getApplicationDocumentsDirectory();
}

Future<void> setupKanjiDict() async {}
Future<void> setupNameDict() async {}
