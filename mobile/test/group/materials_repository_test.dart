import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/features/materials/data/group_material.dart';
import 'package:studyplan/features/materials/data/materials_repository.dart';

import 'group_test_utils.dart';

Map<String, String> _fields(RequestOptions options) => {
      for (final f in (options.data as FormData).fields) f.key: f.value,
    };

void main() {
  group('MaterialsRepository.subjectCodeFor', () {
    test('makes a short lower-case slug', () {
      expect(
        MaterialsRepository.subjectCodeFor('Introduction to Programming'),
        'introduction-to-programming',
      );
      expect(
        MaterialsRepository.subjectCodeFor('  Базы данных (лаб.) '),
        'базы-данных-лаб',
      );
    });

    test('never exceeds 32 characters or ends with a dash', () {
      final code = MaterialsRepository.subjectCodeFor(
        'Information and Communication Technologies in Modern Society',
      );
      expect(code.length, lessThanOrEqualTo(32));
      expect(code.endsWith('-'), isFalse);
      expect(code, startsWith('information-and-communication'));
    });

    test('never collides with the no-subject marker or is empty', () {
      expect(
        MaterialsRepository.subjectCodeFor('None'),
        isNot(GroupMaterial.noSubjectCode),
      );
      expect(MaterialsRepository.subjectCodeFor('!!!'), isNotEmpty);
    });
  });

  test('upload sends a short code and the title cut to 120 chars', () async {
    late Map<String, String> sent;
    final api = fakeApi({
      'POST /materials/upload': (o) {
        sent = _fields(o);
        return {'ok': true};
      },
    });
    final longTitle = 'Information and Communication Technologies ' * 4;

    await MaterialsRepository(api).upload(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'a.pdf',
      title: 'Lecture 1',
      subjectTitle: longTitle,
    );

    expect(sent['subject_code']!.length, lessThanOrEqualTo(32));
    expect(sent['subject_code'], startsWith('information-and'));
    expect(sent['subject_title']!.length, lessThanOrEqualTo(120));
    expect(longTitle.trim(), startsWith(sent['subject_title']!));
  });

  test('upload without a subject sends the no-subject marker', () async {
    late Map<String, String> sent;
    final api = fakeApi({
      'POST /materials/upload': (o) {
        sent = _fields(o);
        return {'ok': true};
      },
    });

    await MaterialsRepository(api).upload(
      bytes: Uint8List.fromList([1]),
      fileName: 'a.pdf',
      title: 'Notes',
    );

    expect(sent['subject_code'], GroupMaterial.noSubjectCode);
    expect(sent['subject_title'], '-');
  });
}
