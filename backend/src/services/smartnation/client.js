import { env } from '../../config/env.js';
import { HttpError } from '../../utils/http-error.js';

/**
 * Client of the college portal SmartNation (Laravel).
 *
 * Login: GET /ru/{region}/login -> cookies + <meta name="csrf-token">,
 *        POST /ru/{region}/login (JSON) with X-CSRF-TOKEN / X-XSRF-TOKEN.
 * The session lives in cookies, so the client keeps its own tiny cookie jar.
 * Lists come back as JSON with ?withFilters=true and X-Requested-With.
 */

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';

export const invalidCredentials = () =>
  new HttpError(401, 'SN_INVALID_CREDENTIALS', 'Wrong SmartNation login or password');
export const snUnavailable = (message = 'SmartNation is unavailable') => new HttpError(502, 'SN_UNAVAILABLE', message);

export class SmartNationClient {
  constructor({ region = env.smartnation.region, baseUrl = env.smartnation.baseUrl, fetchImpl = fetch } = {}) {
    this.region = region;
    this.baseUrl = baseUrl;
    this.fetch = fetchImpl;
    this.cookies = new Map();
    this.credentials = null;
  }

  url(path) {
    return `${this.baseUrl}/ru/${this.region}/${path.replace(/^\//, '')}`;
  }

  storeCookies(res) {
    const list = typeof res.headers.getSetCookie === 'function' ? res.headers.getSetCookie() : [];
    for (const c of list) {
      const [pair] = c.split(';');
      const i = pair.indexOf('=');
      if (i > 0) this.cookies.set(pair.slice(0, i).trim(), pair.slice(i + 1).trim());
    }
  }

  cookieHeader() {
    return [...this.cookies].map(([k, v]) => `${k}=${v}`).join('; ');
  }

  xsrf() {
    const v = this.cookies.get('XSRF-TOKEN');
    return v ? decodeURIComponent(v) : undefined;
  }

  async request(path, { method = 'GET', body, json = true, headers = {} } = {}) {
    let res;
    try {
      res = await this.fetch(path.startsWith('http') ? path : this.url(path), {
        method,
        redirect: 'manual',
        headers: {
          'User-Agent': USER_AGENT,
          Accept: json ? 'application/json, text/plain, */*' : 'text/html,application/xhtml+xml',
          'X-Requested-With': 'XMLHttpRequest',
          ...(this.cookies.size ? { Cookie: this.cookieHeader() } : {}),
          ...(this.xsrf() ? { 'X-XSRF-TOKEN': this.xsrf() } : {}),
          ...(body ? { 'Content-Type': 'application/json' } : {}),
          ...headers,
        },
        body: body ? JSON.stringify(body) : undefined,
      });
    } catch (err) {
      throw snUnavailable(`SmartNation is unreachable (${err.cause?.code ?? err.message})`);
    }
    this.storeCookies(res);
    return res;
  }

  /** Login by IIN (12 digits) or by login. Throws 401 SN_INVALID_CREDENTIALS on wrong data. */
  async login(login, password) {
    const page = await this.request('login', { json: false });
    const html = await page.text();
    const csrf = html.match(/<meta\s+name="csrf-token"\s+content="([^"]+)"/i)?.[1];
    if (!csrf) throw snUnavailable('SmartNation is unavailable (no CSRF token)');

    const id = String(login).trim();
    const body = /^\d{12}$/.test(id)
      ? { type: 'iin', iin: id, password }
      : { type: 'login', login: id, password };

    const res = await this.request('login', { method: 'POST', body, headers: { 'X-CSRF-TOKEN': csrf } });
    if (res.status === 422 || res.status === 401) throw invalidCredentials();
    if (res.status >= 400) throw snUnavailable(`SmartNation responded with ${res.status}`);

    // Laravel answers 200/204 without a body or with a redirect: check that the session is real.
    const check = await this.request('control/journals?withFilters=true');
    if (check.status !== 200) throw invalidCredentials();
    this.credentials = { login: id, password };
    return true;
  }

  /** GET JSON; on an expired session (401/419/redirect to login) logs in again once. */
  async getJson(path, retry = true) {
    const res = await this.request(path);
    if ([401, 419, 302].includes(res.status) && retry && this.credentials) {
      await this.login(this.credentials.login, this.credentials.password);
      return this.getJson(path, false);
    }
    if (res.status !== 200) throw snUnavailable(`SmartNation: ${path} -> ${res.status}`);
    const text = await res.text();
    try {
      return JSON.parse(text);
    } catch {
      throw snUnavailable(`SmartNation: ${path} returned non-JSON`);
    }
  }

  async getHtml(path) {
    const res = await this.request(path, { json: false });
    if (res.status !== 200) throw snUnavailable(`SmartNation: ${path} -> ${res.status}`);
    return res.text();
  }

  /** All pages of a list (Laravel paginate: meta.last_page). */
  async getAllPages(path) {
    const sep = path.includes('?') ? '&' : '?';
    const first = await this.getJson(`${path}${sep}withFilters=true`);
    const items = [...(first.data || [])];
    const last = first.meta?.last_page || 1;
    for (let p = 2; p <= Math.min(last, 20); p += 1) {
      // eslint-disable-next-line no-await-in-loop
      const page = await this.getJson(`${path}${sep}withFilters=true&page=${p}`);
      items.push(...(page.data || []));
    }
    return items;
  }

  getJournals() {
    return this.getAllPages('control/journals');
  }

  getSummary() {
    return this.getJson('control/summary?withFilters=true');
  }

  getContingent(journalId) {
    return this.getJson(`control/journals/${journalId}/contingent`);
  }

  getRefs(journalId) {
    return this.getJson(`control/journals/${journalId}/refs`);
  }

  getLoadTable(journalId, yearMonth) {
    return this.getJson(`control/journals/${journalId}/load-table?year_month=${encodeURIComponent(yearMonth)}`);
  }

  /** Ids of disciplines with assigned homework (only present in the HTML summary page). */
  async getHomeworkDisciplineIds() {
    const html = await this.getHtml('control/assigned-homework/disciplines-list');
    return [...new Set([...html.matchAll(/discipline=(\d+)/g)].map((m) => m[1]))];
  }

  /** Homework of a discipline: closed=false — open, closed=true — closed. */
  getHomeworks(disciplineId, { closed = false } = {}) {
    return this.getAllPages(`control/assigned-homeworks?discipline=${disciplineId}${closed ? '&closed=1' : ''}`);
  }
}
