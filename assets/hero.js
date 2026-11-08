// LED wall graphics, drawn live: tiny pixels on dark panels with visible seams and soft light drifting across.
// <canvas data-tint="multi|orange|pink|yellow|blue|green" data-shape="wall|triptych|outdoor">
// Each canvas only animates while on screen, and stays still for people who prefer reduced motion.
(() => {
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const TAPE = { orange: [255, 95, 31], pink: [255, 45, 149], yellow: [232, 255, 26], blue: [30, 184, 255], green: [61, 255, 90] };
  const ORDER = ['orange', 'pink', 'yellow', 'green', 'blue'];

  function wall(canvas) {
    const ctx = canvas.getContext('2d');
    const tint = canvas.dataset.tint || 'multi', shape = canvas.dataset.shape || 'wall';
    const PIXEL = Number(canvas.dataset.pitch || 7), PANEL = 12;
    let w = 0, h = 0, cols = 0, rows = 0, seed = [], mask = [], visible = true, running = false;

    // Which pixels are lit LED (1) and which are the dark room (0), for each layout.
    function inside(x, y) {
      if (shape === 'triptych') {
        const gap = w * 0.04, sw = (w - gap * 4) / 3, top = h * 0.18, bottom = h * 0.78;
        if (y < top || y > bottom) return 0;
        for (let i = 0; i < 3; i++) { const l = gap + i * (sw + gap); if (x > l && x < l + sw) return 1; }
        return 0;
      }
      if (shape === 'outdoor') {
        const l = w * 0.1, r = w * 0.9, top = h * 0.12, bottom = h * 0.7;
        return x > l && x < r && y > top && y < bottom ? 1 : 0;
      }
      return 1;
    }
    function resize() {
      const dpr = Math.min(devicePixelRatio || 1, 2);
      w = canvas.clientWidth; h = canvas.clientHeight;
      canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      cols = Math.ceil(w / PIXEL) + 1; rows = Math.ceil(h / PIXEL) + 1;
      seed = Array.from({ length: cols * rows }, () => Math.random());
      mask = [];
      for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) mask.push(inside(c * PIXEL + PIXEL / 2, r * PIXEL + PIXEL / 2));
    }
    const light = (x, y, t) => {
      const a = Math.sin(x * 0.012 + t * 0.35) + Math.sin(y * 0.017 - t * 0.27);
      const b = Math.sin((x + y) * 0.008 + t * 0.21) + Math.sin(Math.hypot(x - w * 0.5, y - h * 0.35) * 0.02 - t * 0.6);
      return (a + b) * 0.25 + 0.5;
    };
    // Colour for a pixel: one tape colour, or slow bands that move through all five.
    function colourAt(x, y, t) {
      if (tint !== 'multi') return TAPE[tint] || null;
      const raw = (x / w) * 1.6 + (y / h) * 0.6 + t * 0.05 + Math.sin(y * 0.004 + t * 0.2) * 0.3;
      const p = ((raw % 1) + 1) % 1, f = p * ORDER.length, i = Math.floor(f) % ORDER.length, k = f - Math.floor(f);
      const a = TAPE[ORDER[i % ORDER.length]], b = TAPE[ORDER[(i + 1) % ORDER.length]];
      return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k];
    }
    function draw(time) {
      const t = time / 1000;
      ctx.fillStyle = '#050505'; ctx.fillRect(0, 0, w, h);
      if (shape === 'wall') {
        ctx.strokeStyle = 'rgba(255,255,255,0.05)'; ctx.lineWidth = 1;
        const step = PIXEL * PANEL; ctx.beginPath();
        for (let x = 0.5; x < w; x += step) { ctx.moveTo(x, 0); ctx.lineTo(x, h); }
        for (let y = 0.5; y < h; y += step) { ctx.moveTo(0, y); ctx.lineTo(w, y); }
        ctx.stroke();
      }
      for (let r = 0; r < rows; r++) {
        const y = r * PIXEL + PIXEL / 2;
        for (let c = 0; c < cols; c++) {
          const i = r * cols + c;
          if (!mask[i]) continue;
          const x = c * PIXEL + PIXEL / 2, s = seed[i];
          let v = Math.pow(light(x, y, t), 3) * 0.85 + s * 0.08;
          if (s > 0.9965) v = Math.max(v, 0.55 + 0.45 * Math.sin(t * 2 + s * 100));
          if (v < 0.05) continue;
          const col = colourAt(x, y, t);
          // Bright pixels lean towards white, dimmer ones show the tape colour.
          const mix = Math.min(0.6, Math.pow(v, 2.6) * 0.7), g = 40 + v * 215;
          const rr = col ? col[0] * (1 - mix) + g * mix : g, gg = col ? col[1] * (1 - mix) + g * mix : g, bb = col ? col[2] * (1 - mix) + g * mix : g;
          ctx.fillStyle = `rgb(${rr | 0},${gg | 0},${bb | 0})`; ctx.globalAlpha = Math.min(1, v * 1.4);
          ctx.fillRect(x - 1.2, y - 1.2, 2.4, 2.4);
        }
      }
      ctx.globalAlpha = 1;
    }
    function loop(time) {
      if (!visible) { running = false; return; }
      draw(time);
      setTimeout(() => requestAnimationFrame(loop), 33);
    }
    resize();
    addEventListener('resize', () => { resize(); draw(performance.now()); });
    if (still) { draw(4000); return; }
    new IntersectionObserver(([e]) => { visible = e.isIntersecting; if (visible && !running) { running = true; requestAnimationFrame(loop); } }).observe(canvas);
  }
  document.querySelectorAll('canvas[data-led], .led > canvas').forEach(wall);
})();
