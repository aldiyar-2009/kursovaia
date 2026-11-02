import { Router } from 'express';
import * as admin from '../controllers/admin.controller.js';
import * as auth from '../controllers/auth.controller.js';
import * as college from '../controllers/college.controller.js';
import * as materials from '../controllers/materials.controller.js';
import { sync } from '../controllers/sync.controller.js';
import { requireAdmin, requireAuth } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rate-limit.js';

export const router = Router();

router.get('/health', (_req, res) => res.json({ status: 'ok', time: Date.now() }));

// Auth
router.post('/auth/register', auth.register);
router.post('/auth/login', auth.login);
router.get('/auth/me', requireAuth, auth.me);
router.patch('/auth/me', requireAuth, auth.updateMe);

// Demo accounts (try the app without registering)
router.post('/auth/demo', rateLimit({ windowMs: 60 * 60_000, max: 30 }), auth.createDemo);
router.post('/auth/demo/reset', requireAuth, auth.clearDemo);

// College edition: sign-in through SmartNation, grades/assignments snapshot
router.post('/auth/smartnation', rateLimit({ windowMs: 15 * 60_000, max: 20 }), college.loginSmartNation);
router.get('/college/snapshot', requireAuth, college.snapshot);
router.post('/college/refresh', requireAuth, college.refresh);

// Public: college timetable (Excel import) and university events (Telegram channels)
router.get('/timetable', college.timetable);
router.get('/timetable/groups', college.timetableGroups);
router.get('/events', college.events);

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

// Announcements published from the admin panel (public: shown in guest mode too)
router.get('/announcements', admin.publishedAnnouncements);

// Admin panel (role = admin)
const adminOnly = [requireAuth, requireAdmin];
router.get('/admin/stats', adminOnly, admin.stats);
router.get('/admin/users', adminOnly, admin.listUsers);
router.post('/admin/users', adminOnly, admin.createUser);
router.patch('/admin/users/:id', adminOnly, admin.updateUser);
router.post('/admin/users/:id/block', adminOnly, admin.blockUser);
router.post('/admin/users/:id/unblock', adminOnly, admin.unblockUser);
router.get('/admin/announcements', adminOnly, admin.listAnnouncements);
router.post('/admin/announcements', adminOnly, admin.createAnnouncement);
router.patch('/admin/announcements/:id', adminOnly, admin.updateAnnouncement);
router.delete('/admin/announcements/:id', adminOnly, admin.deleteAnnouncement);
router.post('/admin/announcements/:id/publish', adminOnly, admin.publishAnnouncement);
router.post('/admin/announcements/:id/unpublish', adminOnly, admin.unpublishAnnouncement);
