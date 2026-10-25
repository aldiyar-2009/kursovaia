import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/utils/file_download_helper.dart';
import 'package:studyplan/features/files/data/models/course_file_model.dart';

/// Stores files the user added on this device. Only real user files are
/// listed; there is no built-in sample content.
class FilesRepository {
  static final FilesRepository _instance = FilesRepository._internal();
  factory FilesRepository() => _instance;
  FilesRepository._internal();

  static const String _storageKey = 'aitu_local_uploaded_course_files_v1';

  final Map<String, Uint8List> _fileBytesCache = {};
  bool _initialized = false;
  final List<CourseFile> _userUploadedFiles = [];

  Future<void> _ensureLoaded() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey);
      if (raw != null) {
        _userUploadedFiles.clear();
        for (final item in raw) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            _userUploadedFiles.add(CourseFile.fromJson(map));
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _userUploadedFiles.map((f) => jsonEncode(f.toJson())).toList();
      await prefs.setStringList(_storageKey, list);
    } catch (_) {}
  }

  Future<List<CourseFile>> getMaterials({String? subjectCode, String? category}) async {
    await _ensureLoaded();

    var result = List<CourseFile>.of(_userUploadedFiles);
    if (subjectCode != null && subjectCode != 'all') {
      result = result.where((f) => f.subjectCode == subjectCode).toList();
    }
    if (category != null && category != 'all') {
      result = result.where((f) => f.category == category).toList();
    }
    return result;
  }

  Future<CourseFile> uploadMaterialLocally({
    required String title,
    required String subjectCode,
    required String subjectTitle,
    required String category,
    String? description,
    required String fileName,
    required int fileSize,
    Uint8List? fileBytes,
  }) async {
    await _ensureLoaded();

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}_${_userUploadedFiles.length + 1}';

    final localFile = CourseFile(
      id: id,
      title: title,
      subjectCode: subjectCode,
      subjectTitle: subjectTitle,
      description: description,
      fileName: fileName,
      fileSize: fileSize > 0 ? fileSize : (fileBytes?.length ?? 0),
      fileType: ext,
      category: category,
      uploaderName: 'Вы',
      createdAt: DateTime.now(),
      isLocal: true,
    );

    if (fileBytes != null) {
      _fileBytesCache[id] = fileBytes;
    }

    _userUploadedFiles.insert(0, localFile);
    await _saveToStorage();

    return localFile;
  }

  Future<bool> deleteMaterial(String id) async {
    await _ensureLoaded();
    _userUploadedFiles.removeWhere((f) => f.id == id);
    _fileBytesCache.remove(id);
    await _saveToStorage();
    return true;
  }

  /// Saves the file's real bytes to the device / browser.
  /// Returns false when the file contents are not available on this device.
  Future<bool> downloadOrOpenFile(CourseFile file) async {
    final bytes = _fileBytesCache[file.id];
    if (bytes == null || bytes.isEmpty) return false;
    try {
      downloadBytesWeb(bytes, file.fileName);
      return true;
    } catch (_) {
      return false;
    }
  }
}
