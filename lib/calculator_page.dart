import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'domain/calculator.dart';
import 'domain/pay_scales.dart';

enum CalcMode { payScale, hmrc }

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const _teal = Color(0xFF005C69);
  static const _gold = Color(0xFFFFC837);
  static const _mintBadge = Color(0xFFCCEDE9);

  // ── Controllers ────────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _hmrcControllers = {
    for (final y in PayYear.values) y: TextEditingController(),
  };

  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _revealCtrl;
  late final AnimationController _counterCtrl;
  late final Animation<double> _revealFade;
  late final Animation<Offset> _revealSlide;
  late final Animation<double> _counterAnim;
  bool _revealed = false;
  double _counterTarget = 0;

  // ── Form state ─────────────────────────────────────────────────────────────
  CalcMode _mode = CalcMode.payScale;
  double _yearsExperience = 0;
  double _hours = 37.5;
  bool _pension = true;
  DateTime _backPayStart = DateTime(2025, 4, 1);
  DateTime _effectiveAfcDate = DateTime.now();

  // ── Derived ────────────────────────────────────────────────────────────────
  SpinePoint get _spine {
    if (_yearsExperience < 2) return SpinePoint.entry;
    if (_yearsExperience < 4) return SpinePoint.intermediate;
    return SpinePoint.top;
  }

  // ── Result state ───────────────────────────────────────────────────────────
  CalcResult? _result;
  String _displayName = '';

  final _fmt =
      NumberFormat.currency(locale: 'en_GB', symbol: '£', decimalDigits: 2);
  final _dateFmt = DateFormat('d MMM yyyy');

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _counterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _revealFade = CurvedAnimation(
      parent: _revealCtrl,
      curve: Curves.easeOut,
    );
    _revealSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic));
    _counterAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _counterCtrl, curve: Curves.easeOutExpo),
    );

    _nameController.addListener(_recalculate);
    for (final c in _hmrcControllers.values) {
      c.addListener(_recalculate);
    }
    _recalculate();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _counterCtrl.dispose();
    _nameController.dispose();
    for (final c in _hmrcControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Reveal ─────────────────────────────────────────────────────────────────
  void _reveal() {
    final gross = _result?.totalGross ?? 0;
    setState(() {
      _revealed = true;
      _counterTarget = gross;
    });
    _revealCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _counterCtrl.forward(from: 0);
    });
  }

  // ── Calculation ────────────────────────────────────────────────────────────
  void _recalculate() {
    final years = <YearResult>[];
    final endDate = _effectiveAfcDate;

    for (final year in PayYear.values) {
      final yearEnd = DateTime(year.endYear, 3, 31);
      if (_backPayStart.isAfter(yearEnd)) continue;
      if (endDate.isBefore(year.awardDate)) continue;

      final periodStart = _backPayStart.isAfter(year.awardDate)
          ? _backPayStart
          : year.awardDate;
      final periodEnd = endDate.isBefore(yearEnd) ? endDate : yearEnd;
      if (!periodEnd.isAfter(periodStart)) continue;

      if (_mode == CalcMode.payScale) {
        years.add(calculateFromScales(
          year: year,
          spine: _spine,
          contractedHours: _hours,
          periodStart: periodStart,
          periodEnd: periodEnd,
          includePension: _pension,
        ));
      } else {
        final raw = _hmrcControllers[year]!.text
            .replaceAll(',', '')
            .replaceAll('£', '')
            .trim();
        final earnings = double.tryParse(raw);
        if (earnings == null || earnings <= 0) continue;
        years.add(calculateFromHmrc(
          year: year,
          spine: _spine,
          contractedHours: _hours,
          hmrcEarnings: earnings,
          periodStart: periodStart,
          periodEnd: periodEnd,
          includePension: _pension,
        ));
      }
    }

    setState(() {
      _result = years.isEmpty ? null : CalcResult(years);
      _displayName = _nameController.text.trim();
      // hide reveal button again if result disappears
      if (_result == null) _revealed = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: const Text(
          'NHS Scotland Band 5 AfC Back Pay Calculator',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _nameCard(),
                  const SizedBox(height: 16),
                  _modeCard(),
                  const SizedBox(height: 16),
                  _employmentCard(),
                  const SizedBox(height: 16),
                  _backPayStartCard(),
                  if (_mode == CalcMode.hmrc) ...[
                    const SizedBox(height: 16),
                    _hmrcCard(),
                  ],
                  const SizedBox(height: 16),
                  _effectiveAfcDateCard(),
                  const SizedBox(height: 24),
                  _resultsSection(),
                  const SizedBox(height: 48),
                  _footer(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────────────

  Widget _nameCard() => _card(
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Your first name',
            hintText: 'e.g. Zoe',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
      );

  Widget _modeCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How would you like to calculate?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            SegmentedButton<CalcMode>(
              segments: const [
                ButtonSegment(
                  value: CalcMode.payScale,
                  label: Text('Use pay scales'),
                  icon: Icon(Icons.table_chart_outlined),
                ),
                ButtonSegment(
                  value: CalcMode.hmrc,
                  label: Text('Use my HMRC earnings'),
                  icon: Icon(Icons.receipt_long_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                setState(() {
                  _mode = s.first;
                  _revealed = false;
                });
                _recalculate();
              },
            ),
            const SizedBox(height: 8),
            Text(
              _mode == CalcMode.payScale
                  ? 'Uses published NHS Scotland pay tables. Back pay = Band 6 salary − Band 5 salary for each year.'
                  : 'Uses your actual gross earnings from HMRC vs Band 6 expected pay. More accurate if you worked overtime or enhancements.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );

  // Section 1 ─────────────────────────────────────────────────────────────────

  Widget _employmentCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current employment',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _mintBadge,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.work_outline, color: _teal, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NHS Band 5 → Band 6 (Specialist Nurse)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _teal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Years of experience
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Years of experience',
                    style:
                        TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                _spineBadge(_spine),
              ],
            ),
            Slider(
              value: _yearsExperience,
              min: 0,
              max: 10,
              divisions: 20,
              activeColor: _teal,
              inactiveColor: _mintBadge,
              label: _yearsExperience == _yearsExperience.truncate()
                  ? '${_yearsExperience.toInt()} yrs'
                  : '$_yearsExperience yrs',
              onChanged: (v) {
                setState(() => _yearsExperience = v);
                _recalculate();
              },
            ),
            Row(
              children: [
                Text('0',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                Text('2',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                Text('4',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                Text('10 yrs',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 20),

            // Contracted hours
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Contracted hours per week',
                    style:
                        TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _teal,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_hours % 1 == 0 ? _hours.toInt() : _hours} hrs',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
            Slider(
              value: _hours,
              min: 8,
              max: 37.5,
              divisions: 59,
              activeColor: _teal,
              inactiveColor: _mintBadge,
              label: '${_hours % 1 == 0 ? _hours.toInt() : _hours} hrs',
              onChanged: (v) {
                setState(() => _hours = v);
                _recalculate();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('8 hrs',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text('Full time (37.5)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 20),

            // Pension
            const Text('NHS Pension opted in?',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true, label: Text('Yes — include deduction')),
                ButtonSegment(value: false, label: Text('No — opted out')),
              ],
              selected: {_pension},
              onSelectionChanged: (s) {
                setState(() => _pension = s.first);
                _recalculate();
              },
            ),
          ],
        ),
      );

  Widget _spineBadge(SpinePoint sp) {
    final label = switch (sp) {
      SpinePoint.entry => 'Entry · 0–2 yrs',
      SpinePoint.intermediate => 'Intermediate · 2–4 yrs',
      SpinePoint.top => 'Top of band · 4+ yrs',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _teal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  // Section 2 ─────────────────────────────────────────────────────────────────

  Widget _backPayStartCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date backdated to',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'The date your Specialist Nursing role effectively starts — the beginning of the period for which back pay is owed.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            _infoTip(
                'The earliest eligible date under PCS(AFC)2024/3 is 1 April 2023.'),
            const SizedBox(height: 16),
            _dateField(
              label: 'Backdated to',
              date: _backPayStart,
              firstDate: PayYear.earliestBackPayDate,
              lastDate: _effectiveAfcDate,
              onChanged: (d) {
                setState(() => _backPayStart = d);
                _recalculate();
              },
            ),
          ],
        ),
      );

  // Section 3 (HMRC mode only) ─────────────────────────────────────────────

  Widget _hmrcCard() {
    final relevantYears = PayYear.values.where((year) {
      final yearEnd = DateTime(year.endYear, 3, 31);
      return !_backPayStart.isAfter(yearEnd) &&
          !_effectiveAfcDate.isBefore(year.awardDate);
    }).toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your HMRC gross earnings',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Find these in the HMRC app under "Pay As You Earn". Enter the total gross pay for each tax year shown.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          _infoTip(
            'Your actual earnings (including overtime) are compared against the Band 6 expected salary for the same period.',
          ),
          const SizedBox(height: 12),
          ...relevantYears.map(_hmrcRow),
        ],
      ),
    );
  }

  Widget _hmrcRow(PayYear year) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _hmrcControllers[year],
        decoration: InputDecoration(
          labelText: '${year.label} gross earnings',
          border: const OutlineInputBorder(),
          prefixText: '£ ',
          hintText: '0.00',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
        ],
      ),
    );
  }

  // Final section ─────────────────────────────────────────────────────────────

  Widget _effectiveAfcDateCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Effective AfC date',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'The date you formally become (or became) a Band 6 Specialist Nurse and start receiving Band 6 pay. Back pay is calculated up to this date.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            _dateField(
              label: 'Effective from',
              date: _effectiveAfcDate,
              firstDate: _backPayStart,
              lastDate: DateTime(2027, 3, 31),
              onChanged: (d) {
                setState(() => _effectiveAfcDate = d);
                _recalculate();
              },
            ),
          ],
        ),
      );

  Widget _dateField({
    required String label,
    required DateTime date,
    required DateTime firstDate,
    required DateTime lastDate,
    required void Function(DateTime) onChanged,
  }) {
    final clampedInitial = date.isBefore(firstDate)
        ? firstDate
        : date.isAfter(lastDate)
            ? lastDate
            : date;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: clampedInitial,
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: _teal,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 15),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Text(_dateFmt.format(date),
            style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  // ── Results ────────────────────────────────────────────────────────────────

  Widget _resultsSection() {
    if (_result == null) return _placeholderResults();
    if (!_revealed) return _revealButton();

    return FadeTransition(
      opacity: _revealFade,
      child: SlideTransition(
        position: _revealSlide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_displayName.isNotEmpty) ...[
              _congratsCard(),
              const SizedBox(height: 16),
            ],
            _resultsCard(),
            const SizedBox(height: 16),
            _disclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _revealButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          child: Column(
            children: [
              const Icon(Icons.lock_outline, size: 36, color: _teal),
              const SizedBox(height: 12),
              const Text(
                'Your estimate is ready',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _teal),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap the button below when you\'re ready to see your back pay estimate.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _RevealButton(onPressed: _reveal),
      ],
    );
  }

  Widget _placeholderResults() => _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.calculate_outlined, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                _mode == CalcMode.hmrc
                    ? 'Enter your HMRC earnings above to see your estimate.'
                    : 'Fill in your details above to see your estimate.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );

  Widget _congratsCard() => Container(
        decoration: BoxDecoration(
          color: _teal,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations, $_displayName.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Whether you have had your Agenda for Change accepted or not, we hope you feel recognised for the work that you do. We would be a worse society without you.',
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      );

  Widget _resultsCard() {
    final r = _result!;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your estimated back pay',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            '${_dateFmt.format(_backPayStart)} → ${_dateFmt.format(_effectiveAfcDate)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),

          // Hero numbers with animated counter
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FFF9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _mintBadge),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total gross back pay',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _counterAnim,
                  builder: (context, _) {
                    final animating = _counterCtrl.status !=
                        AnimationStatus.completed;
                    final value = animating
                        ? _counterTarget * _counterAnim.value
                        : r.totalGross;
                    return Text(
                      _fmt.format(value),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _gold,
                        letterSpacing: -0.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Estimated take-home: ',
                        style: TextStyle(fontSize: 14)),
                    Text(
                      _fmt.format(r.totalNet),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Per-year breakdown
          ...r.years.map(_yearSection),
          const Divider(thickness: 1.5),
          const SizedBox(height: 8),
          _row('Total gross back pay', r.totalGross, bold: true),
          _row('  Income tax (est.)', -r.totalTax),
          _row('  National Insurance (est.)', -r.totalNI),
          if (_pension) _row('  Pension contribution (est.)', -r.totalPension),
          const Divider(),
          _row('Total estimated take-home', r.totalNet,
              bold: true, color: _teal),
        ],
      ),
    );
  }

  Widget _yearSection(YearResult y) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _mintBadge,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              y.year.label,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, color: _teal),
            ),
          ),
          const SizedBox(height: 8),
          _row(
            _mode == CalcMode.payScale
                ? 'Band 5 salary (annual)'
                : 'Your HMRC earnings',
            y.proRatedOldSalary,
          ),
          _row(
            _mode == CalcMode.payScale
                ? 'Band 6 salary (annual)'
                : 'Expected Band 6 pay',
            y.proRatedNewSalary,
          ),
          _row('Gross back pay', y.grossBackPay, bold: true),
          _row('  Income tax (est.)', -y.incomeTax),
          _row('  National Insurance (est.)', -y.nationalInsurance),
          if (_pension) _row('  Pension contribution (est.)', -y.pension),
          _row('Net back pay', y.net, bold: true, color: _teal),
          const SizedBox(height: 16),
        ],
      );

  Widget _row(String label, double value, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
      color: color,
      fontSize: 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            value >= 0 ? _fmt.format(value) : '-${_fmt.format(-value)}',
            style: style,
          ),
        ],
      ),
    );
  }

  Widget _disclaimer() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFF8575)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: Color(0xFFFF8575)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'These are estimates based on published NHS Scotland pay scales and standard Scottish tax rates. '
                'Your actual back pay may differ. Please verify with your payroll department.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _infoTip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _mintBadge,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 15, color: _teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 12, color: _teal),
              ),
            ),
          ],
        ),
      );

  Widget _footer() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            const Divider(),
            const SizedBox(height: 12),
            Text('Made by Aidan Neil · Kelvin Systems',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(
              'Well done Zoe and those at NSD on the recognition of your specialised work ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );

  Widget _card({required Widget child}) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      );
}

// ── Animated Reveal Button ─────────────────────────────────────────────────

class _RevealButton extends StatefulWidget {
  const _RevealButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_RevealButton> createState() => _RevealButtonState();
}

class _RevealButtonState extends State<_RevealButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: widget.onPressed,
          icon: const Icon(Icons.auto_awesome, size: 20),
          label: const Text('Reveal my back pay estimate'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
