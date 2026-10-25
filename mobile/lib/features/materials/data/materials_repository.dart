import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/features/materials/data/group_material.dart';

enum MaterialsFailure { offline, tooLarge, forbidden, generic }

class MaterialsException implements Exception {
  final MaterialsFailure failure;
  const MaterialsException(this.failure);

  factory MaterialsException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) return const MaterialsException(MaterialsFailure.offline);
    if (status == 413) return const MaterialsException(MaterialsFailure.tooLarge);
    if (status == 403) return const MaterialsException(MaterialsFailure.forbidden);
    return const MaterialsException(MaterialsFailure.generic);
  }

  @override
  String toString() => 'MaterialsException($failure)';
}

/// Group materials over REST (`/materials`, `/files/:name`). The last list
/// is cached per group in SharedPreferences for offline viewing.
class MaterialsRepository {
  final ApiClient apiClient;

  MaterialsRepository(this.apiClient);

  static String _cacheKey(String groupId) => 'group_materials_cache_$groupId';

  Future<List<GroupMaterial>?> loadCached(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(groupId));
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(GroupMaterial.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(String groupId, List<GroupMaterial> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey(groupId),
      jsonEncode(items.map((m) => m.toJson()).toList()),
    );
  }

  Future<List<GroupMaterial>> fetch(String groupId) async {
    try {
      final res = await apiClient.dio.get<dynamic>('/materials');
      final data = res.data as Map<String, dynamic>;
      final items = ((data['materials'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GroupMaterial.fromJson)
          .toList();
      await _saveCache(groupId, items);
      return items;
    } on DioException catch (e) {
      throw MaterialsException.fromDio(e);
    }
  }

  /// Max length of `course_materials.subject_code` on the server.
  static const subjectCodeMaxLength = 32;

  /// Max length of `course_materials.subject_title` on the server.
  static const subjectTitleMaxLength = 120;

  /// Short, stable code for a subject title: lower-case letters and digits
  /// joined by `-`, at most [subjectCodeMaxLength] characters. Never equal to
  /// [GroupMaterial.noSubjectCode], which marks a material without subject.
  static String subjectCodeFor(String subjectTitle) {
    var code = subjectTitle
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (code.length > subjectCodeMaxLength) {
      code = code
          .substring(0, subjectCodeMaxLength)
          .replaceAll(RegExp(r'-+$'), '');
    }
    if (code.isEmpty) return 'subject';
    if (code == GroupMaterial.noSubjectCode) return 'subject-$code';
    return code;
  }

  /// The subject title cut to [subjectTitleMaxLength] characters.
  static String subjectTitleFor(String subjectTitle) {
    final title = subjectTitle.trim();
    return title.length <= subjectTitleMaxLength
        ? title
        : title.substring(0, subjectTitleMaxLength).trimRight();
  }

  Future<void> upload({
    required Uint8List bytes,
    required String fileName,
    required String title,
    String? subjectTitle,
  }) async {
    final subject = subjectTitle?.trim();
    final hasSubject = subject != null && subject.isNotEmpty;
    final form = FormData.fromMap({
      'title': title.trim(),
      'subject_code':
          hasSubject ? subjectCodeFor(subject) : GroupMaterial.noSubjectCode,
      // Never empty: the server replaces an empty subject with a default one.
      'subject_title': hasSubject ? subjectTitleFor(subject) : '-',
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    try {
      await apiClient.dio.post<dynamic>(
        '/materials/upload',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw MaterialsException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await apiClient.dio.delete<dynamic>('/materials/$id');
    } on DioException catch (e) {
      throw MaterialsException.fromDio(e);
    }
  }

  /// File contents from `/files/<name>` (requires the JWT and group
  /// membership).
  Future<Uint8List> download(GroupMaterial material) async {
    try {
      final res = await apiClient.dio.get<List<int>>(
        '/files/${Uri.encodeComponent(material.filePath)}',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw MaterialsException.fromDio(e);
    }
  }
}
