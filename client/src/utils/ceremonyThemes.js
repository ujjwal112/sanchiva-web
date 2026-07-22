/**
 * Theme (colors + quote) for each ceremony type.
 * Matched by name keywords (case-insensitive).
 * Text/quote colors are deep tints so they stay readable on light glass cards.
 */
const THEMES = {
  haldi: {
    key: 'haldi',
    label: 'Haldi',
    // Turmeric gold
    bg: 'linear-gradient(145deg, rgba(253, 224, 71, 0.72) 0%, rgba(250, 204, 21, 0.55) 55%, rgba(245, 158, 11, 0.4) 100%), #fffbeb',
    border: 'rgba(217, 119, 6, 0.45)',
    accent: '#b45309',
    text: '#78350f',
    quote: 'May turmeric bring you glow, joy, and a lifetime of blessings.',
  },
  mehendi: {
    key: 'mehendi',
    label: 'Mehendi',
    // Mehndi green
    bg: 'linear-gradient(145deg, rgba(134, 239, 172, 0.65) 0%, rgba(74, 222, 128, 0.48) 55%, rgba(34, 197, 94, 0.35) 100%), #f0fdf4',
    border: 'rgba(22, 163, 74, 0.4)',
    accent: '#15803d',
    text: '#14532d',
    quote: 'Every leaf of mehendi is a wish for love that lasts forever.',
  },
  sangeet: {
    key: 'sangeet',
    label: 'Sangeet',
    // Festive purple / magenta
    bg: 'linear-gradient(145deg, rgba(216, 180, 254, 0.7) 0%, rgba(192, 132, 252, 0.5) 50%, rgba(244, 114, 182, 0.35) 100%), #faf5ff',
    border: 'rgba(147, 51, 234, 0.4)',
    accent: '#7e22ce',
    text: '#581c87',
    quote: 'Dance like the music was written for your forever.',
  },
  tilak: {
    key: 'tilak',
    label: 'Tilak',
    // Saffron / vermillion
    bg: 'linear-gradient(145deg, rgba(253, 186, 116, 0.72) 0%, rgba(251, 146, 60, 0.5) 55%, rgba(249, 115, 22, 0.35) 100%), #fff7ed',
    border: 'rgba(234, 88, 12, 0.4)',
    accent: '#c2410c',
    text: '#7c2d12',
    quote: 'A sacred mark of blessing as two families join in joy.',
  },
  engagement: {
    key: 'engagement',
    label: 'Engagement',
    // Soft rose / pink
    bg: 'linear-gradient(145deg, rgba(251, 207, 232, 0.75) 0%, rgba(244, 114, 182, 0.45) 55%, rgba(251, 113, 133, 0.32) 100%), #fdf2f8',
    border: 'rgba(219, 39, 119, 0.35)',
    accent: '#be185d',
    text: '#9d174d',
    quote: 'Two hearts, one promise, a beautiful lifetime ahead.',
  },
  wedding: {
    key: 'wedding',
    label: 'Main Wedding',
    // Deep maroon / red
    bg: 'linear-gradient(145deg, rgba(252, 165, 165, 0.7) 0%, rgba(251, 113, 133, 0.5) 50%, rgba(190, 24, 93, 0.35) 100%), #fff1f2',
    border: 'rgba(190, 24, 93, 0.4)',
    accent: '#9f1239',
    text: '#881337',
    quote: 'Today we begin a beautiful forever, hand in hand.',
  },
  reception: {
    key: 'reception',
    label: 'Reception',
    // Royal navy / blue
    bg: 'linear-gradient(145deg, rgba(147, 197, 253, 0.7) 0%, rgba(96, 165, 250, 0.5) 55%, rgba(59, 130, 246, 0.35) 100%), #eff6ff',
    border: 'rgba(37, 99, 235, 0.4)',
    accent: '#1d4ed8',
    text: '#1e3a8a',
    quote: 'Celebrating love with the ones who matter most.',
  },
  nikah: {
    key: 'nikah',
    label: 'Nikah',
    // Emerald green
    bg: 'linear-gradient(145deg, rgba(110, 231, 183, 0.68) 0%, rgba(52, 211, 153, 0.48) 55%, rgba(16, 185, 129, 0.35) 100%), #ecfdf5',
    border: 'rgba(5, 150, 105, 0.4)',
    accent: '#047857',
    text: '#064e3b',
    quote: 'May faith and love guide every step of your journey together.',
  },
  walima: {
    key: 'walima',
    label: 'Walima',
    // Warm gold
    bg: 'linear-gradient(145deg, rgba(253, 230, 138, 0.72) 0%, rgba(251, 191, 36, 0.5) 55%, rgba(245, 158, 11, 0.35) 100%), #fffbeb',
    border: 'rgba(217, 119, 6, 0.4)',
    accent: '#b45309',
    text: '#78350f',
    quote: 'May this feast of joy mark the start of endless happiness.',
  },
  default: {
    key: 'default',
    label: 'Ceremony',
    bg: 'linear-gradient(145deg, rgba(196, 181, 253, 0.68) 0%, rgba(167, 139, 250, 0.48) 55%, rgba(34, 211, 238, 0.28) 100%), #f5f3ff',
    border: 'rgba(124, 58, 237, 0.35)',
    accent: '#6d28d9',
    text: '#4c1d95',
    quote: 'Celebrating this special moment with love, laughter, and joy.',
  },
};

