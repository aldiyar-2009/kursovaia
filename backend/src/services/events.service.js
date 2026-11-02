import * as cheerio from 'cheerio';
import { db } from '../config/db.js';
import { env } from '../config/env.js';
import { toBool } from '../utils/validators.js';

/**
 * University events from public Telegram channels (DSVR News and others, EVENT_SOURCES).
 *
 * No Telegram account is needed: the public web view https://t.me/s/<channel> returns
 * HTML with the latest ~20 posts, `?before=<id>` — older ones. The event date/time
 * (📅 ⏰), place (📍) and registration link are taken from the post text. Posts without
 * an event date (news, podcasts) are skipped.
 */

const TZ = '+05:00'; // Astana
const HOUR = 3_600_000;
const DAY = 24 * HOUR;

// Months: Russian, Kazakh, English (genitive forms and abbreviations).
const MONTHS = [
  [/^(январ|қаңтар|jan)/i, 1],
  [/^(феврал|ақпан|feb)/i, 2],
  [/^(март|наурыз|mar)/i, 3],
  [/^(апрел|сәуір|apr)/i, 4],
  [/^(ма[йя]|мамыр|may)/i, 5],
  [/^(июн|маусым|jun)/i, 6],
  [/^(июл|шілде|jul)/i, 7],
  [/^(август|тамыз|aug)/i, 8],
  [/^(сентябр|қыркүйек|sep)/i, 9],
  [/^(октябр|қазан|oct)/i, 10],
  [/^(ноябр|қараша|nov)/i, 11],
  [/^(декабр|желтоқсан|dec)/i, 12],
];
const MONTH_WORD = '([A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі]{3,})';

const monthNo = (word) => {
  for (const [re, n] of MONTHS) if (re.test(word)) return n;
  return null;
};

const DATE_LINE = /📅|📆|🗓|дата|date|күні|когда/i;
const TIME_LINE = /⏰|[🕐-🕧]|время|time|уақыты|басталуы/iu;
const PLACE_LINE = /📍/;
const REG_LINE = /регистрац|тіркел|register|registration|✍️|🔗|👉|билет|ticket/i;
const REG_HOSTS = /forms\.gle|forms\.cloud\.microsoft|forms\.office|docs\.google\.com\/forms|ticketon|tally\.so|clck\.ru/i;

/** Finds a date (day, month, year?) in a line. */
export function findDate(s) {
  let m = s.match(/\b(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?\b/);
  if (m && +m[2] >= 1 && +m[2] <= 12 && +m[1] >= 1 && +m[1] <= 31) {
    const y = m[3] ? (m[3].length === 2 ? 2000 + +m[3] : +m[3]) : null;
    return { d: +m[1], mo: +m[2], y };
  }
  // «5 ноября», «1 қараша 2026», «4 Nov»
  m = s.match(new RegExp(`\\b(\\d{1,2})\\s+${MONTH_WORD}(?:\\s+(\\d{4}))?`, 'u'));
  if (m && monthNo(m[2])) return { d: +m[1], mo: monthNo(m[2]), y: m[3] ? +m[3] : null };
  // «Nov 4», «November 1, 2026»
  m = s.match(new RegExp(`${MONTH_WORD}\\s+(\\d{1,2})(?:,?\\s+(\\d{4}))?\\b`, 'u'));
  if (m && monthNo(m[1])) return { d: +m[2], mo: monthNo(m[1]), y: m[3] ? +m[3] : null };
  return null;
}

/** "19:00" | "1:30 PM" -> "HH:mm" */
const findTime = (s) => {
  const m = s.match(/\b([01]?\d|2[0-3]):([0-5]\d)(?:\s*([AaPp])\.?[Mm]\.?)?/);
  if (!m) return null;
  let h = +m[1];
  if (m[3] && /p/i.test(m[3]) && h < 12) h += 12;
  if (m[3] && /a/i.test(m[3]) && h === 12) h = 0;
  return `${String(h).padStart(2, '0')}:${m[2]}`;
};

/** No year given -> the one closest to the post date (slightly biased to the future). */
export function inferYear(d, mo, postedAt) {
  const posted = new Date(postedAt);
  const y = posted.getUTCFullYear();
  let best = y;
  let bestDiff = Infinity;
  for (const cand of [y - 1, y, y + 1]) {
    const diff = Date.UTC(cand, mo - 1, d) - posted.getTime();
    const score = diff < 0 ? -diff * 3 : diff; // past dates are "more expensive"
    if (score < bestDiff) {
      bestDiff = score;
      best = cand;
    }
  }
  return best;
}

const stripEmoji = (s) => s
  .replace(/[\p{Extended_Pictographic}\p{Regional_Indicator}\u{FE0F}\u{200D}\u{20E3}]/gu, '')
  .replace(/^[\s|:–—-]+/, '')
  .trim();

/** Parses a post text. Returns null when it is not an event. `starts_at` is an ISO string. */
export function extractEventInfo(text, links, postedAt) {
  const lines = String(text || '')
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean);
  if (!lines.length) return null;

  const dateLines = lines.filter((l) => DATE_LINE.test(l));
  let date = null;
  for (const l of [...dateLines, ...lines]) if ((date = findDate(l))) break;
  if (!date) return null;

  let time = null;
  for (const l of [...dateLines, ...lines.filter((x) => TIME_LINE.test(x))]) if ((time = findTime(l))) break;

  const year = date.y || inferYear(date.d, date.mo, postedAt);
  const ymd = `${year}-${String(date.mo).padStart(2, '0')}-${String(date.d).padStart(2, '0')}`;
  const startsAt = new Date(`${ymd}T${time || '00:00'}:00${TZ}`);
  if (Number.isNaN(startsAt.getTime())) return null;

  // Place: the line with 📍 (it may also contain date/time separated by "|").
  let place = null;
  const placeLine = lines.find((l) => PLACE_LINE.test(l));
  if (placeLine) {
    const part = placeLine.split('|').find((p) => PLACE_LINE.test(p)) || placeLine;
    place = stripEmoji(part)
      .replace(/^(кабинет|место|локация|өтетін орны|location|venue|орны)\s*:\s*/i, '')
      .trim() || null;
  }

  const link = links.find((h) => REG_HOSTS.test(h))
    || (lines.some((l) => REG_LINE.test(l)) ? links[0] : null)
    || null;

  return {
    title: stripEmoji(lines[0]).slice(0, 200) || 'Мероприятие',
    starts_at: startsAt.toISOString(),
    has_time: Boolean(time),
    place: place ? place.slice(0, 200) : null,
    link: link ?? null,
  };
}

