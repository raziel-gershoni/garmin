// Checks a line-by-line JS mirror of common/source/HebrewCalendar.mc + HebrewFormat.mc
// against @hebcal/core for every day 1900-01-01..2100-12-31, then writes
// common/test/Fixtures.mc for the Monkey C unit tests.
//
//   cd tools && npm install && node hebcal-oracle.mjs
import { HDate } from '@hebcal/core';
import { writeFileSync } from 'node:fs';

const div = (a, b) => Math.trunc(a / b); // Monkey C integer division truncates
const mod = (a, b) => a % b;             // Monkey C % keeps the dividend's sign

// ---- mirror of HebrewCalendar.mc ----
const EPOCH = -1373427, NISAN = 1, TISHREI = 7, ADAR = 12, ADAR_II = 13;
const isLeapYear = y => mod(7 * y + 1, 19) < 7;
function elapsedDays(y) {
  const months = div(235 * y - 234, 19);
  const parts = 12084 + 13753 * months;
  if (parts > 2147483647) throw new Error(`Int32 overflow at year ${y}`);
  let days = 29 * months + div(parts, 25920);
  if (mod(3 * (days + 1), 7) < 3) days += 1;
  return days;
}
function yearLengthCorrection(y) {
  const ny0 = elapsedDays(y - 1), ny1 = elapsedDays(y), ny2 = elapsedDays(y + 1);
  if (ny2 - ny1 === 356) return 2;
  if (ny1 - ny0 === 382) return 1;
  return 0;
}
const newYear = y => EPOCH + elapsedDays(y) + yearLengthCorrection(y);
function monthLength(m, leap, yearDays) {
  if (m === 2 || m === 4 || m === 6 || m === 10 || m === ADAR_II) return 29;
  if (m === ADAR && !leap) return 29;
  if (m === 8 && mod(yearDays, 10) !== 5) return 29;
  if (m === 9 && mod(yearDays, 10) === 3) return 29;
  return 30;
}
const nextMonth = (m, leap) => (m === (leap ? ADAR_II : ADAR) ? NISAN : m + 1);
function toFixed(y, m, d) {
  const ny = newYear(y), yearDays = newYear(y + 1) - ny, leap = isLeapYear(y);
  let rd = ny + d - 1;
  for (let mm = TISHREI; mm !== m; mm = nextMonth(mm, leap)) rd += monthLength(mm, leap, yearDays);
  return rd;
}
function fromFixed(rd) {
  let year = Number((BigInt(rd - EPOCH) * 98496n) / 35975351n) + 1;
  while (newYear(year) > rd) year -= 1;
  while (newYear(year + 1) <= rd) year += 1;
  const ny = newYear(year), yearDays = newYear(year + 1) - ny, leap = isLeapYear(year);
  let dayOfYear = rd - ny, month = TISHREI, len = monthLength(month, leap, yearDays);
  while (dayOfYear >= len) {
    dayOfYear -= len;
    month = nextMonth(month, leap);
    len = monthLength(month, leap, yearDays);
  }
  return [year, month, dayOfYear + 1];
}
const isGregorianLeapYear = y => (mod(y, 4) === 0 && mod(y, 100) !== 0) || mod(y, 400) === 0;
function fixedFromGregorian(y, m, d) {
  const py = y - 1;
  let rd = 365 * py + div(py, 4) - div(py, 100) + div(py, 400) + div(367 * m - 362, 12) + d;
  if (m > 2) rd -= isGregorianLeapYear(y) ? 1 : 2;
  return rd;
}

// ---- mirror of HebrewFormat.mc ----
const ONES = ['א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];
const TENS = ['י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ'];
const HUNDREDS = ['ק', 'ר', 'ש'];
const MONTHS = ['', 'ניסן', 'אייר', 'סיון', 'תמוז', 'אב', 'אלול', 'תשרי', 'חשון', 'כסלו', 'טבת', 'שבט', 'אדר', 'אדר ב׳'];
function gematria(n) {
  const letters = [];
  while (n >= 400) { letters.push('ת'); n -= 400; }
  if (n >= 100) { letters.push(HUNDREDS[div(n, 100) - 1]); n = mod(n, 100); }
  if (n === 15 || n === 16) { letters.push('ט'); letters.push(ONES[n - 10]); n = 0; }
  if (n >= 10) { letters.push(TENS[div(n, 10) - 1]); n = mod(n, 10); }
  if (n > 0) letters.push(ONES[n - 1]);
  if (letters.length === 1) return letters[0] + '׳';
  let s = '';
  for (let i = 0; i < letters.length; i++) { if (i === letters.length - 1) s += '״'; s += letters[i]; }
  return s;
}
const monthName = (m, y) => (m === ADAR && isLeapYear(y) ? 'אדר א׳' : MONTHS[m]);
const full = h => `${gematria(h[2])} ${monthName(h[1], h[0])} ${gematria(mod(h[0], 1000))}`;

// ---- exhaustive comparison ----
let checked = 0, bad = 0;
const fixtures = [], strings = [];
const start = new Date(Date.UTC(1900, 0, 1)), end = new Date(Date.UTC(2100, 11, 31));
for (let t = start; t <= end; t = new Date(t.getTime() + 86400000)) {
  const gy = t.getUTCFullYear(), gm = t.getUTCMonth() + 1, gd = t.getUTCDate();
  const ref = new HDate(new Date(gy, gm - 1, gd));
  const rd = fixedFromGregorian(gy, gm, gd);
  const mine = fromFixed(rd);
  const want = [ref.getFullYear(), ref.getMonth(), ref.getDate()];
  const okDate = rd === ref.abs() && mine.join() === want.join() && toFixed(...mine) === rd;
  const okText = full(mine) === ref.renderGematriya(true);
  if (!okDate || !okText) {
    if (bad++ < 10) console.error('MISMATCH', gy, gm, gd, { rd, abs: ref.abs(), mine, want, text: full(mine), ref: ref.renderGematriya(true) });
  }
  checked++;
  // Fixtures: a sample every 257 days, plus edge days (month boundaries in leap/short/long years).
  const edge = (mine[2] === 1 || mine[2] >= 29) && mine[0] >= 5785 && mine[0] <= 5789;
  if (checked % 401 === 1 || edge || (gm === 2 && gd === 29) || (gm === 3 && gd === 1 && gy % 100 === 0)) {
    fixtures.push([gy, gm, gd, ...want]);
  }
  if (checked % 1999 === 1 || (edge && mine[2] === 1 && mine[1] >= 12)) strings.push([gy, gm, gd, ref.renderGematriya(true)]);
}
console.log(`checked ${checked} days, ${bad} mismatches; ${fixtures.length} date fixtures, ${strings.length} string fixtures`);
if (bad) process.exit(1);

const out = `import Toybox.Lang;

// Generated by tools/hebcal-oracle.mjs from @hebcal/core — do not edit.
(:test)
module Fixtures {
    // [gregorianYear, month, day, hebrewYear, hebrewMonth, hebrewDay]
    const DATES = [
${fixtures.map(f => `        [${f.join(', ')}]`).join(',\n')}
    ];

    // [gregorianYear, month, day, Hebcal renderGematriya(true)]
    const STRINGS = [
${strings.map(s => `        [${s[0]}, ${s[1]}, ${s[2]}, "${s[3]}"]`).join(',\n')}
    ];
}
`;
writeFileSync(new URL('../common/test/Fixtures.mc', import.meta.url), out);
console.log('wrote common/test/Fixtures.mc');
