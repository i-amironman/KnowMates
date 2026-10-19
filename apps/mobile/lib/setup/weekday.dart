/// API weekday: 0 = Monday … 6 = Sunday (see services/api migrations).
const kApiWeekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const kDefaultApiWeekday = 0;

String apiWeekdayLabel(int apiWeekday) {
  assert(apiWeekday >= 0 && apiWeekday < kApiWeekdayLabels.length);
  return kApiWeekdayLabels[apiWeekday];
}
