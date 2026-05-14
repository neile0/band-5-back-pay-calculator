// NHS Scotland Agenda for Change pay scales — Band 5 and Band 6.
// Sources: NHS Scotland pay circulars, nhstakehomepaycalculator.co.uk, NHS Employers tables.
// Band 6 figures for 2023/24 and earlier are derived by reverse-applying the
// confirmed annual percentage increases (verified to be consistent with the
// ~25% Band 5→Band 6 differential that holds across all available years).

enum SpinePoint {
  entry('Entry (0–2 years)', 'Entry', '0–2 yrs'),
  intermediate('Intermediate (2–4 years)', 'Intermediate', '2–4 yrs'),
  top('Top (4+ years)', 'Top', '4+ yrs');

  const SpinePoint(this.label, this.shortLabel, this.yearsLabel);
  final String label;
  final String shortLabel;
  final String yearsLabel;
}

enum PayYear {
  // Earliest back-pay date under PCS(AFC)2024/3 is 1 April 2023.
  y2023_24('2023/24', 2023, 2024, 6.5),
  y2024_25('2024/25', 2024, 2025, 5.5),
  y2025_26('2025/26', 2025, 2026, 4.25),
  y2026_27('2026/27', 2026, 2027, 3.75);

  const PayYear(
      this.label, this.startYear, this.endYear, this.increasePercent);
  final String label;
  final int startYear;
  final int endYear;
  final double increasePercent;

  DateTime get awardDate => DateTime(startYear, 4, 1);

  static final earliestBackPayDate = DateTime(2023, 4, 1);
}

// ── Band 5 annual FTE salaries ──────────────────────────────────────────────

const _band5 = <(PayYear, SpinePoint), double>{
  (PayYear.y2023_24, SpinePoint.entry): 30229,
  (PayYear.y2023_24, SpinePoint.intermediate): 32300,
  (PayYear.y2023_24, SpinePoint.top): 37664,
  (PayYear.y2024_25, SpinePoint.entry): 31892,
  (PayYear.y2024_25, SpinePoint.intermediate): 34077,
  (PayYear.y2024_25, SpinePoint.top): 39735,
  (PayYear.y2025_26, SpinePoint.entry): 33247,
  (PayYear.y2025_26, SpinePoint.intermediate): 35525,
  (PayYear.y2025_26, SpinePoint.top): 41424,
  (PayYear.y2026_27, SpinePoint.entry): 34494,
  (PayYear.y2026_27, SpinePoint.intermediate): 36857,
  (PayYear.y2026_27, SpinePoint.top): 42977,
};

// ── Band 6 annual FTE salaries ──────────────────────────────────────────────
// 2024/25 confirmed from nhstakehomepaycalculator.co.uk.
// 2023/24 derived by reverse-applying the 5.5% uplift (consistent with the
// ~25% Band 5→Band 6 differential that holds across all confirmed years).

const _band6 = <(PayYear, SpinePoint), double>{
  (PayYear.y2023_24, SpinePoint.entry): 37836,
  (PayYear.y2023_24, SpinePoint.intermediate): 39497,
  (PayYear.y2023_24, SpinePoint.top): 46100,
  (PayYear.y2024_25, SpinePoint.entry): 39912,
  (PayYear.y2024_25, SpinePoint.intermediate): 41670,
  (PayYear.y2024_25, SpinePoint.top): 48635,
  (PayYear.y2025_26, SpinePoint.entry): 41608,
  (PayYear.y2025_26, SpinePoint.intermediate): 43441,
  (PayYear.y2025_26, SpinePoint.top): 50702,
  (PayYear.y2026_27, SpinePoint.entry): 43169,
  (PayYear.y2026_27, SpinePoint.intermediate): 45070,
  (PayYear.y2026_27, SpinePoint.top): 52603,
};

// FTE reference hours. NHS Scotland reduced FTE to 36h from April 2026.
const _fteHours = <PayYear, double>{
  PayYear.y2023_24: 37.5,
  PayYear.y2024_25: 37.5,
  PayYear.y2025_26: 37.5,
  PayYear.y2026_27: 36.0,
};

double band5AnnualScale(PayYear year, SpinePoint spine) =>
    _band5[(year, spine)]!;

double band6AnnualScale(PayYear year, SpinePoint spine) =>
    _band6[(year, spine)]!;

double fteHoursFor(PayYear year) => _fteHours[year]!;
