import fs from 'node:fs/promises';
import path from 'node:path';
import { db } from '../config/db.js';
import { env } from '../config/env.js';
import { badRequest, notFound, forbidden } from '../utils/http-error.js';
import { newId } from '../utils/validators.js';

/** Column sizes of `course_materials` (see migrations); PostgreSQL rejects longer values. */
const LIMITS = {
  subject_code: 32,
  subject_title: 120,
  title: 200,
  file_name: 255,
  file_type: 16,
  category: 32,
};

export async function listMaterials(user, query = {}) {
  const q = db('course_materials')
    .where({ group_id: user.group_id })
    .orderBy('created_at', 'desc');

  if (query.subject) {
    q.andWhere('subject_code', query.subject);
  }
  if (query.category) {
    q.andWhere('category', query.category);
  }

  return q;
}

/** Legacy client placeholders for "no subject". */
const NO_SUBJECT_PLACEHOLDERS = new Set(['none', '-']);

/** First `max` characters (code points, as PostgreSQL varchar counts them), re-trimmed. */
function truncate(value, max) {
  const chars = Array.from(value);
  return chars.length <= max ? value : chars.slice(0, max).join('').trim();
}

/** Trimmed string or null when missing / blank. */
function trimmed(value) {
  if (typeof value !== 'string') return null;
  const t = value.trim();
  return t || null;
}

/** Trimmed subject value, or null when missing, empty or a legacy placeholder. */
function optionalSubjectField(value) {
  const t = trimmed(value);
  if (!t || NO_SUBJECT_PLACEHOLDERS.has(t.toLowerCase())) return null;
  return t;
}

/** Original file name (multer gives latin1), truncated to the column size keeping the extension. */
function safeFileName(file) {
  const name = Buffer.from(file.originalname ?? '', 'latin1').toString('utf8').trim() || 'file';
  if (Array.from(name).length <= LIMITS.file_name) return name;
  const ext = path.extname(name).slice(0, LIMITS.file_type + 1);
  const base = name.slice(0, name.length - path.extname(name).length);
  return truncate(base, LIMITS.file_name - Array.from(ext).length) + ext;
}

function fileType(fileName) {
  const ext = path.extname(fileName).slice(1).toLowerCase().replace(/[^a-z0-9]/g, '');
  return ext.slice(0, LIMITS.file_type) || 'bin';
}

/** Removes a stored upload, ignoring files that are already gone. */
async function removeStoredFile(filePath) {
  if (!filePath) return;
  try {
    await fs.unlink(filePath);
  } catch (err) {
    if (err.code !== 'ENOENT') console.warn(`[materials] cannot remove ${filePath}: ${err.message}`);
  }
}

/** Names multer gives stored uploads: `<uuid><.ext>`. */
export const STORED_NAME_RE = /^[0-9a-f-]{36}(\.[a-z0-9]{1,8})?$/i;

/** Absolute path of a stored material file; basename() keeps it inside the upload dir. */
const storedPath = (fileName) => path.join(env.uploadDir, path.basename(String(fileName)));

/**
 * Creates a material for an uploaded file. On any error (validation or DB) the file
 * multer already saved is deleted, so failed uploads leave no orphans on disk.
 */
export async function createMaterial(user, file, body = {}) {
  try {
    return await insertMaterial(user, file, body);
  } catch (err) {
    if (file) await removeStoredFile(file.path ?? storedPath(file.filename));
    throw err;
  }
}

async function insertMaterial(user, file, body) {
  if (!user.group_id) {
    throw badRequest('You are not in a group');
  }
  if (!file) {
    throw badRequest('File is required');
  }
  const title = trimmed(body.title);
  if (!title) {
    throw badRequest('Title is required');
  }

  const subjectTitle = optionalSubjectField(body.subject_title);
  const subjectCode = optionalSubjectField(body.subject_code) ?? subjectTitle;
  const fileName = safeFileName(file);
  const now = Date.now();

  const record = {
    id: newId(),
    group_id: user.group_id,
    uploader_id: user.id,
    uploader_name: truncate(String(user.name ?? ''), 120),
    subject_code: subjectCode ? truncate(subjectCode, LIMITS.subject_code) : null,
    subject_title: subjectTitle ? truncate(subjectTitle, LIMITS.subject_title) : null,
    title: truncate(title, LIMITS.title),
    description: trimmed(body.description),
    file_name: fileName,
    file_path: file.filename,
    file_size: Number(file.size) || 0,
    file_type: fileType(fileName),
    category: truncate(trimmed(body.category) ?? 'lecture', LIMITS.category),
    created_at: now,
    updated_at: now,
  };

  await db('course_materials').insert(record);
  return record;
}

export async function deleteMaterial(user, id) {
  const material = await db('course_materials').where({ id, group_id: user.group_id }).first();
  if (!material) {
    throw notFound('Material not found');
  }

  if (material.uploader_id !== user.id) {
    throw forbidden('Only the uploader can delete this material');
  }

  await db('course_materials').where({ id }).del();
  // Only unlink names multer generated (legacy/seed rows may hold arbitrary names),
  // and only when no other material still points at the same file.
  if (STORED_NAME_RE.test(String(material.file_path))) {
    const stillUsed = await db('course_materials').where({ file_path: material.file_path }).first();
    if (!stillUsed) await removeStoredFile(storedPath(material.file_path));
  }
  return { success: true };
}

/** Material whose stored file is `fileName`, only if it belongs to the user's group. */
export async function findGroupMaterialByFile(user, fileName) {
  if (!user.group_id) return null;
  return db('course_materials').where({ file_path: fileName, group_id: user.group_id }).first();
}
