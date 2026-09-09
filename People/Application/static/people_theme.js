(function () {
  'use strict';

  const THEME_KEY = 'msb-theme';

  function savedTheme() {
    try {
      const value = localStorage.getItem(THEME_KEY);
      return value === 'light' || value === 'dark' ? value : null;
    } catch (_error) {
      return null;
    }
  }

  function currentTheme() {
    if (document.documentElement.dataset.theme) {
      return document.documentElement.dataset.theme;
    }
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function syncThemeButton() {
    const button = document.getElementById('theme-toggle');
    if (!button) return;
    button.textContent = currentTheme() === 'dark' ? 'Light mode' : 'Dark mode';
  }

  function configureTheme() {
    const saved = savedTheme();
    if (saved) {
      document.documentElement.dataset.theme = saved;
    }
    syncThemeButton();

    const button = document.getElementById('theme-toggle');
    if (!button) return;
    button.addEventListener('click', () => {
      const next = currentTheme() === 'dark' ? 'light' : 'dark';
      document.documentElement.dataset.theme = next;
      try {
        localStorage.setItem(THEME_KEY, next);
      } catch (_error) {
        // Theme still applies for this page even if storage is unavailable.
      }
      syncThemeButton();
    });
  }

  configureTheme();
})();
