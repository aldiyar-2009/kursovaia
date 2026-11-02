import * as collegeService from '../services/college.service.js';
import * as eventsService from '../services/events.service.js';
import * as timetableService from '../services/timetable.service.js';
import { asyncHandler } from '../utils/http-error.js';

export const loginSmartNation = asyncHandler(async (req, res) => {
  res.json(await collegeService.loginSmartNation(req.body ?? {}));
});

export const snapshot = asyncHandler(async (req, res) => {
  res.json(await collegeService.getSnapshot(req.user));
});

export const refresh = asyncHandler(async (req, res) => {
  res.json(await collegeService.refreshSnapshot(req.user));
});

export const timetable = asyncHandler(async (req, res) => {
  res.json(await timetableService.getTimetable(req.query.group));
});

export const timetableGroups = asyncHandler(async (_req, res) => {
  res.json(await timetableService.listGroups());
});

export const events = asyncHandler(async (req, res) => {
  res.json(await eventsService.listEvents({ scope: req.query.scope, limit: req.query.limit }));
});
