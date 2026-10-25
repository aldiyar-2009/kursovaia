import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/files/data/models/course_file_model.dart';
import 'package:studyplan/features/files/data/services/files_repository.dart';
import 'package:studyplan/features/grades/data/services/aitu_data_service.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final _repository = FilesRepository();
  final _dataService = AituDataService();

  List<CourseFile> _files = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedSubject = 'all';
  String _selectedCategory = 'all';

  final List<Map<String, String>> _subjects = [
    {'code': 'all', 'title': 'Все предметы'},
    {'code': 'py', 'title': 'Programming'},
    {'code': 'math', 'title': 'Calculus 1'},
    {'code': 'ict', 'title': 'ICT & Networks'},
    {'code': 'eng', 'title': 'English for IT'},
    {'code': 'hist', 'title': 'History of KZ'},
  ];

  final List<Map<String, String>> _categories = [
    {'code': 'all', 'title': 'Все типы'},
    {'code': 'syllabus', 'title': 'Силлабусы'},
    {'code': 'lecture', 'title': 'Лекции'},
    {'code': 'lab', 'title': 'Лабораторные'},
    {'code': 'assignment', 'title': 'Задания / Шпаргалки'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final list = await _repository.getMaterials(
      subjectCode: _selectedSubject,
      category: _selectedCategory,
    );
    if (!mounted) return;
    setState(() {
      _files = list;
      _isLoading = false;
    });
  }

  List<CourseFile> get _filteredFiles {
    if (_searchQuery.isEmpty) return _files;
    final q = _searchQuery.toLowerCase();
    return _files.where((f) =>
        f.title.toLowerCase().contains(q) ||
        f.fileName.toLowerCase().contains(q) ||
        f.subjectTitle.toLowerCase().contains(q) ||
        (f.description ?? '').toLowerCase().contains(q)).toList();
  }

  Future<void> _pickAndUploadDirectly() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;
      final picked = files.first;

      final bytes = await picked.readAsBytes();
      final size = (await picked.length()) ?? bytes.length;

      if (!mounted) return;
      _showUploadModalWithFile(
        initialFileName: picked.name,
        initialFileSize: size,
        initialBytes: bytes,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('Ошибка выбора файла: $e'),
        ),
      );
    }
  }

  void _showUploadModalWithFile({
    String? initialFileName,
    int? initialFileSize,
    Uint8List? initialBytes,
  }) {
    final titleController = TextEditingController(
      text: initialFileName != null
          ? initialFileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
          : '',
    );
    final descController = TextEditingController();
    
    String chosenSubject = _selectedSubject != 'all' ? _selectedSubject : 'py';
    String chosenCategory = _selectedCategory != 'all' ? _selectedCategory : 'lab';
    
    String currentFileName = initialFileName ?? '';
    int currentFileSize = initialFileSize ?? 0;
    Uint8List? currentBytes = initialBytes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final hasFile = currentFileName.isNotEmpty;
          final ext = currentFileName.contains('.')
              ? currentFileName.split('.').last.toUpperCase()
              : 'FILE';

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.plate(AppColors.accentCyan, 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: AppColors.accentCyan, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Загрузка документа',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Сохраняется локально на вашем устройстве',
                        style: TextStyle(fontSize: 11, color: AppColors.accentCyan),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File selection dropzone
                    InkWell(
                      onTap: () async {
                        try {
                          final files = await FilePicker.pickFiles();
                          if (files.isNotEmpty) {
                            final f = files.first;
                            final b = await f.readAsBytes();
                            final s = (await f.length()) ?? b.length;
                            setModalState(() {
                              currentFileName = f.name;
                              currentFileSize = s;
                              currentBytes = b;
                              if (titleController.text.trim().isEmpty) {
                                titleController.text = f.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                              }
                            });
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Не удалось выбрать файл: $e')),
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: hasFile
                              ? AppColors.plate(AppColors.accentCyan, 0.08)
                              : AppColors.elevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasFile ? AppColors.accentCyan : AppColors.border,
                            width: hasFile ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: hasFile ? AppColors.accentCyan : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                hasFile ? Icons.insert_drive_file_rounded : Icons.file_upload_outlined,
                                color: hasFile ? Colors.black : AppColors.accentCyan,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasFile ? currentFileName : 'Нажмите, чтобы выбрать файл с устройства',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: hasFile ? AppColors.textPrimary : AppColors.accentCyan,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasFile
                                        ? '$ext · ${(currentFileSize / 1024).toStringAsFixed(1)} KB · Готов к сохранению'
                                        : 'PDF, DOCX, PPTX, TXT, ZIP, PY, изображения и др.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: hasFile ? AppColors.accentCyan : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                final files = await FilePicker.pickFiles();
                                if (files.isNotEmpty) {
                                  final f = files.first;
                                  final b = await f.readAsBytes();
                                  final s = (await f.length()) ?? b.length;
                                  setModalState(() {
                                    currentFileName = f.name;
                                    currentFileSize = s;
                                    currentBytes = b;
                                    if (titleController.text.trim().isEmpty) {
                                      titleController.text = f.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                                    }
                                  });
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              child: Text(hasFile ? 'Заменить' : 'Обзор', style: const TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Название материала / темы', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.elevated,
                        hintText: 'например: Лабораторная работа №3 или Конспект лекций',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Дисциплина', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.elevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: chosenSubject,
                                    isExpanded: true,
                                    dropdownColor: AppColors.surface,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'py', child: Text('Programming')),
                                      DropdownMenuItem(value: 'math', child: Text('Calculus 1')),
                                      DropdownMenuItem(value: 'ict', child: Text('ICT Networks')),
                                      DropdownMenuItem(value: 'eng', child: Text('English for IT')),
                                      DropdownMenuItem(value: 'hist', child: Text('History of KZ')),
                                    ],
                                    onChanged: (v) => setModalState(() => chosenSubject = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Тип документа', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.elevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: chosenCategory,
                                    isExpanded: true,
                                    dropdownColor: AppColors.surface,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'lab', child: Text('Лабораторная')),
                                      DropdownMenuItem(value: 'lecture', child: Text('Лекция')),
                                      DropdownMenuItem(value: 'syllabus', child: Text('Силлабус')),
                                      DropdownMenuItem(value: 'assignment', child: Text('Шпаргалка / Задание')),
                                    ],
                                    onChanged: (v) => setModalState(() => chosenCategory = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text('Примечание (необязательно)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.elevated,
                        hintText: 'Комментарий к документу, ссылка на решение или вопросы к сдаче...',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Укажите название материала')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);

                  final subjectTitles = {
                    'py': 'Introduction to Programming',
                    'math': 'Calculus 1',
                    'ict': 'Information & Comm. Technologies',
                    'eng': 'Foreign Language',
                    'hist': 'History of Kazakhstan',
                  };

                  final finalFileName = currentFileName.isNotEmpty
                      ? currentFileName
                      : '${title.replaceAll(' ', '_')}.pdf';
                  final finalFileSize = currentFileSize > 0 ? currentFileSize : 1024 * 720;

                  final messenger = ScaffoldMessenger.of(context);

                  await _repository.uploadMaterialLocally(
                    title: title,
                    subjectCode: chosenSubject,
                    subjectTitle: subjectTitles[chosenSubject] ?? 'Дисциплина',
                    category: chosenCategory,
                    description: descController.text.trim().isNotEmpty
                        ? descController.text.trim()
                        : null,
                    fileName: finalFileName,
                    fileSize: finalFileSize,
                    fileBytes: currentBytes,
                  );

                  if (!mounted) return;
                  await _loadFiles();

                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.surface,
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.accentCyan, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Файл «$finalFileName» успешно сохранён локально на устройстве!'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Сохранить локально'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUploadDialog() {
    _showUploadModalWithFile();
  }

  Color _getFileTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'docx':
      case 'doc':
        return const Color(0xFF3B82F6);
      case 'pptx':
      case 'ppt':
        return const Color(0xFFF97316);
      case 'zip':
      case 'rar':
      case '7z':
        return const Color(0xFFA855F7);
      case 'py':
      case 'js':
      case 'dart':
      case 'cpp':
      case 'java':
        return const Color(0xFF10B981);
      default:
        return AppColors.accentCyan;
    }
  }

  IconData _getFileTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'docx':
      case 'doc':
        return Icons.description_rounded;
      case 'pptx':
      case 'ppt':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'py':
      case 'js':
      case 'dart':
      case 'cpp':
      case 'java':
        return Icons.code_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFiles;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _buildHeaderRow(),
          const SizedBox(height: 16),
          _buildStorageStats(),
          const SizedBox(height: 16),
          _buildSearchAndFilters(),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              ),
            )
          else if (filtered.isEmpty)
            _buildEmptyState()
          else
            ...filtered.map(_buildFileCard),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'УЧЕБНЫЕ МАТЕРИАЛЫ AITU',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.accentCyan),
            ),
            const SizedBox(height: 2),
            const Text(
              'Файлы и документы',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Text(
              'Группа ${_dataService.currentGroup} · Локальное хранилище на устройстве',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickAndUploadDirectly,
              icon: const Icon(Icons.file_open_rounded, size: 16),
              label: const Text('Выбрать файл', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentCyan,
                side: const BorderSide(color: AppColors.accentCyan),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _showUploadDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Добавить', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageStats() {
    final totalCount = _files.length;
    final totalBytes = _files.fold<int>(0, (sum, f) => sum + f.fileSize);
    final formattedTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final localCount = _files.where((f) => f.isLocal).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.plate(AppColors.accentCyan, 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.folder_shared_rounded, color: AppColors.accentCyan, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Локальное хранилище документов', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('$formattedTotal MB сохранено локально', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentCyan)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (totalBytes / (50 * 1024 * 1024)).clamp(0.05, 1.0),
                    backgroundColor: AppColors.elevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Всего файлов: $totalCount · Локально сохранено: $localCount · Файлы не перегружают БД',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Поиск по названию файла, предмету или ключевым словам...',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentCyan)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 12),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _subjects.map((s) {
              final isSel = _selectedSubject == s['code'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(s['title']!),
                  selected: isSel,
                  onSelected: (_) {
                    setState(() => _selectedSubject = s['code']!);
                    _loadFiles();
                  },
                  selectedColor: AppColors.accentCyan,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? Colors.black : AppColors.textSecondary,
                  ),
                  side: BorderSide(color: isSel ? AppColors.accentCyan : AppColors.border),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((c) {
              final isSel = _selectedCategory == c['code'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(c['title']!),
                  selected: isSel,
                  onSelected: (_) {
                    setState(() => _selectedCategory = c['code']!);
                    _loadFiles();
                  },
                  selectedColor: AppColors.accent.withValues(alpha: 0.25),
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? AppColors.accent : AppColors.textMuted,
                  ),
                  side: BorderSide(color: isSel ? AppColors.accent : AppColors.border),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(CourseFile file) {
    final typeColor = _getFileTypeColor(file.fileType);
    final iconData = _getFileTypeIcon(file.fileType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: file.isLocal ? AppColors.accentCyan.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                ),
                child: Icon(iconData, color: typeColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            file.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (file.isLocal) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.plate(AppColors.accentCyan, 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.devices_rounded, size: 11, color: AppColors.accentCyan),
                                SizedBox(width: 3),
                                Text(
                                  'Локальный',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentCyan),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.elevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            file.subjectTitle,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accentCyan),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.plate(typeColor, 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            file.categoryLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: typeColor),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          file.formattedSize,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (file.description != null && file.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              file.description!,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_open_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    file.fileName,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              Row(
                children: [
                  if (file.isLocal) ...[
                    IconButton(
                      tooltip: 'Удалить из локального хранилища',
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await _repository.deleteMaterial(file.id);
                        if (!mounted) return;
                        _loadFiles();
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.surface,
                            content: Text('Файл «${file.fileName}» удалён из памяти устройства'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: 'aitu://files/${file.id}/${file.fileName}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.surface,
                          content: Text('Локальная ссылка скопирована в буфер обмена'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.link_rounded, size: 14),
                    label: const Text('Ссылка', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await _repository.downloadOrOpenFile(file);
                      if (ok) {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.surface,
                            content: Text('Файл «${file.fileName}» успешно скачан на ваше устройство!'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Скачать', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text(
              'Файлы не найдены',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Выберите документ с вашего компьютера или телефона для сохранения.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickAndUploadDirectly,
              icon: const Icon(Icons.file_upload_rounded, size: 16),
              label: const Text('Выбрать файл с устройства'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
