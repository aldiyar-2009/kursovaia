import {
  isDateStr,
  isEpochMs,
  isNonEmptyString,
  isTimeStr,
  isUuid,
  parseJson,
  toBool,
  toNullableBool,
} from '../utils/validators.js';


const nullableUuid = (v) => v === null || v === undefined || isUuid(v);
const nullableStr = (max) => (v) => v === null || v === undefined || (typeof v === 'string' && v.length <= max);
const nullableDate = (v) => v === null || v === undefined || isDateStr(v);

export const LESSON_TYPES = ['lecture', 'practice', 'lab'];
export const TASK_STATUSES = ['inbox', 'in_progress', 'completed'];
export const MESSAGE_TYPES = ['text', 'schedule_update', 'homework', 'file'];
export const HEADMAN_ONLY_MESSAGE_TYPES = ['schedule_update', 'homework'];

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
};

/** Order matters: parents first so FK checks pass inside one transaction. */
export const SYNC_ORDER = ['subjects', 'lessons', 'tasks', 'subtasks'];

export function normalizeRow(table, row) {
  if (!row) return row;
  const spec = SYNC_TABLES[table];
  const out = { ...row };
  for (const b of spec?.booleans ?? []) out[b] = toBool(out[b]);
  for (const b of spec?.nullableBooleans ?? []) out[b] = toNullableBool(out[b]);
  return out;
}

export function normalizeMessage(row) {
  if (!row) return row;
  return { ...row, is_pinned: toBool(row.is_pinned), payload_json: parseJson(row.payload_json) };
}

export function normalizeUser(row) {
  if (!row) return null;
  const { password_hash: _ignored, ...rest } = row;
  return rest;
}
