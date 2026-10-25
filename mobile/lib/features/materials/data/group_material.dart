/// A file shared with the group (`course_materials` on the server).
class GroupMaterial {
  /// Sent as the subject when the uploader picked none; the server would
  /// otherwise substitute its own default subject.
  static const noSubjectCode = 'none';

  final String id;
  final String title;
  final String? subjectTitle;
  final String uploaderId;
  final String uploaderName;
  final String fileName;

  /// Stored file name, downloadable at `/files/<filePath>`.
  final String filePath;
  final int fileSize;
  final int createdAt;

  const GroupMaterial({
    required this.id,
    required this.title,
    required this.subjectTitle,
    required this.uploaderId,
    required this.uploaderName,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.createdAt,
  });

  factory GroupMaterial.fromJson(Map<String, dynamic> json) {
    final code = json['subject_code']?.toString();
    final subject = (json['subject_title'] as String?)?.trim();
    return GroupMaterial(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      subjectTitle: code == noSubjectCode || subject == null || subject.isEmpty
          ? null
          : subject,
      uploaderId: json['uploader_id']?.toString() ?? '',
      uploaderName: (json['uploader_name'] as String?)?.trim() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject_code': subjectTitle ?? noSubjectCode,
        'subject_title': subjectTitle ?? '',
        'uploader_id': uploaderId,
        'uploader_name': uploaderName,
        'file_name': fileName,
        'file_path': filePath,
        'file_size': fileSize,
        'created_at': createdAt,
      };
}
