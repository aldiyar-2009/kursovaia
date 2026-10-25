class CourseFile {
  final String id;
  final String title;
  final String subjectCode;
  final String subjectTitle;
  final String? description;
  final String fileName;
  final int fileSize;
  final String fileType; // 'pdf', 'docx', 'pptx', 'zip', 'txt', 'py', etc.
  final String category; // 'syllabus', 'lecture', 'lab', 'assignment'
  final String uploaderName;
  final DateTime createdAt;
  final String? downloadUrl;
  final bool isLocal;

  const CourseFile({
    required this.id,
    required this.title,
    required this.subjectCode,
    required this.subjectTitle,
    this.description,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.category,
    required this.uploaderName,
    required this.createdAt,
    this.downloadUrl,
    this.isLocal = false,
  });

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get categoryLabel {
    switch (category) {
      case 'syllabus':
        return 'Силлабус';
      case 'lecture':
        return 'Лекция';
      case 'lab':
        return 'Лабораторная';
      case 'assignment':
        return 'Задание / Шпаргалка';
      default:
        return 'Материал';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject_code': subjectCode,
      'subject_title': subjectTitle,
      'description': description,
      'file_name': fileName,
      'file_size': fileSize,
      'file_type': fileType,
      'category': category,
      'uploader_name': uploaderName,
      'created_at': createdAt.millisecondsSinceEpoch,
      'download_url': downloadUrl,
      'is_local': isLocal,
    };
  }

  factory CourseFile.fromJson(Map<String, dynamic> json) {
    return CourseFile(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Учебный материал',
      subjectCode: json['subject_code'] ?? 'general',
      subjectTitle: json['subject_title'] ?? 'Дисциплина',
      description: json['description'],
      fileName: json['file_name'] ?? 'document.pdf',
      fileSize: (json['file_size'] as num?)?.toInt() ?? 1024 * 1024,
      fileType: (json['file_type'] ?? 'pdf').toString().toLowerCase(),
      category: json['category'] ?? 'lecture',
      uploaderName: json['uploader_name'] ?? 'Студент',
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['created_at'] as num).toInt())
          : DateTime.now(),
      downloadUrl: json['file_path'] != null
          ? '/api/files/${json['file_path']}'
          : json['download_url'],
      isLocal: json['is_local'] == true,
    );
  }
}
