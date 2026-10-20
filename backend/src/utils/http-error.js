export class HttpError extends Error {
  /**
   * @param {number} status HTTP status
   * @param {string} code machine-readable error code
   * @param {string} message human readable message
   * @param {unknown} [details]
   */
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export const badRequest = (message, details) => new HttpError(400, 'BAD_REQUEST', message, details);
export const unauthorized = (message = 'Authentication required') => new HttpError(401, 'UNAUTHORIZED', message);
export const forbidden = (message = 'Forbidden') => new HttpError(403, 'FORBIDDEN', message);
export const notFound = (message = 'Not found') => new HttpError(404, 'NOT_FOUND', message);
export const conflict = (message) => new HttpError(409, 'CONFLICT', message);

/** Wraps an async express handler so rejected promises reach the error middleware. */
export const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
