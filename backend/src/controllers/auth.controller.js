import * as authService from '../services/auth.service.js';
import * as groupService from '../services/group.service.js';
import { asyncHandler } from '../utils/http-error.js';

export const register = asyncHandler(async (req, res) => {
  res.status(201).json(await authService.register(req.body ?? {}));
});

export const login = asyncHandler(async (req, res) => {
  res.json(await authService.login(req.body ?? {}));
});

export const me = asyncHandler(async (req, res) => {
  res.json(await authService.buildSession(req.user));
});

export const updateMe = asyncHandler(async (req, res) => {
  res.json(await authService.updateMe(req.user, req.body ?? {}));
});


export const createGroup = asyncHandler(async (req, res) => {
  res.status(201).json(await groupService.createGroup(req.user.id, req.body ?? {}));
});

export const joinGroup = asyncHandler(async (req, res) => {
  res.json(await groupService.joinGroup(req.user.id, req.body?.invite_code));
});

export const leaveGroup = asyncHandler(async (req, res) => {
  res.json(await groupService.leaveGroup(req.user.id));
});

export const myGroup = asyncHandler(async (req, res) => {
  res.json(await groupService.getMyGroup(req.user));
});

export const updateGroup = asyncHandler(async (req, res) => {
  res.json(await groupService.updateGroup(req.user, req.body ?? {}));
});
