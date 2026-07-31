import 'dart:convert';
import 'dart:io';

class LocalJsonStore {
  LocalJsonStore({required String fileName, File? file})
      : _file = file ?? File(_defaultFilePath(fileName));

  final File _file;

  Future<Object?> read() async {
    try {
      if (!await _file.exists()) return null;
      return jsonDecode(await _file.readAsString());
    } catch (error) {
      throw LocalStorageException('无法读取本地数据。', error);
    }
  }

  Future<void> write(Object value) async {
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(jsonEncode(value), flush: true);
    } catch (error) {
      throw LocalStorageException('无法保存本地数据。', error);
    }
  }

  static String _defaultFilePath(String fileName) {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return '$appData${Platform.pathSeparator}PaperFlow${Platform.pathSeparator}$fileName';
      }
    }
    if (Platform.isAndroid) {
      final appFile =
          Directory.systemTemp.parent.uri.resolve('files/PaperFlow/$fileName');
      return File.fromUri(appFile).path;
    }
    return '${Directory.systemTemp.path}${Platform.pathSeparator}PaperFlow${Platform.pathSeparator}$fileName';
  }
}

class LocalStorageException implements Exception {
  const LocalStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
