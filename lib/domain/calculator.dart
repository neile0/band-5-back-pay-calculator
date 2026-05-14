import 'pay_scales.dart';
import 'tax.dart';

class YearResult {
  const YearResult({
    required this.year,
    required this.proRatedOldSalary,
    required this.proRatedNewSalary,
    required this.grossBackPay,
    required this.incomeTax,
    required this.nationalInsurance,
    required this.pension,
  });

  final PayYear year;
  // Scale mode: annual FTE-adjusted Band5 / Band6 salaries.
  // HMRC mode: actual HMRC earnings vs expected Band 6 for the period.
  final double proRatedOldSalary;
  final double proRatedNewSalary;
  final double grossBackPay;
  final double incomeTax;
  final double nationalInsurance;
  final double pension;

  double get net => grossBackPay - incomeTax - nationalInsurance - pension;
}

class CalcResult {
  const CalcResult(this.years);
  final List<YearResult> years;

  double get totalGross => years.fold(0, (s, y) => s + y.grossBackPay);
  double get totalTax => years.fold(0, (s, y) => s + y.incomeTax);
  double get totalNI => years.fold(0, (s, y) => s + y.nationalInsurance);
  double get totalPension => years.fold(0, (s, y) => s + y.pension);
  double get totalNet => years.fold(0, (s, y) => s + y.net);
}

// Back pay = (Band 6 salary − Band 5 salary) × period fraction.
// Both salaries are the published NHS Scotland government scales.
YearResult calculateFromScales({
  required PayYear year,
  required SpinePoint spine,
  required double contractedHours,
  required DateTime periodStart,
  required DateTime periodEnd,
  required bool includePension,
}) {
  final fte = fteHoursFor(year);
  final hoursRatio = contractedHours / fte;

  final taxYearDays = DateTime(year.endYear, 3, 31)
          .difference(DateTime(year.startYear, 4, 1))
          .inDays +
      1;
  final periodDays =
      (periodEnd.difference(periodStart).inDays + 1).clamp(0, taxYearDays);
  final periodRatio = periodDays / taxYearDays;

  final band5Annual = band5AnnualScale(year, spine) * hoursRatio;
  final band6Annual = band6AnnualScale(year, spine) * hoursRatio;

  final gross = (band6Annual - band5Annual) * periodRatio;
  final tax = marginalIncomeTax(band5Annual, gross);
  final ni = marginalNI(band5Annual, gross);
  final pen = includePension ? pensionOnBackPay(band5Annual, gross) : 0.0;

  return YearResult(
    year: year,
    proRatedOldSalary: band5Annual,
    proRatedNewSalary: band6Annual,
    grossBackPay: gross,
    incomeTax: tax,
    nationalInsurance: ni,
    pension: pen,
  );
}

// Back pay = Band 6 expected for the period − actual HMRC earnings.
// HMRC earnings are trusted as-is for the claimed period; Band 6 is
// pro-rated to the same period using periodStart/periodEnd.
YearResult calculateFromHmrc({
  required PayYear year,
  required SpinePoint spine,
  required double contractedHours,
  required double hmrcEarnings,
  required DateTime periodStart,
  required DateTime periodEnd,
  required bool includePension,
}) {
  final fte = fteHoursFor(year);
  final hoursRatio = contractedHours / fte;

  final taxYearDays = DateTime(year.endYear, 3, 31)
          .difference(DateTime(year.startYear, 4, 1))
          .inDays +
      1;
  final periodDays =
      (periodEnd.difference(periodStart).inDays + 1).clamp(0, taxYearDays);
  final periodRatio = periodDays / taxYearDays;

  final band6Annual = band6AnnualScale(year, spine) * hoursRatio;
  final band6ForPeriod = band6Annual * periodRatio;

  final gross = (band6ForPeriod - hmrcEarnings).clamp(0.0, double.infinity);

  // Annualise the HMRC figure to get the correct marginal tax band.
  final annualisedBase =
      periodRatio > 0 ? hmrcEarnings / periodRatio : hmrcEarnings;
  final tax = marginalIncomeTax(annualisedBase, gross);
  final ni = marginalNI(annualisedBase, gross);
  final pen = includePension ? pensionOnBackPay(annualisedBase, gross) : 0.0;

  return YearResult(
    year: year,
    proRatedOldSalary: hmrcEarnings,
    proRatedNewSalary: band6ForPeriod,
    grossBackPay: gross,
    incomeTax: tax,
    nationalInsurance: ni,
    pension: pen,
  );
}
