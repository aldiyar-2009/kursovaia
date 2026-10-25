import {
  isDateStr,
  isEpochMs,
  isNonEmptyString,
  isTimeStr,
  isUuid,
  toBool,
  toNullableBool,
} from '../utils/validators.js';


const nullableUuid = (v) => v === null || v === undefined || isUuid(v);
const nullableStr = (max) => (v) => v === null || v === undefined || (typeof v === 'string' && v.length <= max);
const nullableDate = (v) => v === null || v === undefined || isDateStr(v);
const nullableEpoch = (v) => v === null || v === undefined || isEpochMs(v);
/** Moodle ids: non-negative 32-bit integers. */
const nullableLmsId = (v) => v === null || v === undefined || (Number.isInteger(v) && v >= 0 && v <= 2_147_483_647);
/** Grade on the 0..100 scale or null (no grade yet). */
const nullableScore = (v) => v === null || v === undefined || (typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 100);
const oneOfOrDefault = (values, v, fallback) => values.includes(v ?? fallback);

export const LESSON_TYPES = ['lecture', 'practice', 'lab'];
export const TASK_STATUSES = ['inbox', 'in_progress', 'completed'];
export const LMS_COURSE_SOURCES = ['lms', 'manual'];
export const LMS_CLASSIFICATIONS = ['inprogress', 'past', 'future'];
export const LMS_EVENT_TYPES = ['deadline', 'class', 'other'];
export const LMS_MATERIAL_TYPES = ['file', 'folder', 'url', 'page', 'other'];