function matchKey(name = '') {
  const n = String(name).toLowerCase().trim();
  if (!n) return 'default';
  if (n.includes('haldi') || n.includes('pithi')) return 'haldi';
  if (n.includes('mehend') || n.includes('mehndi') || n.includes('henna')) return 'mehendi';
  if (n.includes('sangeet') || n.includes('garba') || n.includes('dj')) return 'sangeet';
  if (n.includes('tilak')) return 'tilak';
  if (n.includes('engag') || n.includes('roka') || n.includes('sagai')) return 'engagement';
  if (n.includes('nikah') || n.includes('nikaah')) return 'nikah';
  if (n.includes('walima') || n.includes('mehfil')) return 'walima';
  if (n.includes('reception') || n.includes('party')) return 'reception';
  if (
    n.includes('wedding') ||
    n.includes('shaadi') ||
    n.includes('vivah') ||
    n.includes('phere') ||
    n.includes('main')
  ) {
    return 'wedding';
  }
  return 'default';
}

/** Resolve full theme for a ceremony name */
export function getCeremonyTheme(name) {
  const key = matchKey(name);
  const t = THEMES[key] || THEMES.default;
  return { ...t, name: name || t.label };
}

export function getCeremonyQuote(name) {
  return getCeremonyTheme(name).quote;
}

function ceremonyDateValue(date) {
  if (!date) return null;
  const t = new Date(date).getTime();
  return Number.isNaN(t) ? null : t;
}

/**
 * Build display cards from API ceremony_details / ceremonies.
 * Sorted by date ascending; ceremonies without a date appear last.
 * @param {{ name: string, date?: string, quote?: string }[]} details
 */
export function buildCeremonyCards(details = []) {
  return (details || [])
    .filter((d) => d && d.name && String(d.name).toLowerCase() !== 'general' && d.name !== 'Other')
    .map((d) => {
      const theme = getCeremonyTheme(d.name);
      return {
        name: d.name,
        date: d.date || null,
        quote: d.quote || theme.quote,
        theme,
      };
    })
    .sort((a, b) => {
      const ta = ceremonyDateValue(a.date);
      const tb = ceremonyDateValue(b.date);
      if (ta == null && tb == null) return String(a.name).localeCompare(String(b.name));
      if (ta == null) return 1; // no date → end
      if (tb == null) return -1;
      if (ta !== tb) return ta - tb;
      return String(a.name).localeCompare(String(b.name));
    });
}
