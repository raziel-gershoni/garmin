// Renders the Venu ring icons from Material Design Icons (Pictogrammers, see LICENSE-mdi.txt)
// as white anti-aliased PNGs on transparent, for drawBitmap2 with :tintColor.
// Usage: cd tools && node build-icons.mjs
import { Resvg } from '@resvg/resvg-js';
import { PNG } from 'pngjs';
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(new URL(import.meta.url).pathname);
const svgDir = path.join(here, 'node_modules/@mdi/svg/svg');
const out = path.join(here, '../face/resources-round/drawables');
const SIZE = 34; // Venu 4 41 mm rings (radius 50); the 45 mm would use 38
// file name -> MDI icon
const ICONS = {
  icon_heart: 'heart',
  icon_battery: 'battery',
  icon_battery80: 'battery-80',
  icon_battery50: 'battery-50',
  icon_battery20: 'battery-20',
  icon_steps: 'shoe-print',
  icon_altitude: 'image-filter-hdr',
  icon_sunrise: 'weather-sunset-up',
  icon_sunset: 'weather-sunset-down',
  icon_bodybattery: 'lightning-bolt',
  icon_notifications: 'bell',
  icon_calories: 'fire',
};

fs.mkdirSync(out, { recursive: true });
for (const [name, mdi] of Object.entries(ICONS)) {
  const svg = fs.readFileSync(path.join(svgDir, mdi + '.svg'), 'utf8').replace('<path ', '<path fill="#FFFFFF" ');
  const png = PNG.sync.read(Buffer.from(new Resvg(svg, { fitTo: { mode: 'width', value: SIZE } }).render().asPng()));
  for (let i = 0; i < png.data.length; i += 4) {
    png.data[i] = png.data[i + 1] = png.data[i + 2] = 255; // white; coverage stays in alpha
  }
  if (png.width !== SIZE || png.height !== SIZE) throw new Error(`${mdi}: ${png.width}x${png.height}`);
  fs.writeFileSync(path.join(out, name + '.png'), PNG.sync.write(png));
}
console.log(`wrote ${Object.keys(ICONS).length} icons to ${out}`);
