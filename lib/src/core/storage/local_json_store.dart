import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LocalJsonStore {
  LocalJsonStore({required String fileName, File? file})
      : _file = file ?? File(_defaultFilePath(fileName));

  static final Map<String, Future<void>> _operationTails = {};

  final File _file;

  Future<T> transaction<T>(
    Future<T> Function(LocalJsonStoreTransaction transaction) operation,
  ) {
    final absolutePath = _file.absolute.path;
    final path = Platform.isWindows ? absolutePath.toLowerCase() : absolutePath;
    final previous = _operationTails[path] ?? Future<void>.value();
    final result = previous.then(
      (_) => operation(LocalJsonStoreTransaction._(_file)),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _operationTails[path] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_operationTails[path], tail)) {
          _operationTails.remove(path);
        }
      }),
    );
    return result;
  }

  Future<Object?> read() => transaction((transaction) => transaction.read());

  Future<void> write(Object value) {
    return transaction((transaction) => transaction.write(value));
  }

  Future<int> sizeInBytes() {
    return transaction((transaction) => transaction.sizeInBytes());
  }

  Future<void> clear() {
    return transaction((transaction) => transaction.clear());
  }

  Future<String?> quarantineCorruptFile() {
    return transaction(
      (transaction) => transaction.quarantineCorruptFile(),
    );
  }

  static String _defaultFilePath(String fileName) {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return '$appData${Platform.pathSeparator}Spark${Platform.pathSeparator}$fileName';
      }
    }
    if (Platform.isAndroid) {
      final appFile =
          Directory.systemTemp.parent.uri.resolve('files/Spark/$fileName');
      return File.fromUri(appFile).path;
    }
    return '${Directory.systemTemp.path}${Platform.pathSeparator}Spark${Platform.pathSeparator}$fileName';
  }
}

class LocalJsonStoreTransaction {
  LocalJsonStoreTransaction._(this._file);

  static int _temporaryFileSequence = 0;

  final File _file;

  File get _recoveryFile => File('${_file.path}.previous');

  Future<Object?> read() async {
    await _recoverInterruptedReplacement();
    final exists = await _storageOperation(
      _file.exists,
      message: '无法检查本地数据。',
    );
    if (!exists) return null;
    final source = await _storageOperation(
      _file.readAsString,
      message: '无法读取本地数据。',
    );
    try {
      return jsonDecode(source);
    } on FormatException catch (error) {
      throw LocalJsonDecodingException('本地数据不是有效的 JSON。', error);
    }
  }

  Future<void> write(Object value) async {
    final encoded = jsonEncode(value);
    await _storageOperation(
      () => _file.parent.create(recursive: true),
      message: '无法创建本地数据目录。',
    );
    final temporary = File(
      '${_file.path}.tmp.$pid.${DateTime.now().toUtc().microsecondsSinceEpoch}.${_temporaryFileSequence++}',
    );
    try {
      await _storageOperation(
        () => temporary.writeAsString(encoded, flush: true),
        message: '无法写入本地数据临时文件。',
      );
      await _replaceWith(temporary);
    } finally {
      await _deleteBestEffort(temporary);
    }
  }

  Future<int> sizeInBytes() async {
    await _recoverInterruptedReplacement();
    final files = await _managedFiles();
    final sizes = await Future.wait<int>(
      files.map(
        (file) => _storageOperation(
          file.length,
          message: '无法统计本地数据占用。',
        ),
      ),
    );
    return sizes.fold<int>(0, (total, size) => total + size);
  }

  Future<List<File>> _managedFiles() async {
    final directoryExists = await _storageOperation(
      _file.parent.exists,
      message: '无法检查本地数据目录。',
    );
    if (!directoryExists) return const [];
    final targetName = _fileName(_file.path);
    return _storageOperation(
      () async {
        final files = <File>[];
        await for (final entity in _file.parent.list(followLinks: false)) {
          if (entity is! File) continue;
          final candidateName = _fileName(entity.path);
          if (_isManagedFileName(candidateName, targetName)) {
            files.add(entity);
          }
        }
        return files;
      },
      message: '无法统计本地数据占用。',
    );
  }

  Future<void> clear() async {
    final files = await _managedFiles();
    for (final file in files) {
      await _storageOperation(
        file.delete,
        message: '无法清除本地数据。',
      );
    }
  }

  static bool _isManagedFileName(String candidate, String target) {
    if (Platform.isWindows) {
      candidate = candidate.toLowerCase();
      target = target.toLowerCase();
    }
    return candidate == target ||
        candidate == '$target.previous' ||
        candidate.startsWith('$target.corrupt.') ||
        candidate.startsWith('$target.tmp.');
  }

  static String _fileName(String path) {
    final separatorIndex = path.lastIndexOf(Platform.pathSeparator);
    return separatorIndex < 0 ? path : path.substring(separatorIndex + 1);
  }

  Future<String?> quarantineCorruptFile() async {
    final exists = await _storageOperation(
      _file.exists,
      message: '无法检查损坏的本地数据。',
    );
    if (!exists) return null;
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final backup = File('${_file.path}.corrupt.$timestamp');
    await _storageOperation(
      () => _file.rename(backup.path),
      message: '无法隔离损坏的本地数据。',
    );
    return backup.path;
  }

  Future<void> _replaceWith(File temporary) async {
    final targetExists = await _storageOperation(
      _file.exists,
      message: '无法检查本地数据。',
    );
    if (!targetExists) {
      await _storageOperation(
        () => temporary.rename(_file.path),
        message: '无法保存本地数据。',
      );
      return;
    }

    if (!Platform.isWindows) {
      await _storageOperation(
        () => temporary.rename(_file.path),
        message: '无法保存本地数据。',
      );
      return;
    }

    if (await _recoveryFile.exists()) {
      await _storageOperation(
        _recoveryFile.delete,
        message: '无法清理本地数据恢复文件。',
      );
    }
    await _storageOperation(
      () => _file.rename(_recoveryFile.path),
      message: '无法准备替换本地数据。',
    );
    try {
      await _storageOperation(
        () => temporary.rename(_file.path),
        message: '无法保存本地数据。',
      );
    } catch (_) {
      if (!await _file.exists() && await _recoveryFile.exists()) {
        await _storageOperation(
          () => _recoveryFile.rename(_file.path),
          message: '无法恢复原有本地数据。',
        );
      }
      rethrow;
    }
    await _deleteBestEffort(_recoveryFile);
  }

  Future<void> _recoverInterruptedReplacement() async {
    final targetExists = await _storageOperation(
      _file.exists,
      message: '无法检查本地数据。',
    );
    final recoveryExists = await _storageOperation(
      _recoveryFile.exists,
      message: '无法检查本地数据恢复文件。',
    );
    if (!targetExists && recoveryExists) {
      await _storageOperation(
        () => _recoveryFile.rename(_file.path),
        message: '无法恢复中断写入前的本地数据。',
      );
    } else if (targetExists && recoveryExists) {
      await _deleteBestEffort(_recoveryFile);
    }
  }

  static Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The target data is already committed; stale cleanup files are harmless.
    }
  }

  static Future<T> _storageOperation<T>(
    Future<T> Function() operation, {
    required String message,
  }) async {
    try {
      return await operation();
    } on FileSystemException catch (error) {
      throw LocalStorageException(message, error);
    }
  }
}

class LocalStorageException implements Exception {
  const LocalStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class LocalJsonDecodingException implements Exception {
  const LocalJsonDecodingException(this.message, this.cause);

  final String message;
  final FormatException cause;

  @override
  String toString() => message;
}
