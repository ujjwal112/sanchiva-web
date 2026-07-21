import fs from 'fs';

const p = 'client/src/index.css';
let s = fs.readFileSync(p, 'utf8');

const pairs = [
  [/var\(--color-paper-white\)/g, 'var(--color-paper)'],
  [/var\(--color-vault-ink\)/g, 'var(--color-obsidian)'],
  [/var\(--color-mist-white\)/g, 'var(--color-paper)'],
  [/var\(--color-hairline\)/g, 'rgba(0, 0, 0, 0.12)'],
  [/var\(--color-fog-gray\)/g, 'var(--color-felt-gray)'],
  [/var\(--color-deep-teal\)/g, 'var(--color-obsidian)'],
  [/var\(--color-electric-violet\)/g, 'var(--color-slate-pill)'],
  [/var\(--color-sapphire-blue\)/g, 'var(--color-pewter)'],
  [/var\(--color-peach-wall\)/g, '#f5f5f5'],
  [/var\(--color-mint-wall\)/g, '#f0f0f0'],
  [/var\(--color-lavender-wall\)/g, '#ebebeb'],
  [/var\(--color-midnight-tide\)/g, 'var(--color-inkstone)'],
  [/var\(--color-pure-light\)/g, 'var(--color-paper)'],
  [/var\(--color-forest-depths\)/g, 'var(--color-obsidian)'],
];
for (const [a, b] of pairs) s = s.replace(a, b);

