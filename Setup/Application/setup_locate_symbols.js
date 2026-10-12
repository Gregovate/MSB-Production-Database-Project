/* #171 Park Map: reviewed GPX type -> canonical Plain SVG filename.
 * This is presentation-only. Preserve source marker_url/type/Label on Map,
 * geometry, and historical GPX URLs in PostGIS and ExpertGPS exports.
 *
 * File identities are the approved lowercase Plain outputs; no guess from
 * waypoint labels. Types without an approved mapping remain map circles.
 */
(() => {
  'use strict';
  const BASE = 'https://webassets.sheboyganlights.org/images/symbols/msb-svg/';
  const TYPE_TO_SVG = Object.freeze({
    'Panel': 'panel.svg',
    'OUT-Combo': 'outlet-combo.svg',
    'Camera': 'ip-camera.svg',
    'Outlet Power': 'outlet-power.svg',
    'Drop Point': 'kit-box.svg',
    'Hydrant': 'fire-hydrant.svg',
    'Light Pole': 'lp.svg',
    'LP-Combo': 'lp-combo.svg',
    'LP-Network': 'lp-network.svg',
    'LP-Power': 'lp-outlet.svg',
    'Manhole': 'manhole.svg',
    'T-Post': 't-post.svg',
    'Transformer': 'transformer.svg',
    'Stage': 'stage.svg',
    'Flag': 'pole-yellow.svg',
    'Controller': 'lor-controller.svg'
  });
  const sizes = new Map();
  const errors = new Set();

  function imageSize(filename) {
    if (!sizes.has(filename)) {
      sizes.set(filename, new Promise(resolve => {
        const image = new Image();
        let completed = false;
        const finish = size => {
          if (completed) return;
          completed = true;
          clearTimeout(timeout);
          if (!size) errors.add(filename);
          resolve(size);
        };
        const timeout = setTimeout(() => finish(null), 15000);
        image.onload = () => {
          const w = image.naturalWidth, h = image.naturalHeight;
          // The icon library validates each native canvas axis as 1..32px.
          finish(Number.isInteger(w) && Number.isInteger(h) &&
            w >= 1 && w <= 32 && h >= 1 && h <= 32 ? [w, h] : null);
        };
        image.onerror = () => finish(null);
        image.src = BASE + filename;
      }));
    }
    return sizes.get(filename);
  }

  function placeholder(offset = 0) {
    return L.divIcon({
      className: 'msb-reference-placeholder',
      html: '<span aria-hidden="true"></span>',
      iconSize: [12, 12],
      iconAnchor: [6, 6 + offset]
    });
  }

  function setSymbol(marker, type, options = {}) {
    const filename = TYPE_TO_SVG[type];
    if (!filename || !marker || typeof marker.setIcon !== 'function') return false;
    const offset = Number(options.yOffset) || 0;
    marker.setIcon(placeholder(offset));
    imageSize(filename).then(size => {
      if (!size) return;  // Explicit fallback; never show a broken image icon.
      const [width, height] = size;
      marker.setIcon(L.icon({
        iconUrl: BASE + filename,
        iconSize: [width, height],            // Never stretch to 32 x 32.
        iconAnchor: [width / 2, height / 2 + offset],
        popupAnchor: [0, -height / 2 - offset],
        className: 'msb-reference-icon'
      }));
    });
    return true;
  }

  function marker(xy, type, options = {}) {
    if (!TYPE_TO_SVG[type]) {
      return L.circleMarker(xy, {radius: 5, color: '#444', weight: 1, fillOpacity: .8});
    }
    const item = L.marker(xy, {icon: placeholder(Number(options.yOffset) || 0),
      zIndexOffset: Number(options.zIndexOffset) || 0});
    setSymbol(item, type, options);
    return item;
  }

  window.msbReferenceSymbols = Object.freeze({
    marker,
    setSymbol,
    has: type => Object.prototype.hasOwnProperty.call(TYPE_TO_SVG, type),
    urlFor: type => TYPE_TO_SVG[type] ? BASE + TYPE_TO_SVG[type] : null,
    urls: () => [...new Set(Object.values(TYPE_TO_SVG))].map(name => BASE + name),
    errors: () => [...errors]
  });
})();
