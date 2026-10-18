import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const base = new URL(process.argv[2] || 'http://127.0.0.1:8787');
const output = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../assets/data');
async function read(url) {
  const response = await fetch(new URL(url, base), {signal: AbortSignal.timeout(60000)});
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${url}`);
  return response.json();
}
const registry = await read('/api/courses');
if (!Array.isArray(registry.courses)) throw new Error('Registro de cursos inválido.');
const documents = await Promise.all(registry.courses.map(async course => {
  const details = await read(`/api/courses/${encodeURIComponent(course.id)}?include=curriculum,contents,schedule`);
  if (!details.course) throw new Error(`Curso inválido: ${course.id}`);
  const semesters = [...new Set([...(course.semesters || []), ...(details.course.semesters || [])])];
  const schedules = {}, scheduleMetadata = {};
  await Promise.all(semesters.map(async semester => {
    const result = await read(`/api/courses/${encodeURIComponent(course.id)}?semester=${encodeURIComponent(semester)}&strict=true&include=schedule`);
    if (result.schedule == null) return;
    if (result.resolvedSemester !== semester) throw new Error(`Semestre diferente do solicitado: ${course.id}/${semester}`);
    if (!Array.isArray(result.schedule)) throw new Error(`Oferta inválida: ${course.id}/${semester}`);
    schedules[semester] = result.schedule;
    scheduleMetadata[semester] = {extraction: result.scheduleExtraction, updated_at: result.scheduleUpdatedAt};
  }));
  return [course.id, {course: {...course, ...details.course}, curriculum: details.curriculum, contents: details.contents,
    schedules, scheduleMetadata, snapshotSource: base.origin, snapshotDate: new Date().toISOString()}];
}));
// Fetch and validate the complete set before replacing any bundled document.
await fs.mkdir(output, {recursive: true});
for (const [id, data] of documents) await fs.writeFile(path.join(output, `${id}.json`), JSON.stringify(data));
await fs.writeFile(path.join(output, 'courses.json'), JSON.stringify(registry));
console.log(`JSONs offline atualizados: ${documents.length} cursos, ${documents.reduce((sum, [, data]) => sum + Object.keys(data.schedules).length, 0)} ofertas semestrais.`);
