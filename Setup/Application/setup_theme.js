const SETUP_THEME_KEY = 'msb-theme';
const SETUP_LIGHT_LOGO = 'https://webassets.sheboyganlights.org/images/branding/msb-blue-logo-600-plain.svg';
const SETUP_DARK_LOGO = 'https://webassets.sheboyganlights.org/images/branding/msb-white-logo-600-plain.svg';

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

function setupSyncThemeLogo() {
  const logo = document.getElementById('screen-logo');
  if (!logo) return;
  logo.src = setupCurrentTheme() === 'dark' ? SETUP_DARK_LOGO : SETUP_LIGHT_LOGO;
}

function setupConfigureTheme() {
  const saved = setupSavedTheme();
  if (saved) {
    document.documentElement.dataset.theme = saved;
  }
  setupSyncThemeButton();
  setupSyncThemeLogo();

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
    setupSyncThemeLogo();
  });
}

setupConfigureTheme();
