import { spawnSync } from 'node:child_process'
import { existsSync } from 'node:fs'
import { join, resolve } from 'node:path'
import process from 'node:process'

const root = resolve(import.meta.dirname, '..')
const windows = process.platform === 'win32'
const venv = join(root, '.venv')
const pythonInVenv = join(venv, windows ? 'Scripts/python.exe' : 'bin/python')

function run(command, args, cwd = root) {
  const result = spawnSync(command, args, { cwd, stdio: 'inherit', shell: windows })
  if (result.error) throw result.error
  if (result.status !== 0) throw new Error(`${command} exited with status ${result.status}`)
}

function findPython() {
  const candidates = windows ? [['py', '-3'], ['python']] : [['python3'], ['python']]
  for (const [command, ...prefix] of candidates) {
    const result = spawnSync(command, [...prefix, '--version'], { encoding: 'utf8', shell: windows })
    const match = `${result.stdout ?? ''}${result.stderr ?? ''}`.match(/Python (\d+)\.(\d+)/)
    if (result.status === 0 && match && Number(match[1]) >= 3 && Number(match[2]) >= 11) return [command, ...prefix]
  }
  throw new Error('Python 3.11+ is required for developer setup and backend development.')
}

const [nodeMajor, nodeMinor] = process.versions.node.split('.').map(Number)
if (nodeMajor < 22 || (nodeMajor === 22 && nodeMinor < 12)) throw new Error('Node.js 22.12+ is required.')
const python = findPython()
if (!existsSync(pythonInVenv)) run(python[0], [...python.slice(1), '-m', 'venv', venv])
run(pythonInVenv, ['-m', 'pip', 'install', '-r', join(root, 'backend/requirements.txt')])
run('npm', ['ci'], root)
run('npm', ['ci'], join(root, 'frontend'))

console.log('\nDeveloper dependencies are ready.')
console.log('Start the desktop development app with: npm run tauri:dev')
console.log('Ollama is optional for journaling; Nomi will guide installation and model setup inside the app.')
console.log('Linux builds also require Tauri WebKitGTK 4.1 system development packages; see docs/migration/BUILD.md.')
