import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/utils/file_download_helper.dart';
import 'package:studyplan/features/files/data/models/course_file_model.dart';

class FilesRepository {
  static final FilesRepository _instance = FilesRepository._internal();
  factory FilesRepository() => _instance;
  FilesRepository._internal();

  static const String _storageKey = 'aitu_local_uploaded_course_files_v1';

  final Map<String, Uint8List> _fileBytesCache = {};
  bool _initialized = false;
  final List<CourseFile> _userUploadedFiles = [];

  final List<CourseFile> _seedFiles = [
    CourseFile(
      id: 'seed_1',
      title: 'Силлабус и темы лабораторных работ (Python & Algorithms)',
      subjectCode: 'py',
      subjectTitle: 'Introduction to Programming',
      description: 'Официальный силлабус на 1 семестр. Требования к оформлению отчетов и критерии оценивания.',
      fileName: 'CS101_Programming_Syllabus_2026.pdf',
      fileSize: 2450000,
      fileType: 'pdf',
      category: 'syllabus',
      uploaderName: 'Староста',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      isLocal: false,
    ),
    CourseFile(
      id: 'seed_2',
      title: 'Методические указания к Лабораторной работе №3: Работа с файлами и JSON',
      subjectCode: 'py',
      subjectTitle: 'Introduction to Programming',
      description: 'Задания по чтению/записи структурированных данных, тесты и примеры входных файлов.',
      fileName: 'Lab3_File_IO_JSON_Guidelines.pdf',
      fileSize: 1850000,
      fileType: 'pdf',
      category: 'lab',
      uploaderName: 'Староста',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      isLocal: false,
    ),
    CourseFile(
      id: 'seed_3',
      title: 'Лекция 4–6: Пределы последовательностей и функций, производные',
      subjectCode: 'math',
      subjectTitle: 'Calculus 1',
      description: 'Конспект лекций кафедры высшей математики с разобранными примерами.',
      fileName: 'Calculus1_Lectures_Limits_Derivatives.pdf',
      fileSize: 4200000,
      fileType: 'pdf',
      category: 'lecture',
      uploaderName: 'Староста',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      isLocal: false,
    ),
    CourseFile(
      id: 'seed_4',
      title: 'Таблица производных и эквивалентных бесконечно малых (шпаргалка)',
      subjectCode: 'math',
      subjectTitle: 'Calculus 1',
      description: 'Удобная таблица формул для решения типовых расчетов и подготовки к Midterm.',
      fileName: 'Calculus_Formulas_CheatSheet.pdf',
      fileSize: 780000,
      fileType: 'pdf',
      category: 'assignment',
      uploaderName: 'Студент',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isLocal: false,
    ),
    CourseFile(
      id: 'seed_5',
      title: 'Сетевая архитектура OSI и TCP/IP: Лабораторный практикум Wireshark',
      subjectCode: 'ict',
      subjectTitle: 'Information & Comm. Technologies',
      description: 'Пошаговое руководство по перехвату пакетов и анализу трафика в локальной сети.',
      fileName: 'ICT_Lab_Wireshark_Protocol_Analysis.pdf',
      fileSize: 3100000,
      fileType: 'pdf',
      category: 'lab',
      uploaderName: 'Староста',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      isLocal: false,
    ),
    CourseFile(
      id: 'seed_6',
      title: 'Academic Writing & Tech Presentation Slides Template',
      subjectCode: 'eng',
      subjectTitle: 'Foreign Language',
      description: 'Шаблон презентации для защиты проектных работ и структура эссе.',
      fileName: 'Tech_Presentation_Template_AITU.pptx',
      fileSize: 1950000,
      fileType: 'pptx',
      category: 'assignment',
      uploaderName: 'Студент',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      isLocal: false,
    ),
    CourseFile(
      id: 'seed_7',
      title: 'Вопросы и тезисы для подготовки к рубежному контролю (РК-1)',
      subjectCode: 'hist',
      subjectTitle: 'History of Kazakhstan',
      description: 'Основные даты, события и терминология для подготовки к тестированию.',
      fileName: 'History_RK1_Exam_Preparation.pdf',
      fileSize: 1100000,
      fileType: 'pdf',
      category: 'assignment',
      uploaderName: 'Староста',
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      isLocal: false,
    ),
  ];

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

    // User-uploaded files first, followed by default syllabus files
    final all = <CourseFile>[..._userUploadedFiles, ..._seedFiles];

    var result = all;
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

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'pdf';
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}_${_userUploadedFiles.length + 1}';

    final localFile = CourseFile(
      id: id,
      title: title,
      subjectCode: subjectCode,
      subjectTitle: subjectTitle,
      description: description,
      fileName: fileName,
      fileSize: fileSize > 0 ? fileSize : 512000,
      fileType: ext,
      category: category,
      uploaderName: 'Студент (Локально)',
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

  /// Downloads or opens the file locally in the client browser / device.
  Future<bool> downloadOrOpenFile(CourseFile file) async {
    try {
      Uint8List? bytes = _fileBytesCache[file.id];

      if (bytes == null || bytes.isEmpty) {
        // Generate authentic study notes content if this was a seeded or text material
        final buffer = StringBuffer();
        buffer.writeln('========================================================');
        buffer.writeln('Astana IT University - Учебный Репозиторий AITU');
        buffer.writeln('========================================================\n');
        buffer.writeln('Название документа: ${file.title}');
        buffer.writeln('Дисциплина:         ${file.subjectTitle} (${file.subjectCode.toUpperCase()})');
        buffer.writeln('Категория:          ${file.categoryLabel}');
        buffer.writeln('Имя файла:          ${file.fileName}');
        buffer.writeln('Загрузил:           ${file.uploaderName}');
        buffer.writeln('Дата:               ${file.createdAt.toIso8601String()}\n');
        if (file.description != null && file.description!.isNotEmpty) {
          buffer.writeln('Описание:\n${file.description}\n');
        }
        buffer.writeln('--------------------------------------------------------');
        buffer.writeln('Документ успешно загружен из локального хранилища устройства.');
        buffer.writeln('StudyPlan Mobile / Web - Astana IT University.');
        buffer.writeln('========================================================');

        bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      }

      // Download file on Web platform
      downloadBytesWeb(bytes, file.fileName);
      return true;
    } catch (_) {
      return false;
    }
  }
}
