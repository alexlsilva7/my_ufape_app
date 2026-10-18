import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

// Reproducible JSON seeds for the default local provider and remote fallback.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const source = path.resolve(root, process.argv[2] || '.backup/src/data');
const output = path.join(root, 'flutter/assets');
const read = p => JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, ''));
fs.mkdirSync(path.join(output, 'data'), {recursive:true});
const courses = read(path.join(source, 'courses_registry.json'));
fs.writeFileSync(path.join(output, 'data/courses.json'), JSON.stringify({courses}));
for (const course of courses) {
  const dir = path.join(source, course.id);
  if (!fs.existsSync(dir)) continue;
  const files = fs.readdirSync(dir);
  const curriculum = files.find(f => f.startsWith('curriculo_') && f.endsWith('.json'));
  const contents = files.find(f => f.startsWith('conteudos_') && f.endsWith('.json'));
  const schedules = {};
  for (const file of files.filter(f => f.startsWith('horario_') && f.endsWith('.json'))) {
    const match = file.match(/_(\d{4})_(\d)\.json$/);
    if (!match) continue;
    const raw = read(path.join(dir,file));
    schedules[`${match[1]}.${match[2]}`] = Array.isArray(raw) ? raw : raw.disciplines || raw.schedule || [];
  }
  fs.writeFileSync(path.join(output, `data/${course.id}.json`), JSON.stringify({course, curriculum:curriculum ? read(path.join(dir,curriculum)) : null, contents:contents ? read(path.join(dir,contents)) : null, schedules, snapshotSource:path.relative(root,source), snapshotNotice:'JSON local incluído no aplicativo.'}));
}
fs.mkdirSync(path.join(output,'images'),{recursive:true});
for (const name of ['my_ufape_logo.png','my_ufape_logo_azul.png']) fs.copyFileSync(path.join(root,'public',name),path.join(output,'images',name));
fs.mkdirSync(path.join(output,'calendar'),{recursive:true});
const calendar = path.join(root,'public/documents/calendario-academico-ufape-2026');
for (const file of fs.readdirSync(calendar).filter(f=>f.endsWith('.webp'))) fs.copyFileSync(path.join(calendar,file),path.join(output,'calendar',file));
fs.copyFileSync(path.join(root,'public/documents/calendario-academico-ufape-2026.pdf'),path.join(output,'calendar/calendario-academico-ufape-2026.pdf'));
console.log(`Offline reference synchronized: ${courses.length} courses and 16 calendar pages.`);
