import { lstat, realpath, rm } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const root = await realpath(path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..'));
const execute = process.argv.includes('--execute');
const targets = ['build/backend', 'frontend/dist', 'src-tauri/target'];

for (const relative of targets) {
  const candidate = path.resolve(root, relative);
  if (!candidate.startsWith(`${root}${path.sep}`)) throw new Error(`Unsafe clean target: ${relative}`);
  const parts = path.relative(root, candidate).split(path.sep);
  let current = root;
  let exists = true;
  for (const part of parts) {
    current = path.join(current, part);
    try {
      const info = await lstat(current);
      if (info.isSymbolicLink()) throw new Error(`Refusing symlink in clean target path: ${relative}`);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      exists = false;
      break;
    }
  }
  if (exists) {
    if (execute) await rm(candidate, { recursive: true, force: true });
    console.log(`${execute ? 'Removed' : 'Would remove'} ${relative}`);
  } else {
    console.log(`Absent ${relative}`);
  }
}

if (!execute) console.log('Dry run only. Pass --execute to remove these generated build outputs.');
