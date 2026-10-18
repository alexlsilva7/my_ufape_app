const fs = require('node:fs');
const path = require('node:path');
const dotenv = require('dotenv');
const root = path.resolve(__dirname, '../..');
const values = dotenv.parse(fs.readFileSync(path.join(root, '.env')));
const key = values.VITE_SUPABASE_PUBLISHABLE_KEY || '';
let safe = key.startsWith('sb_publishable_');
if (key.split('.').length === 3) {
  try { safe = JSON.parse(Buffer.from(key.split('.')[1], 'base64url').toString()).role === 'anon'; } catch {}
}
if (!safe) throw Error('Configure uma chave pública Supabase válida no ambiente do site.');
const target = path.join(root, 'flutter/.env');
const current = fs.existsSync(target) ? dotenv.parse(fs.readFileSync(target)) : {};
// Only PUBLIC build values are copied. Server credentials never enter Flutter.
const configuration = {
  DATA_SOURCE: current.DATA_SOURCE || 'local',
  SUPABASE_URL: values.VITE_SUPABASE_URL,
  SUPABASE_PUBLISHABLE_KEY: key,
  API_BASE_URL: current.API_BASE_URL || 'https://bcc-ufape.vercel.app',
  APP_VERSION: current.APP_VERSION || 'flutter-1.0.0'
};
fs.writeFileSync(target, Object.entries(configuration)
  .map(([name, value]) => `${name}=${JSON.stringify(value || '')}`).join('\n') + '\n');
console.log('Configuração pública preparada em flutter/.env (arquivo ignorado pelo Git).');
