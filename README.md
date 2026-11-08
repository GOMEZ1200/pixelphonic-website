# pixelphonic.co.uk

The Pixel Phonic website. Plain HTML and CSS, no build step, hosted on GitHub Pages.

- `index.html` is the home page. `stagetimer/` holds the Stage Timer product, support and privacy pages (linked from the App Store listing, so keep those URLs).
- `assets/site.css` styles every page. `assets/site.js` runs the menu, scroll effects and the years-in-AV count (from September 2010). `assets/hero.js` draws the LED-wall background.
- Preview locally: `python3 -m http.server 8731` in this folder, then open http://127.0.0.1:8731/.
- Publish: commit and push to `main`. GitHub Pages updates within a minute or two.
