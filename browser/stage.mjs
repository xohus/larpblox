import {copyFile, mkdir, readFile, writeFile} from 'node:fs/promises';

const dist = new URL('./dist/', import.meta.url);
await mkdir(dist, {recursive: true});
for (const file of ['manifest.json', 'background.js']) {
  await copyFile(new URL(file, import.meta.url), new URL(file, dist));
}
const consoleHtml = await readFile(new URL('../LarpConsole.html', import.meta.url), 'utf8');
let scriptCount = 0;
const page = consoleHtml.replace(/<script>([\s\S]*?)<\/script>/gi, (_, script) => {
  scriptCount += 1;
  if (scriptCount > 1) throw new Error('Expected one inline console script.');
  return '<script src="console.js"></script>';
});
if (!scriptCount) throw new Error('No inline console script found.');
const script = /<script>([\s\S]*?)<\/script>/i.exec(consoleHtml)[1];
await writeFile(new URL('console.js', dist), script);
await writeFile(new URL('LarpConsole.html', dist), page);
