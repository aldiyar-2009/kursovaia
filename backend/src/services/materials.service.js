import { db } from '../config/db.js';
import { badRequest, notFound, forbidden } from '../utils/http-error.js';
import { newId } from '../utils/validators.js';

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

/** Trimmed subject value, or null when missing, empty or a legacy placeholder. */
function optionalSubjectField(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed || NO_SUBJECT_PLACEHOLDERS.has(trimmed.toLowerCase())) return null;
  return trimmed;
}

export async function createMaterial(user, file, body) {
  const { title, subject_code, subject_title, category = 'lecture', description = null } = body;

  if (!user.group_id) {
    throw badRequest('You are not in a group');
  }
  if (!title || !title.trim()) {
    throw badRequest('Title is required');
  }

  const now = Date.now();
  const id = newId();

  const originalName = file ? Buffer.from(file.originalname, 'latin1').toString('utf8') : (body.file_name || 'document.pdf');
  const ext = originalName.split('.').pop()?.toLowerCase() || 'pdf';

  const record = {
    id,
    group_id: user.group_id,
    uploader_id: user.id,
    uploader_name: user.name,
    subject_code: optionalSubjectField(subject_code),
    subject_title: optionalSubjectField(subject_title),
    title: title.trim(),
    description: description ? description.trim() : null,
    file_name: originalName,
    file_path: file ? file.filename : `virtual_${id}.${ext}`,
    file_size: file ? file.size : (Number(body.file_size) || 0),
    file_type: ext,
    category,
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
  return { success: true };
}

/** Material whose stored file is `fileName`, only if it belongs to the user's group. */
export async function findGroupMaterialByFile(user, fileName) {
  if (!user.group_id) return null;
  return db('course_materials').where({ file_path: fileName, group_id: user.group_id }).first();
}