/** Parses a t.me/s/<channel> page. Times in the result are ISO strings. */
export function parsePage(html, channel) {
  const $ = cheerio.load(html);
  const events = [];
  $('.tgme_widget_message[data-post]').each((_, el) => {
    const post = $(el);
    const id = post.attr('data-post').split('/')[1];
    const postedAt = post.find('.tgme_widget_message_date time').attr('datetime');
    const textEl = post.find('.tgme_widget_message_text').first();
    if (!postedAt || !textEl.length) return;

    const text = cheerio
      .load(`<div>${(textEl.html() || '').replace(/<br\s*\/?>/gi, '\n')}</div>`)('div')
      .text();
    const links = textEl.find('a[href]').map((__, a) => $(a).attr('href')).get().filter((h) => /^https?:/i.test(h));
    const info = extractEventInfo(text, links, postedAt);
    if (!info) return;

    const style = post.find('.tgme_widget_message_photo_wrap').attr('style') || '';
    events.push({
      source: channel,
      external_id: id,
      ...info,
      text: text.trim().slice(0, 4000),
      image_url: style.match(/url\(['"]?([^'")]+)/)?.[1] || null,
      post_url: `https://t.me/${channel}/${id}`,
      posted_at: new Date(postedAt).toISOString(),
    });
  });
  const before = $('.tme_messages_more[data-before]').attr('data-before')
    || $('.tme_messages_more').attr('href')?.match(/before=(\d+)/)?.[1];
  return { events, before: before || null };
}

export async function fetchChannel(channel, { pages = 1, fetchImpl = fetch } = {}) {
  const all = [];
  let before = null;
  for (let i = 0; i < pages; i += 1) {
    const url = `https://t.me/s/${channel}${before ? `?before=${before}` : ''}`;
    // eslint-disable-next-line no-await-in-loop
    const res = await fetchImpl(url, { headers: { 'User-Agent': 'Mozilla/5.0 StudyPlan' } });
    if (!res.ok) throw new Error(`t.me/s/${channel} -> ${res.status}`);
    // eslint-disable-next-line no-await-in-loop
    const page = parsePage(await res.text(), channel);
    all.push(...page.events);
    if (!page.before) break;
    before = page.before;
  }
  return all;
}

/** Upserts parsed events (ISO times) into the `events` table (epoch ms). */
export async function saveEvents(events, conn = db) {
  const now = Date.now();
  for (const e of events) {
    // eslint-disable-next-line no-await-in-loop
    await conn('events')
      .insert({
        ...e,
        starts_at: Date.parse(e.starts_at),
        posted_at: Date.parse(e.posted_at),
        updated_at: now,
      })
      .onConflict(['source', 'external_id'])
      .merge();
  }
  return events.length;
}

/** Refreshes `events` from every channel. `pages` — how many history pages to read. */
export async function refreshEvents({ pages = 1, channels = env.eventSources, fetchImpl = fetch, conn = db } = {}) {
  let count = 0;
  for (const channel of channels) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const events = await fetchChannel(channel, { pages, fetchImpl });
      // eslint-disable-next-line no-await-in-loop
      count += await saveEvents(events, conn);
    } catch (err) {
      console.error(`[events] ${channel}: ${err.message}`);
    }
  }
  return count;
}

/**
 * GET /events?scope=upcoming|past&limit=
 * An event has ended 2 hours after its start, or at the end of its day when it has no time.
 */
export async function listEvents({ scope, limit } = {}) {
  const past = scope === 'past';
  const n = Math.min(Math.max(Number.parseInt(limit, 10) || 50, 1), 200);
  const endsAt = db.raw(`starts_at + CASE WHEN has_time THEN ${2 * HOUR} ELSE ${DAY} END`);
  const q = db('events').limit(n);
  if (past) q.where(endsAt, '<=', Date.now()).orderBy('starts_at', 'desc');
  else q.where(endsAt, '>', Date.now()).orderBy('starts_at', 'asc');
  const rows = await q;
  return {
    events: rows.map((r) => ({
      id: r.id,
      title: r.title,
      text: r.text,
      starts_at: Number(r.starts_at),
      has_time: toBool(r.has_time),
      place: r.place,
      link: r.link,
      image_url: r.image_url,
      post_url: r.post_url,
    })),
  };
}
