// MSB FieldWiring - GA4 analytics loader
// Contract: System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md
// Never send authenticated identity, QR payloads, Production Database record IDs,
// or raw query strings to Google Analytics.
(function () {
  'use strict';

  const measurementId = 'G-X08ZTSY0VV';
  const analyticsVersion = '2026-08-31.1';

  window.msbFieldWiringAnalyticsVersion = analyticsVersion;
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () {
    window.dataLayer.push(arguments);
  };

  function safePagePath() {
    // FieldWiring URLs may contain display_id, stage_id, preview_uuid, scene_uuid,
    // or other Production Database identifiers. Analytics receives pathname only.
    const path = window.location.pathname || '/fieldwiring/';
    if (path.endsWith('/controllers.html')) return path.replace(/controllers\.html$/, 'controllers');
    if (path.endsWith('/wiring.html')) return path.replace(/wiring\.html$/, 'wiring');
    if (path.endsWith('/index.html')) return path.replace(/index\.html$/, '');
    return path;
  }

  const googleTag = document.createElement('script');
  googleTag.async = true;
  googleTag.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(measurementId);
  document.head.appendChild(googleTag);

  window.gtag('js', new Date());
  window.gtag('config', measurementId, {
    send_page_view: false,
    allow_google_signals: false,
    allow_ad_personalization_signals: false
  });

  const pagePath = safePagePath();
  window.gtag('event', 'page_view', {
    page_title: document.title,
    page_location: window.location.origin + pagePath,
    page_path: pagePath
  });

  // Bounded anonymous workflow events only. Callers must never attach record IDs.
  window.msbFieldWiringAnalyticsEvent = function (eventName, parameters) {
    if (!eventName || typeof eventName !== 'string') return;
    const safeParameters = Object.assign({}, parameters || {});
    delete safeParameters.controller_id;
    delete safeParameters.display_id;
    delete safeParameters.container_id;
    delete safeParameters.location_id;
    delete safeParameters.location_code;
    delete safeParameters.preview_uuid;
    delete safeParameters.scene_uuid;
    delete safeParameters.email;
    delete safeParameters.user;
    delete safeParameters.identity;
    delete safeParameters.qr;
    delete safeParameters.qr_url;
    window.gtag('event', eventName, safeParameters);
  };
})();
