import 'package:uuid/uuid.dart';

abstract final class UuidUtil {
  static const _uuid = Uuid();

  static String generate() => _uuid.v4();
}
