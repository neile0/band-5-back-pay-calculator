// Scottish income tax, NI, and NHS pension estimates.
// Rates based on 2025/26 Scottish budget. Used as a reasonable approximation
// across all back-pay years since these figures span 2024–2027.

const _incomeTaxBands = <({double from, double to, double rate})>[
  (from: 0, to: 12570, rate: 0.00), // personal allowance
  (from: 12570, to: 15397, rate: 0.19), // starter
  (from: 15397, to: 27491, rate: 0.20), // basic
  (from: 27491, to: 43662, rate: 0.21), // intermediate
  (from: 43662, to: 75000, rate: 0.42), // higher
  (from: 75000, to: 125140, rate: 0.45), // advanced
  (from: 125140, to: double.infinity, rate: 0.48), // top
];

const _niPrimaryThreshold = 12570.0;
const _niUpperEarningsLimit = 50270.0;
const _niMainRate = 0.08;
const _niUpperRate = 0.02;

// NHS Scotland employee pension contribution tiers.
const _pensionTiers = <({double from, double to, double rate})>[
  (from: 0, to: 13246, rate: 0.052),
  (from: 13246, to: 26831, rate: 0.065),
  (from: 26831, to: 32691, rate: 0.083),
  (from: 32691, to: 49078, rate: 0.098),
  (from: 49078, to: 72030, rate: 0.107),
  (from: 72030, to: double.infinity, rate: 0.125),
];

double _incomeTax(double income) {
  var tax = 0.0;
  for (final band in _incomeTaxBands) {
    if (income <= band.from) break;
    final taxable = (income < band.to ? income : band.to) - band.from;
    tax += taxable * band.rate;
  }
  return tax;
}

double _ni(double income) {
  if (income <= _niPrimaryThreshold) return 0;
  final main = (income < _niUpperEarningsLimit ? income : _niUpperEarningsLimit) -
      _niPrimaryThreshold;
  final upper = income > _niUpperEarningsLimit ? income - _niUpperEarningsLimit : 0.0;
  return main * _niMainRate + upper * _niUpperRate;
}

double _pensionRate(double annualSalary) {
  for (final tier in _pensionTiers) {
    if (annualSalary <= tier.to) return tier.rate;
  }
  return _pensionTiers.last.rate;
}

/// Marginal income tax on [extra] earned on top of [baseSalary].
double marginalIncomeTax(double baseSalary, double extra) =>
    _incomeTax(baseSalary + extra) - _incomeTax(baseSalary);

/// Marginal NI on [extra] earned on top of [baseSalary].
double marginalNI(double baseSalary, double extra) =>
    _ni(baseSalary + extra) - _ni(baseSalary);

/// Estimated pension deduction on [extra] back pay, based on the tier
/// for [totalSalary] (base + back pay).
double pensionOnBackPay(double baseSalary, double extra) =>
    extra * _pensionRate(baseSalary + extra);
