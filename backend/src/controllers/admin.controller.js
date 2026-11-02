import * as admin from '../services/admin.service.js';
import { asyncHandler } from '../utils/http-error.js';

export const stats = asyncHandler(async (_req, res) => {
  res.json(await admin.stats());
});

export const listUsers = asyncHandler(async (req, res) => {
  res.json({ users: await admin.listUsers(req.query) });
});

export const createUser = asyncHandler(async (req, res) => {
  res.status(201).json({ user: await admin.createUser(req.body ?? {}) });
});

export const updateUser = asyncHandler(async (req, res) => {
  res.json({ user: await admin.updateUser(req.user, req.params.id, req.body ?? {}) });
});

export const blockUser = asyncHandler(async (req, res) => {
  res.json({ user: await admin.setBlocked(req.user, req.params.id, true) });
});

export const unblockUser = asyncHandler(async (req, res) => {
  res.json({ user: await admin.setBlocked(req.user, req.params.id, false) });
});

export const listAnnouncements = asyncHandler(async (_req, res) => {
  res.json({ announcements: await admin.listAnnouncements() });
});

export const createAnnouncement = asyncHandler(async (req, res) => {
  res.status(201).json({ announcement: await admin.createAnnouncement(req.user, req.body ?? {}) });
});

export const updateAnnouncement = asyncHandler(async (req, res) => {
  res.json({ announcement: await admin.updateAnnouncement(req.params.id, req.body ?? {}) });
});

export const publishAnnouncement = asyncHandler(async (req, res) => {
  res.json({ announcement: await admin.setPublished(req.params.id, true) });
});

export const unpublishAnnouncement = asyncHandler(async (req, res) => {
  res.json({ announcement: await admin.setPublished(req.params.id, false) });
});

export const deleteAnnouncement = asyncHandler(async (req, res) => {
  res.json(await admin.deleteAnnouncement(req.params.id));
});

/** Public part shown in the mobile app (also in guest mode). */
export const publishedAnnouncements = asyncHandler(async (_req, res) => {
  res.json({ announcements: await admin.publishedAnnouncements() });
});