// Landing header monochrome ghost pills on iridescent dark
s = s.replace(
  /\.landing-brand-text strong \{[\s\S]*?\.landing-header \.btn-primary:hover \{[\s\S]*?\}/,
  `.landing-brand-text strong {
  font-family: var(--font);
  font-size: 16px;
  font-weight: 400;
  letter-spacing: normal;
  color: var(--color-paper);
}

.landing-brand-text span {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.65);
}

.landing-header .btn-ghost {
  border-color: rgba(255, 255, 255, 0.3);
  color: var(--color-paper);
  background: transparent;
  border-radius: 75px;
}

.landing-header .btn-ghost:hover {
  background: transparent;
  border-color: var(--color-paper);
  color: var(--color-paper);
}

.landing-header .btn-primary {
  background: transparent;
  border: 1px solid rgba(255, 255, 255, 0.3);
  color: var(--color-paper);
  border-radius: 75px;
}

.landing-header .btn-primary:hover {
  background: var(--color-paper);
  color: var(--color-obsidian);
  border-color: var(--color-paper);
}`
);

// Hero type whisper
s = s.replace(
  /\.landing-hero h1 \{[\s\S]*?\.landing-lead \{[\s\S]*?font-weight: 400;\n\}/,
  `.landing-hero h1 {
  font-family: var(--font);
  font-size: clamp(2.5rem, 8vw, 5.5rem);
  font-weight: 300;
  letter-spacing: normal;
  line-height: 1.1;
  margin-bottom: 0.85rem;
  color: var(--color-paper);
}

.landing-hero-accent {
  color: rgba(255, 255, 255, 0.88);
  background: none;
  -webkit-background-clip: unset;
  background-clip: unset;
  font-weight: 300;
}

.landing-lead {
  font-size: 16px;
  max-width: 36rem;
  margin-bottom: 1.35rem;
  color: rgba(255, 255, 255, 0.72);
  font-weight: 400;
}`
);

// Login card monochrome paper on dark
s = s.replace(
  /\.login-card \{[\s\S]*?color: var\(--color-obsidian\);\n\}/,
  `.login-card {
  width: min(420px, 100%);
  padding: 2rem 1.75rem !important;
  text-align: center;
  background: var(--color-paper) !important;
  border: 1px solid rgba(0, 0, 0, 0.1) !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  color: var(--color-obsidian);
}`
);

s = s.replace(
  /\.login-brand h1 \{[\s\S]*?background-clip: unset;\n\}/,
  `.login-brand h1 {
  font-family: var(--font);
  font-size: 1.85rem;
  font-weight: 300;
  letter-spacing: normal;
  color: var(--color-obsidian);
  background: none;
  -webkit-background-clip: unset;
  background-clip: unset;
}`
);

// Login buttons
s = s.replace(
  /\.login-btn \{[\s\S]*?\.login-btn\.btn-primary:hover:not\(:disabled\),[\s\S]*?filter: none;/,
  `.login-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.65rem;
  width: 100%;
  min-height: 48px;
  border-radius: 75px;
  font-weight: 400;
  border: 1px solid var(--color-obsidian);
  background: transparent;
  color: var(--color-obsidian);
  transition: transform 0.9s var(--ease-glide), background 0.9s var(--ease-glide), color 0.9s var(--ease-glide);
  box-shadow: none;
}

.login-btn:hover:not(:disabled) {
  transform: scale(1.02);
  background: var(--color-obsidian);
  color: var(--color-paper);
  box-shadow: none;
}

.login-btn.btn-primary,
.btn-primary.login-btn {
  background: transparent;
  border-color: var(--color-obsidian);
  color: var(--color-obsidian);
}

.login-btn.btn-primary:hover:not(:disabled),
.btn-primary.login-btn:hover:not(:disabled) {
  background: var(--color-obsidian);
  color: var(--color-paper);
  filter: none;`
);

// Feature cards monochrome
s = s.replace(
  /\.landing-feature-card:nth-child\(3n \+ 1\) \{[\s\S]*?\.landing-feature-card h3 \{[\s\S]*?\}/,
  `.landing-feature-card:nth-child(3n + 1),
.landing-feature-card:nth-child(3n + 2),
.landing-feature-card:nth-child(3n) {
  background: var(--color-paper) !important;
  border: 1px solid rgba(0, 0, 0, 0.1) !important;
}

.landing-feature-card h3 {
  color: var(--color-obsidian) !important;
  font-weight: 400 !important;
  font-family: var(--font) !important;
}`
);

// CTA panel
s = s.replace(
  /\.landing-cta-panel \{[\s\S]*?\.landing-cta-panel h3 \{[\s\S]*?\}/,
  `.landing-cta-panel {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.55rem;
  padding: 2rem;
  border-radius: 0;
  background: var(--color-paper);
  border: 1px solid rgba(0, 0, 0, 0.1);
  box-shadow: none;
  color: var(--color-obsidian);
}

.landing-cta-panel h3 {
  color: var(--color-obsidian);
  font-weight: 300;
  font-family: var(--font);
}`
);

// Section headings on light
s = s.replace(
  /\.landing-section-head h2 \{[\s\S]*?color: var\(--color-obsidian\);/,
  `.landing-section-head h2 {
  font-family: var(--font);
  font-size: clamp(1.75rem, 4vw, 3rem);
  font-weight: 300;
  letter-spacing: normal;
  margin-bottom: 0.35rem;
  color: var(--color-obsidian);`
);

// Auth chip
s = s.replace(
  /\.auth-email-chip \{[\s\S]*?color: var\(--color-obsidian\);\n\}/,
  `.auth-email-chip {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.45rem 0.65rem;
  margin-bottom: 0.85rem;
  padding: 0.65rem 0.8rem;
  border-radius: 0;
  background: #f5f5f5;
  border: 1px solid rgba(0, 0, 0, 0.1);
  font-size: 0.9rem;
  color: var(--color-obsidian);
}`
);

// User menu
s = s.replace(
  /\.user-menu-dropdown \{[\s\S]*?color: var\(--color-obsidian\);/,
  `.user-menu-dropdown {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  left: auto;
  min-width: 220px;
  padding: 0.85rem;
  border-radius: 0;
  background: var(--color-paper);
  border: 1px solid rgba(0, 0, 0, 0.12);
  box-shadow: none;
  backdrop-filter: none;
  animation: rise-in 0.8s var(--ease-glide);
  color: var(--color-obsidian);`
);

// Progress bar monochrome
s = s.replace(
  /\.progress-bar > span \{[\s\S]*?box-shadow: none;\n\}/,
  `.progress-bar > span {
  display: block;
  height: 100%;
  background: var(--color-obsidian);
  border-radius: 0;
  transition: width 0.9s var(--ease-glide);
  box-shadow: none;
}`
);

// Charts-safe badge success etc stay muted grays
s = s.replace(/\.badge\.success \{[\s\S]*?\.badge\.danger \{[\s\S]*?color: #[a-f0-9]+;\n\}/i, 
`.badge.success {
  background: transparent;
  border-color: rgba(0, 0, 0, 0.2);
  color: var(--color-inkstone);
}

.badge.warning {
  background: transparent;
  border-color: rgba(0, 0, 0, 0.2);
  color: var(--color-felt-gray);
}

.badge.danger {
  background: transparent;
  border-color: var(--danger);
  color: var(--danger);
}`);

// Chip
s = s.replace(
  /\.chip \{[\s\S]*?\.chip\.selected \{[\s\S]*?\}/,
  `.chip {
  padding: 0.4rem 1rem;
  border-radius: 75px;
  border: 1px solid rgba(0, 0, 0, 0.15);
  background: transparent;
  color: var(--color-obsidian);
  font-size: 0.85rem;
  font-weight: 400;
  transition: all 0.8s var(--ease-glide);
}

.chip.selected {
  background: var(--color-obsidian);
  border-color: var(--color-obsidian);
  color: var(--color-paper);
  box-shadow: none;
}`
);

// Landing section head on dark vs light - features section is after hero so light
// Footer light
s = s.replace(
  /\.landing-footer \{[\s\S]*?margin-top: auto;\n\}/,
  `.landing-footer {
  border-top: 1px solid rgba(255, 255, 255, 0.15);
  padding: 1.25rem 1.5rem 1.75rem;
  margin-top: auto;
  color: rgba(255, 255, 255, 0.7);
}

.landing-page .landing-section .muted {
  color: var(--color-felt-gray);
}

.landing-page .landing-main > .landing-section:not(:first-child) {
  color: var(--color-obsidian);
}

/* Light content band after hero */
.landing-page .landing-main {
  width: min(1078px, 100%);
}

.landing-page .landing-section .landing-section-head h2,
.landing-page .landing-about-block h2 {
  color: var(--color-obsidian);
}

.landing-footer .muted {
  color: rgba(255, 255, 255, 0.55);
}

.landing-footer-login {
  color: var(--color-paper) !important;
}`
);

// password peek monochrome
s = s.replace(
  /\.password-peek-btn:hover \{[\s\S]*?\}/,
  `.password-peek-btn:hover {
  background: rgba(0, 0, 0, 0.06);
  color: var(--color-obsidian);
}`
);

fs.writeFileSync(p, s);
console.log('monopo css applied');
