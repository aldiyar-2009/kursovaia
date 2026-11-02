// Tiny diagram helper: absolutely positioned boxes + SVG orthogonal arrows.
// Rendered to PNG with Playwright for the explanatory note.
const D = (() => {
  const root = document.getElementById('d');
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('width', root.style.width ? parseInt(root.style.width, 10) : 2000);
  svg.setAttribute('height', root.style.height ? parseInt(root.style.height, 10) : 1400);
  svg.innerHTML = `<defs>
    <marker id="a" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="9" markerHeight="9" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="#000"/></marker></defs>`;
  root.appendChild(svg);

  const el = (tag, cls, html) => {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (html != null) n.innerHTML = html;
    return n;
  };

  /** Box with a grey title bar and body lines. */
  function box(x, y, w, h, title, lines = [], opts = {}) {
    const b = el('div', 'box' + (opts.dashed ? ' dashed' : '') + (opts.outer ? ' outer' : ''));
    Object.assign(b.style, { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
    if (title) b.appendChild(el('div', 'title', title));
    if (lines.length) {
      const body = el('div', 'body' + (opts.center ? ' center' : ''));
      body.innerHTML = lines.join('<br>');
      b.appendChild(body);
    }
    root.appendChild(b);
    return { x, y, w, h };
  }

  function text(x, y, html, opts = {}) {
    const t = el('div', 'label' + (opts.cls ? ' ' + opts.cls : ''), html);
    Object.assign(t.style, { left: x + 'px', top: y + 'px' });
    if (opts.w) t.style.width = opts.w + 'px';
    root.appendChild(t);
  }

  /** Polyline through points; arrowheads at end (and start when double). */
  function arrow(points, opts = {}) {
    const p = document.createElementNS('http://www.w3.org/2000/svg', 'polyline');
    p.setAttribute('points', points.map((q) => q.join(',')).join(' '));
    p.setAttribute('fill', 'none');
    p.setAttribute('stroke', '#000');
    p.setAttribute('stroke-width', opts.width ?? 2);
    if (opts.dashed) p.setAttribute('stroke-dasharray', '9 6');
    if (opts.head !== false) p.setAttribute('marker-end', 'url(#a)');
    if (opts.double) p.setAttribute('marker-start', 'url(#a)');
    svg.appendChild(p);
  }

  function line(x1, y1, x2, y2, opts = {}) {
    arrow([[x1, y1], [x2, y2]], { ...opts, head: opts.head ?? false });
  }

  return { box, text, arrow, line, root, svg };
})();
