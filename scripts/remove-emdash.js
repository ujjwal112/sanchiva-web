import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name === 'node_modules' || e.name === 'dist' || e.name === '.git') continue;
      walk(p, out);
    } else if (/\.(jsx?|tsx?|html|css|md|json)$/.test(e.name)) {
      out.push(p);
    }
  }
  return out;
}

const files = walk(path.join(root, 'client'))
  .concat(walk(path.join(root, 'server', 'src')))
  .concat([
    path.join(root, 'package.json'),
    path.join(root, 'README.md'),
  ].filter((f) => fs.existsSync(f)));

let count = 0;
for (const f of files) {
  let s = fs.readFileSync(f, 'utf8');
  if (!s.includes('—')) continue;
  const before = s;

  // Empty / missing value placeholders
  s = s.replace(/'—'/g, "'-'");
  s = s.replace(/"—"/g, '"-"');

  // Em dash with spaces → comma+space (readable UI prose)
  s = s.replace(/ — /g, ', ');
  // Any remaining em dash
  s = s.replace(/—/g, ', ');

  // Tidy accidental double commas
  s = s.replace(/,\s*,/g, ',');

  if (s !== before) {
    fs.writeFileSync(f, s);
    count += 1;
    console.log('updated', path.relative(root, f));
  }
}
console.log('done, files:', count);
