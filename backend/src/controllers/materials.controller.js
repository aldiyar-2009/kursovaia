import fs from 'node:fs';
import path from 'node:path';
import multer from 'multer';
import { env } from '../config/env.js';
import * as materialsService from '../services/materials.service.js';
import { asyncHandler, notFound } from '../utils/http-error.js';
import { newId } from '../utils/validators.js';

fs.mkdirSync(env.uploadDir, { recursive: true });

export const upload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, env.uploadDir),
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase().replace(/[^.a-z0-9]/g, '').slice(0, 9);
      cb(null, `${newId()}${ext}`);
    },
  }),
  limits: { fileSize: env.uploadMaxBytes, files: 1 },
});

export const list = asyncHandler(async (req, res) => {
  const materials = await materialsService.listMaterials(req.user, req.query);
  res.json({ materials });
});

export const create = asyncHandler(async (req, res) => {
  const material = await materialsService.createMaterial(req.user, req.file, req.body);
  res.status(201).json({ material });
});

export const remove = asyncHandler(async (req, res) => {
  const result = await materialsService.deleteMaterial(req.user, req.params.id);
  res.json(result);
});

/**
 * GET /api/files/:name — downloads an uploaded material file. Only members of the group
 * the material belongs to may download it; everyone else gets 404 (no existence leak).
 */
export const downloadFile = asyncHandler(async (req, res) => {
  const { name } = req.params;
  if (!materialsService.STORED_NAME_RE.test(name)) throw notFound('File not found');
  const material = await materialsService.findGroupMaterialByFile(req.user, name);
  if (!material || !fs.existsSync(path.join(env.uploadDir, name))) throw notFound('File not found');
  res.set('X-Content-Type-Options', 'nosniff');
  // `root` keeps the dotfile check on the file name only, not on the upload directory path.
  res.download(name, material.file_name, { root: env.uploadDir });
});
