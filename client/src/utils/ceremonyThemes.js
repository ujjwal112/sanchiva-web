/**
 * Theme (colors + quote) for each ceremony type.
 * Matched by name keywords (case-insensitive).
 */
const THEMES = {
  haldi: {
    key: 'haldi',
    label: 'Haldi',
    // Turmeric gold / yellow
    bg: 'linear-gradient(145deg, rgba(234, 179, 8, 0.28), rgba(202, 138, 4, 0.18))',
    border: 'rgba(234, 179, 8, 0.55)',
    accent: '#fbbf24',
    text: '#fef3c7',
    quote: 'May turmeric bring you glow, joy, and a lifetime of blessings.',
  },
  mehendi: {
    key: 'mehendi',
    label: 'Mehendi',
    // Mehndi green
    bg: 'linear-gradient(145deg, rgba(34, 197, 94, 0.25), rgba(22, 101, 52, 0.2))',
    border: 'rgba(74, 222, 128, 0.5)',
    accent: '#4ade80',
    text: '#dcfce7',
    quote: 'Every leaf of mehendi is a wish for love that lasts forever.',
  },
  sangeet: {
    key: 'sangeet',
    label: 'Sangeet',
    // Festive purple / magenta
    bg: 'linear-gradient(145deg, rgba(168, 85, 247, 0.28), rgba(219, 39, 119, 0.18))',
    border: 'rgba(192, 132, 252, 0.55)',
    accent: '#c084fc',
    text: '#f3e8ff',
    quote: 'Dance like the music was written for your forever.',
  },
  tilak: {
    key: 'tilak',
    label: 'Tilak',
    // Saffron / vermillion
    bg: 'linear-gradient(145deg, rgba(249, 115, 22, 0.28), rgba(194, 65, 12, 0.18))',
    border: 'rgba(251, 146, 60, 0.55)',
    accent: '#fb923c',
    text: '#ffedd5',
    quote: 'A sacred mark of blessing as two families join in joy.',
  },
  engagement: {
    key: 'engagement',
    label: 'Engagement',
    // Soft rose / pink
    bg: 'linear-gradient(145deg, rgba(244, 114, 182, 0.28), rgba(251, 113, 133, 0.16))',
    border: 'rgba(244, 114, 182, 0.5)',
    accent: '#f472b6',
    text: '#fce7f3',
    quote: 'Two hearts, one promise, a beautiful lifetime ahead.',
  },
  wedding: {
    key: 'wedding',
    label: 'Main Wedding',
    // Deep maroon / red
    bg: 'linear-gradient(145deg, rgba(190, 24, 93, 0.3), rgba(127, 29, 29, 0.22))',
    border: 'rgba(251, 113, 133, 0.55)',
    accent: '#fb7185',
    text: '#ffe4e6',
    quote: 'Today we begin a beautiful forever, hand in hand.',
  },
  reception: {
    key: 'reception',
    label: 'Reception',
    // Royal navy / blue
    bg: 'linear-gradient(145deg, rgba(59, 130, 246, 0.28), rgba(30, 58, 138, 0.22))',
    border: 'rgba(96, 165, 250, 0.55)',
    accent: '#60a5fa',
    text: '#dbeafe',
    quote: 'Celebrating love with the ones who matter most.',
  },
  nikah: {
    key: 'nikah',
    label: 'Nikah',
    // Emerald green
    bg: 'linear-gradient(145deg, rgba(16, 185, 129, 0.28), rgba(6, 78, 59, 0.22))',
    border: 'rgba(52, 211, 153, 0.55)',
    accent: '#34d399',
    text: '#d1fae5',
    quote: 'May faith and love guide every step of your journey together.',
  },
  walima: {
    key: 'walima',
    label: 'Walima',
    // Warm gold
    bg: 'linear-gradient(145deg, rgba(245, 158, 11, 0.28), rgba(180, 83, 9, 0.2))',
    border: 'rgba(251, 191, 36, 0.55)',
    accent: '#fbbf24',
    text: 'May this feast of joy mark the start of endless happiness.',
  },
  default: {
    key: 'default',
    label: 'Ceremony',
    bg: 'linear-gradient(145deg, rgba(124, 108, 255, 0.28), rgba(34, 211, 238, 0.14))',
    border: 'rgba(124, 108, 255, 0.45)',
    accent: '#a78bfa',
    text: '#ede9fe',
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
