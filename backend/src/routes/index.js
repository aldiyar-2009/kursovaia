import { Router } from 'express';
import * as auth from '../controllers/auth.controller.js';
import * as materials from '../controllers/materials.controller.js';
import { sync } from '../controllers/sync.controller.js';
import { requireAuth } from '../middleware/auth.js';

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

// Group materials & files
router.get('/materials', requireAuth, materials.list);
router.post('/materials/upload', requireAuth, materials.upload.single('file'), materials.create);
router.delete('/materials/:id', requireAuth, materials.remove);
router.get('/files/:name', requireAuth, materials.downloadFile);
