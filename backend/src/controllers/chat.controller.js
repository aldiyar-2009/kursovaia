import fs from 'node:fs';
import path from 'node:path';
import multer from 'multer';
import { env } from '../config/env.js';
import * as chatService from '../services/chat.service.js';
import { asyncHandler, badRequest, notFound } from '../utils/http-error.js';
import { newId } from '../utils/validators.js';

fs.mkdirSync(env.uploadDir, { recursive: true });

const SAFE_NAME_RE = /^[0-9a-f-]{36}(\.[a-z0-9]{1,8})?$/i;

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

export const listMessages = asyncHandler(async (req, res) => {
  res.json({ messages: await chatService.listMessages(req.user, req.query) });
});

export const sendMessage = asyncHandler(async (req, res) => {
  res.status(201).json({ message: await chatService.sendMessage(req.user, req.body) });
});

export const pinMessage = asyncHandler(async (req, res) => {
  res.json({ message: await chatService.setPinned(req.user, req.params.id, req.body?.pinned ?? true) });
});

/** Stores a chat attachment and returns metadata to embed into a `file` message payload. */
export const uploadFile = asyncHandler(async (req, res) => {
  if (!req.file) throw badRequest('Field "file" is required (multipart/form-data)');
  res.status(201).json({
    file_id: req.file.filename,
    file_name: Buffer.from(req.file.originalname, 'latin1').toString('utf8'),
    file_size: req.file.size,
    mime_type: req.file.mimetype,
    url: `/api/files/${req.file.filename}`,
  });
});

export const downloadFile = asyncHandler(async (req, res) => {
  const { name } = req.params;
  if (!SAFE_NAME_RE.test(name)) throw notFound('File not found');
  const full = path.join(env.uploadDir, name);
  if (!fs.existsSync(full)) throw notFound('File not found');
  res.sendFile(full);
});
