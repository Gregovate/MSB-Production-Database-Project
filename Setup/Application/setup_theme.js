const SETUP_THEME_KEY = 'msb-theme';

function setupSavedTheme() {
  try {
    const value = localStorage.getItem(SETUP_THEME_KEY);
    return value === 'light' || value === 'dark' ? value : null;
  } catch (_error) {
    return null;
  }
}

function setupCurrentTheme() {
  if (document.documentElement.dataset.theme) {
    return document.documentElement.dataset.theme;
  }
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function setupSyncThemeButton() {
  const button = document.getElementById('theme-toggle');
  if (!button) return;
  button.textContent = setupCurrentTheme() === 'dark' ? 'Light mode' : 'Dark mode';
}

function setupConfigureTheme() {
  const saved = setupSavedTheme();
  if (saved) {
    document.documentElement.dataset.theme = saved;
  }
  setupSyncThemeButton();

  const button = document.getElementById('theme-toggle');
  if (!button) return;
  button.addEventListener('click', () => {
    const next = setupCurrentTheme() === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem(SETUP_THEME_KEY, next);
    } catch (_error) {
      // Theme still applies for this page even if storage is unavailable.
    }
    setupSyncThemeButton();
  });
}

setupConfigureTheme();
