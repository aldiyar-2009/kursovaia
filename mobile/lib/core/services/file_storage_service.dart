import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:studyplan/core/utils/uuid_util.dart';

class FileStorageService {
  static const String _subDir = 'app_docs/attachments';

  Future<Directory> _getAttachmentsDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(docsDir.path, _subDir));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
  }

  /// Copies an external file into the app's local sandbox attachments folder.
  /// Returns a record with the relative path, file size in bytes, and file name.
  Future<({String relativePath, int fileSize, String fileName})> saveFile(File sourceFile) async {
    final dir = await _getAttachmentsDir();
    final originalName = p.basename(sourceFile.path);
    final ext = p.extension(sourceFile.path);
    final uuidName = '${UuidUtil.generate()}$ext';
    final destination = File(p.join(dir.path, uuidName));

    await sourceFile.copy(destination.path);
    final size = await destination.length();

    // Store relative path: attachments/<uuid>.<ext>
    final relativePath = 'attachments/$uuidName';
    return (relativePath: relativePath, fileSize: size, fileName: originalName);
  }

  /// Resolves the absolute path from a stored relative path.
  Future<File> resolveFile(String relativePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final cleanRelative = relativePath.startsWith('attachments/')
        ? relativePath.substring('attachments/'.length)
        : relativePath;
    return File(p.join(docsDir.path, _subDir, cleanRelative));
  }
}
