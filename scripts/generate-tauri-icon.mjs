import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs'
import { deflateSync } from 'node:zlib'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const icons = path.join(root, 'src-tauri', 'icons')
mkdirSync(icons, { recursive: true })

const size = 512
const pixels = Buffer.alloc(size * size * 4)
const bg = [23, 26, 22, 255]
const fg = [186, 198, 174, 255]
const polygon = [[146, 112], [206, 112], [306, 270], [306, 112], [366, 112], [366, 400], [306, 400], [206, 242], [206, 400], [146, 400]]

function insidePolygon(x, y) {
  let inside = false
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [xi, yi] = polygon[i]
    const [xj, yj] = polygon[j]
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside
  }
  return inside
}

for (let y = 0; y < size; y++) {
  for (let x = 0; x < size; x++) {
    const color = insidePolygon(x + 0.5, y + 0.5) ? fg : bg
    pixels.set(color, (y * size + x) * 4)
  }
}

function chunk(type, data) {
  const name = Buffer.from(type)
  const length = Buffer.alloc(4)
  length.writeUInt32BE(data.length)
  const crcInput = Buffer.concat([name, data])
  let crc = 0xffffffff
  for (const byte of crcInput) {
    crc ^= byte
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0)
  }
  const checksum = Buffer.alloc(4)
  checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0)
  return Buffer.concat([length, name, data, checksum])
}

const header = Buffer.alloc(13)
header.writeUInt32BE(size, 0)
header.writeUInt32BE(size, 4)
header[8] = 8
header[9] = 6
const rows = Buffer.alloc((size * 4 + 1) * size)
for (let y = 0; y < size; y++) pixels.copy(rows, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4)
writeFileSync(path.join(icons, 'icon.png'), Buffer.concat([
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  chunk('IHDR', header),
  chunk('IDAT', deflateSync(rows)),
  chunk('IEND', Buffer.alloc(0)),
]))
copyFileSync(path.join(root, 'frontend', 'public', 'Nomi.ico'), path.join(icons, 'icon.ico'))
