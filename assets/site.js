// Page behaviour: menu, top bar, reveals and Apple-style scroll effects. Everything degrades to a normal page.
(() => {
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Mobile menu
  const button = document.querySelector('.menu-button'), menu = document.getElementById('menu');
  const icons = { open: '<path d="M4 7h16M4 12h16M4 17h16"/>', close: '<path d="M6 6l12 12M18 6L6 18"/>' };
  const setMenu = open => { menu.classList.toggle('open', open); button.setAttribute('aria-expanded', open); button.querySelector('svg').innerHTML = open ? icons.close : icons.open; };
  button.addEventListener('click', () => setMenu(!menu.classList.contains('open')));
  menu.addEventListener('click', e => { if (e.target.closest('a')) setMenu(false); });
  addEventListener('keydown', e => { if (e.key === 'Escape') setMenu(false); });

  // Reveal on scroll, and count up numbers
  const countUp = el => {
    const target = Number(el.dataset.count || el.textContent), suffix = el.dataset.suffix || '';
    if (still || !target) return;
    const t0 = performance.now();
    const tick = t => { const p = Math.min(1, (t - t0) / 1400), e = 1 - Math.pow(1 - p, 3); el.textContent = Math.round(target * e) + suffix; if (p < 1) requestAnimationFrame(tick); };
    requestAnimationFrame(tick);
  };
  const io = new IntersectionObserver(entries => entries.forEach(e => {
    if (!e.isIntersecting) return;
    e.target.classList.add('in');
    e.target.querySelectorAll('[data-count]').forEach(countUp);
    io.unobserve(e.target);
  }), { threshold: 0.15, rootMargin: '0px 0px -8% 0px' });
  document.querySelectorAll('.hero .reveal').forEach(el => el.classList.add('in'));
  document.querySelectorAll('.reveal').forEach(el => io.observe(el));

  // Capability cards: soft spotlight follows the pointer
  document.querySelectorAll('.cap').forEach(card => card.addEventListener('pointermove', e => {
    const r = card.getBoundingClientRect();
    card.style.setProperty('--mx', `${e.clientX - r.left}px`); card.style.setProperty('--my', `${e.clientY - r.top}px`);
  }));

  // Statement: split into words that light up as you scroll through it
  const statement = document.querySelector('.statement p');
  let words = [];
  if (statement) {
    statement.innerHTML = statement.textContent.trim().split(/\s+/).map(w => `<span>${w}</span>`).join(' ');
    words = [...statement.querySelectorAll('span')];
    words.filter(w => /2010/.test(w.textContent)).forEach(w => w.classList.add('hl'));
  }

  // Service scenes: split each description into words that light up once the photo has settled
  const scenes = [...document.querySelectorAll('.scene')].map(el => {
    const p = el.querySelector('.words');
    p.innerHTML = p.textContent.trim().split(/\s+/).map(w => `<span>${w}</span>`).join(' ');
    return { el, words: [...p.querySelectorAll('span')] };
  });

  const topbar = document.querySelector('.topbar');
  const stage = document.querySelector('.expand');
  const parallax = [...document.querySelectorAll('[data-parallax]')];
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  // How far (0 to 1) the page has scrolled through a tall, sticky section.
  const progress = el => { const r = el.getBoundingClientRect(); return clamp(-r.top / (r.height - innerHeight)); };

  let queued = false;
  function frame() {
    queued = false;
    if (!topbar.hasAttribute('data-solid')) topbar.classList.toggle('solid', scrollY > 40);
    if (still) return;
    if (words.length) {
      const p = progress(document.querySelector('.statement'));
      const lit = Math.round(p * 1.15 * words.length);
      words.forEach((w, i) => w.classList.toggle('lit', i < lit));
    }
    if (stage) {
      const p = progress(stage), e = 1 - Math.pow(1 - clamp(p / 0.7), 3);
      stage.style.setProperty('--grow', e.toFixed(4));
      stage.style.setProperty('--caption', clamp((p - 0.55) / 0.3).toFixed(3));
      stage.querySelector('.frame').style.setProperty('--night', clamp((p - 0.3) / 0.35).toFixed(3));
    }
    for (const { el, words: ws } of scenes) {
      const r = el.getBoundingClientRect();
      if (r.bottom < -innerHeight || r.top > innerHeight * 1.5) continue;
      const p = progress(el), ease = x => 1 - Math.pow(1 - x, 3);
      el.style.setProperty('--big', (1 - clamp((p - 0.04) / 0.16)).toFixed(3));
      el.style.setProperty('--e', ease(clamp((p - 0.12) / 0.33)).toFixed(4));
      el.style.setProperty('--t', ease(clamp((p - 0.38) / 0.17)).toFixed(3));
      const lit = Math.round(clamp((p - 0.45) / 0.4) * ws.length);
      ws.forEach((w, i) => w.classList.toggle('lit', i < lit));
    }
    for (const el of parallax) {
      const r = el.getBoundingClientRect();
      const offset = (r.top + r.height / 2 - innerHeight / 2) * Number(el.dataset.parallax);
      el.style.transform = `translate3d(0, ${offset.toFixed(1)}px, 0)`;
    }
  }
  const request = () => { if (!queued) { queued = true; requestAnimationFrame(frame); } };
  addEventListener('scroll', request, { passive: true });
  addEventListener('resize', request);
  frame();

  // Logo strip: start moving only once every logo has loaded, so the loop width never changes mid-scroll
  const brands = document.querySelector('.brands');
  if (brands) {
    const imgs = [...brands.querySelectorAll('img')];
    const go = () => brands.classList.add('ready');
    Promise.all(imgs.map(i => i.complete ? null : new Promise(r => { i.addEventListener('load', r, { once: true }); i.addEventListener('error', r, { once: true }); }))).then(go);
    setTimeout(go, 4000);
  }
})();
