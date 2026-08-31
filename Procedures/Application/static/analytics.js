// MSB Procedures - GA4 analytics loader
// Contract: System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md
// Never send authenticated identity, Procedure query strings, Production Database
// record identifiers, QR payloads, or raw document URLs to Google Analytics.
(function () {
  'use strict';

  const measurementId = 'G-X08ZTSY0VV';
  const analyticsVersion = '2026-08-31.1';

  window.msbProcedureAnalyticsVersion = analyticsVersion;
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () {
    window.dataLayer.push(arguments);
  };

  function safePagePath() {
    // Procedure URLs may contain display_id, stage_id, preview_uuid, scene_uuid,
    // task, asset name, or other selection-specific values. Analytics receives
    // only the application pathname.
    const path = window.location.pathname || '/procedures/';
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

  // Bounded anonymous workflow events only. The helper strips identifiers even
  // if a future caller supplies them accidentally.
  window.msbProcedureAnalyticsEvent = function (eventName, parameters) {
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
    delete safeParameters.name;
    delete safeParameters.path;
    delete safeParameters.url;
    window.gtag('event', eventName, safeParameters);
  };
})();
