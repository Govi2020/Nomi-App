import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { access, stat } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const input = process.argv[2];
if (!input) throw new Error('Usage: npm run verify:package -- <package-path>');
const file = path.resolve(input);
const info = await stat(file);
if (!info.isFile() || info.size === 0) throw new Error('Package must be a non-empty file');
const hash = createHash('sha256');
for await (const chunk of createReadStream(file)) hash.update(chunk);
const ext = path.extname(file).toLowerCase();

if (ext === '.deb') {
  const result = spawnSync('dpkg-deb', ['--contents', file], { encoding: 'utf8' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(result.stderr || 'dpkg-deb could not read the package');
  for (const entry of ['usr/bin/nomi', 'usr/bin/nomi-backend']) {
    if (!result.stdout.split(/\r?\n/).some((line) => line.trimEnd().endsWith(entry))) {
      throw new Error(`Debian package is missing ${entry}`);
    }
  }
  console.log('Debian package layout contains usr/bin/nomi and usr/bin/nomi-backend.');
} else if (ext === '.appimage') {
  await access(file, 1);
  console.log('AppImage is marked executable.');
} else if (ext === '.exe') {
  console.log('Windows executable is non-empty; package internals were not inspected.');
} else {
  throw new Error(`Unsupported package type: ${ext || '(no extension)'}`);
}

console.log(`File: ${file}\nSize: ${info.size} bytes\nSHA-256: ${hash.digest('hex')}`);
