// MSB Setup Session - GA4 analytics loader
// Contract: System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md
// Never send authenticated identity, query strings, Production Database record IDs,
// QR payloads, task names, filesystem paths, or raw document URLs to Google Analytics.
(function () {
  'use strict';

  const measurementId = 'G-X08ZTSY0VV';
  const analyticsVersion = '2026-09-07.1';

  window.msbSetupAnalyticsVersion = analyticsVersion;
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () {
    window.dataLayer.push(arguments);
  };

  function safePagePath() {
    // Setup requests may contain session/task/resource identifiers or other
    // operational context. Analytics receives pathname only.
    const path = window.location.pathname || '/setup/';
    if (path.endsWith('/production.html')) return path.replace(/production\.html$/, '');
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

  // Bounded anonymous workflow events only. Callers must never attach record,
  // identity, task-name, path, or document-specific values.
  window.msbSetupAnalyticsEvent = function (eventName, parameters) {
    if (!eventName || typeof eventName !== 'string') return;
    const safeParameters = Object.assign({}, parameters || {});
    delete safeParameters.setup_session_id;
    delete safeParameters.setup_session_task_id;
    delete safeParameters.setup_task_id;
    delete safeParameters.setup_resource_id;
    delete safeParameters.setup_work_day_id;
    delete safeParameters.display_id;
    delete safeParameters.container_id;
    delete safeParameters.location_id;
    delete safeParameters.location_code;
    delete safeParameters.stage_id;
    delete safeParameters.stage_key;
    delete safeParameters.scene_id;
    delete safeParameters.preview_uuid;
    delete safeParameters.scene_uuid;
    delete safeParameters.email;
    delete safeParameters.user;
    delete safeParameters.identity;
    delete safeParameters.qr;
    delete safeParameters.qr_url;
    delete safeParameters.task_name;
    delete safeParameters.name;
    delete safeParameters.path;
    delete safeParameters.url;
    delete safeParameters.document_id;
    window.gtag('event', eventName, safeParameters);
  };
})();
