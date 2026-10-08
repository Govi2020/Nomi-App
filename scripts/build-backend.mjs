import { spawnSync } from 'node:child_process'
import { resolve } from 'node:path'
import process from 'node:process'

const root = resolve(import.meta.dirname, '..')
const windows = process.platform === 'win32'
const pythonCandidates = windows ? [['py', ['-3']], ['python', []]] : [['python3', []], ['python', []]]
const python = pythonCandidates.find(([command, prefix]) => spawnSync(command, [...prefix, '--version'], { stdio: 'ignore', shell: windows }).status === 0)
if (!python) throw new Error('Python 3.11+ is required to build the backend sidecar.')
const [command, prefix] = python
const result = spawnSync(command, [...prefix, resolve(root, 'scripts/build_backend.py')], { cwd: root, stdio: 'inherit', shell: windows })
if (result.error) throw result.error
if (result.status !== 0) process.exit(result.status ?? 1)
