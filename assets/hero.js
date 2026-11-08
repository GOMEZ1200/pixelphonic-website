// LED wall backgrounds (hero and contact): tiny black-and-white pixels on dark panels with visible seams,
// soft light drifting across. Each canvas only animates while on screen, and stays still for reduced motion.
(() => {
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const PIXEL = 7, PANEL = 12;

  function wall(canvas) {
    const ctx = canvas.getContext('2d');
    let w = 0, h = 0, cols = 0, rows = 0, seed = [], visible = true, running = false;
    function resize() {
      const dpr = Math.min(devicePixelRatio || 1, 2);
      w = canvas.clientWidth; h = canvas.clientHeight;
      canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      cols = Math.ceil(w / PIXEL) + 1; rows = Math.ceil(h / PIXEL) + 1;
      seed = Array.from({ length: cols * rows }, () => Math.random());
    }
    const light = (x, y, t) => {
      const a = Math.sin(x * 0.012 + t * 0.35) + Math.sin(y * 0.017 - t * 0.27);
      const b = Math.sin((x + y) * 0.008 + t * 0.21) + Math.sin(Math.hypot(x - w * 0.5, y - h * 0.35) * 0.02 - t * 0.6);
      return (a + b) * 0.25 + 0.5;
    };
    function draw(time) {
      const t = time / 1000;
      ctx.fillStyle = '#050505'; ctx.fillRect(0, 0, w, h);
      ctx.strokeStyle = 'rgba(255,255,255,0.05)'; ctx.lineWidth = 1;
      const step = PIXEL * PANEL; ctx.beginPath();
      for (let x = 0.5; x < w; x += step) { ctx.moveTo(x, 0); ctx.lineTo(x, h); }
      for (let y = 0.5; y < h; y += step) { ctx.moveTo(0, y); ctx.lineTo(w, y); }
      ctx.stroke();
      for (let r = 0; r < rows; r++) {
        const y = r * PIXEL + PIXEL / 2;
        for (let c = 0; c < cols; c++) {
          const x = c * PIXEL + PIXEL / 2, s = seed[r * cols + c];
          let v = Math.pow(light(x, y, t), 3) * 0.8 + s * 0.08;
          if (s > 0.9965) v = Math.max(v, 0.55 + 0.45 * Math.sin(t * 2 + s * 100));
          if (v < 0.05) continue;
          const g = Math.round(40 + v * 215);
          ctx.fillStyle = `rgb(${g},${g},${g})`; ctx.globalAlpha = Math.min(1, v * 1.4);
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
  document.querySelectorAll('.led canvas').forEach(wall);
})();
