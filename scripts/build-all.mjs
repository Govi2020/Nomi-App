import { spawnSync } from 'node:child_process';
import process from 'node:process';

const isWindows = process.platform === 'win32';
const npm = isWindows ? 'npm.cmd' : 'npm';
const bundles = process.env.NOMI_BUNDLES || (isWindows ? 'nsis' : 'deb');

function run(args) {
  const result = spawnSync(npm, args, { stdio: 'inherit', shell: isWindows });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

console.log(`Building Nomi for ${process.platform}; bundle target: ${bundles}`);
run(['run', 'build:backend']);
run(['run', 'tauri:build', '--', '--bundles', bundles]);
