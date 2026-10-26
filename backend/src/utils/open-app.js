/** Android package of the Flutter app (`applicationId` in mobile/android/app/build.gradle.kts). */
export const ANDROID_PACKAGE = 'com.studyplan.studyplan';

/** `host[:port]` as browsers send it; anything else is rejected. */
const HOST_RE = /^[a-z0-9.-]+(:\d{1,5})?$|^\[[0-9a-f:]+\](:\d{1,5})?$/i;

/** Origin of the server as the phone reached it, or null for a suspicious Host header. */
export function requestOrigin(req) {
  const host = req.get('host') ?? '';
  return HOST_RE.test(host) ? `${req.protocol}://${host}` : null;
}

/**
 * Chrome intent URL: opens the installed app with `studyplan://connect?server=<origin>`
 * (the app saves `<origin>/api` as its API address), or falls back to the web
 * version at `origin` when the app is not installed.
 */
export function androidIntentUrl(origin) {
  const fallback = encodeURIComponent(`${origin}/`);
  return `intent://connect?server=${encodeURIComponent(origin)}`
    + `#Intent;scheme=studyplan;package=${ANDROID_PACKAGE};S.browser_fallback_url=${fallback};end`;
}

const escapeHtml = (s) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

/** Page served at `/open` on Android: tries the app right away, with buttons as a fallback. */
export function openAppPage(origin) {
  const intent = escapeHtml(androidIntentUrl(origin));
  const web = escapeHtml(`${origin}/`);
  return `<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>StudyPlan</title>
<style>
  body { margin: 0; font-family: system-ui, sans-serif; background: #fff; color: #111; }
  main { max-width: 360px; margin: 0 auto; padding: 48px 16px; }
  h1 { font-size: 22px; font-weight: 600; margin: 0 0 8px; }
  p { color: #555; margin: 0 0 24px; line-height: 1.5; }
  a { display: block; text-align: center; padding: 12px; border-radius: 8px; text-decoration: none; font-weight: 500; margin-bottom: 8px; }
  .primary { background: #111; color: #fff; }
  .secondary { border: 1px solid #ddd; color: #111; }
  @media (prefers-color-scheme: dark) {
    body { background: #111; color: #eee; } p { color: #aaa; }
    .primary { background: #eee; color: #111; } .secondary { border-color: #333; color: #eee; }
  }
</style>
</head>
<body>
<main>
  <h1>StudyPlan</h1>
  <p>Открываем приложение. Адрес сервера подставится сам.</p>
  <a class="primary" href="${intent}">Открыть приложение</a>
  <a class="secondary" href="${web}">Открыть веб-версию</a>
</main>
<script>location.replace(${JSON.stringify(androidIntentUrl(origin)).replace(/</g, '\\u003c')});</script>
</body>
</html>`;
}
