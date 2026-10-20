/**
 * Thin indirection between business services and Socket.IO so services stay
 * testable without a running socket server.
 */
let io = null;

export const groupRoom = (groupId) => `group:${groupId}`;
export const userRoom = (userId) => `user:${userId}`;

export function setIo(instance) {
  io = instance;
}

export function emitToGroup(groupId, event, payload) {
  if (io && groupId) io.to(groupRoom(groupId)).emit(event, payload);
}

export function emitToUser(userId, event, payload) {
  if (io && userId) io.to(userRoom(userId)).emit(event, payload);
}