export const SYNC_TABLES = {
  subjects: {
    columns: ['id', 'title', 'teacher_name', 'color_hex', 'is_deleted', 'updated_at'],
    booleans: ['is_deleted'],
    validate(r) {
      if (!isNonEmptyString(r.title, 160)) return 'title is required (<=160 chars)';
      if (!nullableStr(160)(r.teacher_name)) return 'teacher_name too long';
      if (!(r.color_hex == null || /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(r.color_hex))) return 'color_hex must be #RRGGBB';
      return null;
    },
  },
  lessons: {
    columns: [
      'id', 'subject_id', 'day_of_week', 'start_time', 'end_time', 'classroom', 'lesson_type', 'topic',
      'is_even_week', 'specific_date', 'valid_from', 'valid_to', 'is_cancelled', 'is_deleted', 'updated_at',
    ],
    booleans: ['is_cancelled', 'is_deleted'],
    nullableBooleans: ['is_even_week'],
    validate(r) {
      if (!isUuid(r.subject_id)) return 'subject_id must be a UUID';
      if (!(Number.isInteger(r.day_of_week) && r.day_of_week >= 1 && r.day_of_week <= 7)) return 'day_of_week must be 1..7';
      if (!isTimeStr(r.start_time) || !isTimeStr(r.end_time)) return 'start_time/end_time must be HH:mm';
      if (r.start_time >= r.end_time) return 'start_time must be before end_time';
      if (!LESSON_TYPES.includes(r.lesson_type ?? 'lecture')) return `lesson_type must be one of ${LESSON_TYPES.join(', ')}`;
      if (!nullableStr(64)(r.classroom) || !nullableStr(255)(r.topic)) return 'classroom/topic too long';
      if (!nullableDate(r.specific_date) || !nullableDate(r.valid_from) || !nullableDate(r.valid_to)) return 'dates must be YYYY-MM-DD';
      return null;
    },
  },
  tasks: {
    columns: [
      'id', 'group_id', 'subject_id', 'subject_title', 'title', 'description', 'due_date', 'priority', 'status',
      'is_group', 'source_message_id', 'source_task_id', 'is_deleted', 'updated_at',
    ],
    booleans: ['is_group', 'is_deleted'],
    validate(r) {
      if (!isNonEmptyString(r.title, 255)) return 'title is required (<=255 chars)';
      if (!(r.due_date == null || isEpochMs(r.due_date))) return 'due_date must be epoch ms';
      if (![1, 2, 3].includes(r.priority ?? 3)) return 'priority must be 1, 2 or 3';
      if (!TASK_STATUSES.includes(r.status ?? 'inbox')) return `status must be one of ${TASK_STATUSES.join(', ')}`;
      if (![r.subject_id, r.source_message_id, r.source_task_id, r.group_id].every(nullableUuid)) return 'invalid uuid reference';
      if (!nullableStr(20_000)(r.description)) return 'description too long';
      return null;
    },
  },
  subtasks: {
    columns: ['id', 'task_id', 'title', 'is_done', 'position', 'is_deleted', 'updated_at'],
    booleans: ['is_done', 'is_deleted'],
    validate(r) {
      if (!isUuid(r.task_id)) return 'task_id must be a UUID';
      if (!isNonEmptyString(r.title, 255)) return 'title is required (<=255 chars)';
      if (!(r.position == null || Number.isInteger(r.position))) return 'position must be an integer';
      return null;
    },
  },
  lms_courses: {
    columns: [
      'id', 'source', 'lms_course_id', 'subject_id', 'classification', 'title', 'teacher_name', 'credits',
      'register_midterm', 'register_endterm', 'final_exam', 'total', 'grade_items_json', 'imported_at',
      'is_deleted', 'updated_at',
    ],
    booleans: ['is_deleted'],
    validate(r) {
      if (!oneOfOrDefault(LMS_COURSE_SOURCES, r.source, 'lms')) return `source must be one of ${LMS_COURSE_SOURCES.join(', ')}`;
      if (!nullableLmsId(r.lms_course_id)) return 'lms_course_id must be a non-negative integer';
      if (!nullableUuid(r.subject_id)) return 'subject_id must be a UUID';
      if (!(r.classification == null || LMS_CLASSIFICATIONS.includes(r.classification))) {
        return `classification must be one of ${LMS_CLASSIFICATIONS.join(', ')}`;
      }
      if (!isNonEmptyString(r.title, 255)) return 'title is required (<=255 chars)';
      if (!nullableStr(160)(r.teacher_name)) return 'teacher_name too long';
      if (!(r.credits === undefined || (Number.isInteger(r.credits) && r.credits >= 1 && r.credits <= 30))) {
        return 'credits must be an integer 1..30';
      }
      for (const k of ['register_midterm', 'register_endterm', 'final_exam', 'total']) {
        if (!nullableScore(r[k])) return `${k} must be a number 0..100 or null`;
      }
      if (!nullableStr(100_000)(r.grade_items_json)) return 'grade_items_json must be a string (<=100000 chars)';
      if (!nullableEpoch(r.imported_at)) return 'imported_at must be epoch ms';
      return null;
    },
  },
  lms_events: {
    columns: [
      'id', 'lms_event_id', 'lms_course_id', 'title', 'course_title', 'event_type', 'module_name', 'starts_at',
      'duration_min', 'location', 'url', 'is_done', 'imported_at', 'is_deleted', 'updated_at',
    ],
    booleans: ['is_done', 'is_deleted'],
    validate(r) {
      if (!nullableLmsId(r.lms_event_id) || !nullableLmsId(r.lms_course_id)) return 'lms ids must be non-negative integers';
      if (!isNonEmptyString(r.title, 255)) return 'title is required (<=255 chars)';
      if (!nullableStr(255)(r.course_title)) return 'course_title too long';
      if (!oneOfOrDefault(LMS_EVENT_TYPES, r.event_type, 'other')) return `event_type must be one of ${LMS_EVENT_TYPES.join(', ')}`;
      if (!nullableStr(64)(r.module_name)) return 'module_name too long';
      if (!isEpochMs(r.starts_at)) return 'starts_at must be epoch ms';
      if (!(r.duration_min == null || (Number.isInteger(r.duration_min) && r.duration_min >= 0))) {
        return 'duration_min must be a non-negative integer';
      }
      if (!nullableStr(128)(r.location)) return 'location too long';
      if (!nullableStr(1024)(r.url)) return 'url too long';
      if (!nullableEpoch(r.imported_at)) return 'imported_at must be epoch ms';
      return null;
    },
  },
  lms_materials: {
    columns: [
      'id', 'lms_module_id', 'lms_course_id', 'course_title', 'section_title', 'title', 'material_type', 'url',
      'imported_at', 'is_deleted', 'updated_at',
    ],
    booleans: ['is_deleted'],
    validate(r) {
      if (!nullableLmsId(r.lms_module_id) || !nullableLmsId(r.lms_course_id)) return 'lms ids must be non-negative integers';
      if (!nullableStr(255)(r.course_title) || !nullableStr(255)(r.section_title)) return 'course_title/section_title too long';
      if (!isNonEmptyString(r.title, 255)) return 'title is required (<=255 chars)';
      if (!oneOfOrDefault(LMS_MATERIAL_TYPES, r.material_type, 'other')) {
        return `material_type must be one of ${LMS_MATERIAL_TYPES.join(', ')}`;
      }
      if (!nullableStr(1024)(r.url)) return 'url too long';
      if (!nullableEpoch(r.imported_at)) return 'imported_at must be epoch ms';
      return null;
    },
  },
};

/** Order matters: parents first so FK checks pass inside one transaction. */
export const SYNC_ORDER = ['subjects', 'lessons', 'tasks', 'subtasks', 'lms_courses', 'lms_events', 'lms_materials'];

export function normalizeRow(table, row) {
  if (!row) return row;
  const spec = SYNC_TABLES[table];
  const out = { ...row };
  for (const b of spec?.booleans ?? []) out[b] = toBool(out[b]);
  for (const b of spec?.nullableBooleans ?? []) out[b] = toNullableBool(out[b]);
  return out;
}

export function normalizeUser(row) {
  if (!row) return null;
  const { password_hash: _ignored, ...rest } = row;
  return rest;
}
