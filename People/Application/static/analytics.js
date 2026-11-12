// MSB People Manager - GA4 analytics loader
// Contract: System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md
// Never send a person's name, email, phone, person_id, authenticated identity,
// search text, or other Production Database record identifiers to GA4.
(function () {
  'use strict';

  const measurementId = 'G-X08ZTSY0VV';
  const analyticsVersion = '2026-09-09.1';

  window.msbPeopleAnalyticsVersion = analyticsVersion;
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () {
    window.dataLayer.push(arguments);
  };

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

  const pagePath = window.location.pathname || '/people/';
  window.gtag('event', 'page_view', {
    page_title: document.title,
    page_location: window.location.origin + pagePath,
    page_path: pagePath
  });

  const forbiddenKeys = new Set([
    'person_id', 'name', 'first_name', 'last_name', 'preferred_name',
    'email', 'personal_email', 'cell_phone', 'phone', 'user', 'identity',
    'query', 'search', 'q', 'directus_user_id', 'pg_login_name'
  ]);

  window.msbPeopleAnalyticsEvent = function (eventName, parameters) {
    if (!eventName || typeof eventName !== 'string') return;
    const safe = {};
    Object.entries(parameters || {}).forEach(([key, value]) => {
      if (!forbiddenKeys.has(String(key).toLowerCase())) safe[key] = value;
    });
    window.gtag('event', eventName, safe);
  };
})();
