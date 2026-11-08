// Page behaviour: menu, top bar, reveals and Apple-style scroll effects. Everything degrades to a normal page.
(() => {
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Years in AV, counted from September 2010, so it never goes out of date.
  const start = new Date(2010, 8, 1), now = new Date();
  const years = now.getFullYear() - start.getFullYear() - (now < new Date(now.getFullYear(), 8, 1) ? 1 : 0);
  document.querySelectorAll('[data-years]').forEach(el => { el.textContent = years; });

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
    words.slice(-2).forEach(w => w.classList.add('hl'));
  }

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
})();
