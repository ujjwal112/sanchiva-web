import { Capacitor } from '@capacitor/core';
import { API_ORIGIN } from '../api';

export function isNativeApp() {
  try {
    if (typeof Capacitor?.isNativePlatform === 'function' && Capacitor.isNativePlatform()) {
      return true;
    }
  } catch {
    /* ignore */
  }
  try {
    // Remote WebView still injects window.Capacitor
    return !!(window.Capacitor && window.Capacitor.isNativePlatform?.());
  } catch {
    return false;
  }
}

function parseOAuthCallbackUrl(url) {
  if (!url || typeof url !== 'string') return null;

  // sanchiva://auth/callback?...  OR  intent leftovers
  const isOurDeepLink =
    url.startsWith('sanchiva://auth/callback') ||
    url.includes('://auth/callback') ||
    /sanchiva:\/\/auth\/callback/i.test(url);

  if (!isOurDeepLink && !url.includes('access_token=')) {
    return null;
  }

  try {
    const qIndex = url.indexOf('?');
    const qs = qIndex >= 0 ? url.slice(qIndex + 1).split('#')[0] : '';
    const params = new URLSearchParams(qs);
    const error = params.get('error');
    const access = params.get('access_token');
    const refresh = params.get('refresh_token');

    if (error) {
      return { error: decodeURIComponent(error) };
    }
    if (!access || !refresh) {
      // Not an auth callback we understand
      if (!isOurDeepLink) return null;
      return { error: 'Missing tokens from Google login' };
    }
    return { access, refresh };
  } catch (e) {
    return { error: e.message || 'Failed to complete login' };
  }
}

/**
 * Start Google (or other) OAuth in the system browser (Custom Tabs).
 * After success the server returns an HTML bridge that opens
 * sanchiva://auth/callback?... which re-opens this APK.
 */
export async function openNativeOAuth(provider = 'google') {
  const base = API_ORIGIN || window.location.origin;
  const url = `${base}/api/auth/${provider}?client=android`;

  try {
    const { Browser } = await import('@capacitor/browser');
    await Browser.open({
      url,
      presentationStyle: 'popover',
    });
  } catch (e) {
    // Last resort: open in external browser / WebView navigation
    console.warn('Browser plugin failed, falling back to location', e);
    window.location.href = url;
  }
}

/**
 * Listen for deep-link return from browser OAuth.
 * Also handles cold-start when the app was opened by the deep link.
 * Returns an unsubscribe function.
 */
export async function listenNativeOAuthReturn(onResult) {
  if (!isNativeApp()) return () => {};

  const { App } = await import('@capacitor/app');
  const { Browser } = await import('@capacitor/browser');

  const handleUrl = async (url) => {
    const result = parseOAuthCallbackUrl(url);
    if (!result) return;

    try {
      await Browser.close();
    } catch {
      /* browser may already be closed */
    }

    onResult(result);
  };

  // Cold start: app launched via deep link while not running
  try {
    const launch = await App.getLaunchUrl();
    if (launch?.url) {
      // slight delay so AuthProvider is ready
      setTimeout(() => handleUrl(launch.url), 50);
    }
  } catch {
    /* ignore */
  }

  const handler = await App.addListener('appUrlOpen', async ({ url }) => {
    await handleUrl(url);
  });

  return () => {
    try {
      handler.remove();
    } catch {
      /* ignore */
    }
  };
}
