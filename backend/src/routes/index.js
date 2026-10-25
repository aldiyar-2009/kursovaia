import { Router } from 'express';
import * as auth from '../controllers/auth.controller.js';
import * as chat from '../controllers/chat.controller.js';
import { sync } from '../controllers/sync.controller.js';
import { requireAuth } from '../middleware/auth.js';

import * as materials from '../controllers/materials.controller.js';

export const router = Router();

router.get('/health', (_req, res) => res.json({ status: 'ok', time: Date.now() }));

// Auth
router.post('/auth/register', auth.register);
router.post('/auth/login', auth.login);
router.get('/auth/me', requireAuth, auth.me);
router.patch('/auth/me', requireAuth, auth.updateMe);

// Groups
router.get('/groups/me', requireAuth, auth.myGroup);
router.patch('/groups/me', requireAuth, auth.updateGroup);
router.post('/groups', requireAuth, auth.createGroup);
router.post('/groups/join', requireAuth, auth.joinGroup);
router.post('/groups/leave', requireAuth, auth.leaveGroup);

// Offline-first batch sync
router.post('/sync', requireAuth, sync);

// Group chat
router.get('/chat/messages', requireAuth, chat.listMessages);
router.post('/chat/messages', requireAuth, chat.sendMessage);
router.patch('/chat/messages/:id/pin', requireAuth, chat.pinMessage);
router.post('/chat/upload', requireAuth, chat.upload.single('file'), chat.uploadFile);
router.get('/files/:name', requireAuth, chat.downloadFile);

// University course materials & files
router.get('/materials', requireAuth, materials.list);
router.post('/materials/upload', requireAuth, chat.upload.single('file'), materials.upload);
router.delete('/materials/:id', requireAuth, materials.remove);
