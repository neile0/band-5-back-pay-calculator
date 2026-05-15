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

class _CalculatorPageState extends State<CalculatorPage> {
  static const _teal = Color(0xFF005C69);
  static const _mintBadge = Color(0xFFCCEDE9);
  static const _textSecondary = Color(0xFF677C7E);

  final _nameController = TextEditingController();
  final _hmrcControllers = {
    for (final y in PayYear.values) y: TextEditingController(),
  };

  CalcMode _mode = CalcMode.payScale;
  double _yearsExperience = 0;
  double _hours = 37.5;
  bool _pension = true;
  DateTime _backPayStart = DateTime(2025, 4, 1);
  DateTime _effectiveAfcDate = DateTime.now();

  // Current spine — used for UI badge only.
  SpinePoint get _spine => _spineAt(DateTime.now());

  // Spine at a historical date, derived by rewinding current experience.
  SpinePoint _spineAt(DateTime date) {
    final yearsAtDate =
        _yearsExperience - DateTime.now().difference(date).inDays / 365.25;
    final y = yearsAtDate.clamp(0.0, double.infinity);
    if (y < 2) return SpinePoint.entry;
    if (y < 4) return SpinePoint.intermediate;
    return SpinePoint.top;
  }

  CalcResult? _result;
  String _displayName = '';
  final _hmrcInvalidYears = <PayYear>{};

  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_recalculate);
    for (final c in _hmrcControllers.values) {
      c.addListener(_recalculate);
    }
    _recalculate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _hmrcControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _reveal() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => _ResultScreen(
          result: _result!,
          name: _displayName,
          backPayStart: _backPayStart,
          effectiveAfcDate: _effectiveAfcDate,
          mode: _mode,
          pension: _pension,
        ),
        transitionsBuilder: (context, animation, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

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

      final spineForPeriod = _spineAt(periodStart);

      if (_mode == CalcMode.payScale) {
        years.add(calculateFromScales(
          year: year,
          spine: spineForPeriod,
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
          spine: spineForPeriod,
          contractedHours: _hours,
          hmrcEarnings: earnings,
          periodStart: periodStart,
          periodEnd: periodEnd,
          includePension: _pension,
        ));
      }
    }

    final invalidYears = <PayYear>{};
    for (final year in PayYear.values) {
      final raw = _hmrcControllers[year]!.text
          .replaceAll(',', '')
          .replaceAll('£', '')
          .trim();
      if (raw.isNotEmpty) {
        final parsed = double.tryParse(raw);
        if (parsed == null || parsed <= 0) invalidYears.add(year);
      }
    }

    setState(() {
      _result = years.isEmpty ? null : CalcResult(years);
      _displayName = _nameController.text.trim();
      _hmrcInvalidYears
        ..clear()
        ..addAll(invalidYears);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                  const SizedBox(height: 12),
                  _modeCard(),
                  const SizedBox(height: 20),
                  _employmentCard(),
                  const SizedBox(height: 16),
                  _backPayStartCard(),
                  if (_mode == CalcMode.hmrc) ...[
                    const SizedBox(height: 12),
                    _hmrcCard(),
                  ],
                  const SizedBox(height: 16),
                  _effectiveAfcDateCard(),
                  const SizedBox(height: 40),
                  const Divider(),
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

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _nameCard() => _card(
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Your first name',
            hintText: 'e.g. Zoe',
            helperText: 'Optional — personalises your results',
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
                setState(() => _mode = s.first);
                _recalculate();
              },
            ),
            const SizedBox(height: 8),
            Text(
              _mode == CalcMode.payScale
                  ? 'Uses published NHS Scotland pay tables. Back pay = Band 6 salary − Band 5 salary for each year.'
                  : 'Uses your actual gross earnings from HMRC vs Band 6 expected pay. More accurate if you received overtime pay or shift enhancements.',
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ],
        ),
      );

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
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
              semanticFormatterCallback: (v) =>
                  '${v % 1 == 0 ? v.toInt() : v} years of experience',
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
              semanticFormatterCallback: (v) =>
                  '${v % 1 == 0 ? v.toInt() : v} contracted hours per week',
              onChanged: (v) {
                setState(() => _hours = v);
                _recalculate();
              },
            ),
            Row(
              children: [
                Text('8',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                Text('22.5',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                Text('30',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                Text('37.5 hrs',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 20),
            const Text('NHS Pension',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Opted in')),
                ButtonSegment(value: false, label: Text('Opted out')),
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
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _backPayStartCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Back pay start date',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'When your Specialist Nursing role effectively began — back pay is calculated from this date.',
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
            const SizedBox(height: 12),
            _infoTip(
                'The earliest eligible date is 1 April 2023, as set out in AfC Pay Circular PCS(AFC)2024/3.'),
            const SizedBox(height: 16),
            _dateField(
              label: 'Starting from',
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
            style: TextStyle(fontSize: 13, color: _textSecondary),
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

  Widget _hmrcRow(PayYear year) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _hmrcControllers[year],
          decoration: InputDecoration(
            labelText: '${year.label} gross earnings',
            border: const OutlineInputBorder(),
            prefixText: '£ ',
            hintText: 'e.g. 32,000.00',
            errorText: _hmrcInvalidYears.contains(year)
                ? 'Enter an amount above £0'
                : null,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
          ],
        ),
      );

  Widget _effectiveAfcDateCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Band 6 start date',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'The date you start (or started) receiving Band 6 pay under Agenda for Change (AfC). Back pay is calculated up to this date.',
              style: TextStyle(fontSize: 13, color: _textSecondary),
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
    return Semantics(
      label: '$label: ${_dateFmt.format(date)}',
      button: true,
      excludeSemantics: true,
      child: InkWell(
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
    ));
  }

  // ── Results section ───────────────────────────────────────────────────────

  Widget _resultsSection() {
    if (_result == null) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const Icon(Icons.calculate_outlined,
                  size: 40, color: _mintBadge),
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
    }

    return Column(
      children: [
        Text(
          'Your estimate is ready',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _teal),
        ),
        const SizedBox(height: 12),
        _RevealButton(onPressed: _reveal),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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
              child: Text(text,
                  style: const TextStyle(fontSize: 12, color: _teal)),
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
                style: TextStyle(fontSize: 13, color: _textSecondary)),
            const SizedBox(height: 4),
            Text(
              'Well done Zoe and those at NSD on the recognition of your specialised work ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ],
        ),
      );

  Widget _card({required Widget child}) => Card(
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      );
}

// ── Full-screen result view ───────────────────────────────────────────────

class _ResultScreen extends StatefulWidget {
  const _ResultScreen({
    required this.result,
    required this.name,
    required this.backPayStart,
    required this.effectiveAfcDate,
    required this.mode,
    required this.pension,
  });

  final CalcResult result;
  final String name;
  final DateTime backPayStart;
  final DateTime effectiveAfcDate;
  final CalcMode mode;
  final bool pension;

  @override
  State<_ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<_ResultScreen>
    with SingleTickerProviderStateMixin {
  static const _teal = Color(0xFF005C69);
  static const _gold = Color(0xFFFFC837);
  static const _mintBadge = Color(0xFFCCEDE9);

  late final AnimationController _ctrl;
  late final Animation<double> _counterAnim;
  late final Animation<double> _fadeAnim;

  final _fmt =
      NumberFormat.currency(locale: 'en_GB', symbol: '£', decimalDigits: 2);
  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _counterAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.65, curve: Curves.easeOutExpo)),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.45, 1.0, curve: Curves.easeOut)),
    );
    Future.delayed(const Duration(milliseconds: 300),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return Scaffold(
      backgroundColor: _teal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Your Back Pay Estimate',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final done = _ctrl.status == AnimationStatus.completed;
          final net = done ? r.totalNet : r.totalNet * _counterAnim.value;
          final fade = _fadeAnim.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Personalised greeting
                if (widget.name.isNotEmpty) ...[
                  Text(
                    'Congratulations, ${widget.name}.',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'We hope you feel recognised for the work that you do. We would be a worse society without you.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                ] else
                  const SizedBox(height: 8),

                // Hero — take-home (animated) and gross side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Take-home estimate',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            _fmt.format(net),
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Opacity(
                        opacity: fade,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Gross back pay',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              _fmt.format(r.totalGross),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: fade,
                  child: Text(
                    '${_dateFmt.format(widget.backPayStart)} → ${_dateFmt.format(widget.effectiveAfcDate)}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),

                const SizedBox(height: 32),

                // Summary breakdown card
                Opacity(opacity: fade, child: _breakdownCard(r)),

                const SizedBox(height: 16),

                // Per-year detail cards
                Opacity(
                  opacity: fade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: r.years.map(_yearCard).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Disclaimer
                Opacity(
                  opacity: fade,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'These are estimates based on published NHS Scotland pay scales and standard Scottish tax rates. '
                      'Your actual back pay may differ — please verify with your payroll department.',
                      style: TextStyle(
                          color: Colors.white60, fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _breakdownCard(CalcResult r) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How it breaks down',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 16),
            _row('Total gross back pay', r.totalGross),
            _row('  Income tax (est.)', -r.totalTax),
            _row('  National Insurance (est.)', -r.totalNI),
            if (widget.pension)
              _row('  Pension contribution (est.)', -r.totalPension),
            const Divider(height: 24),
            _row('Take-home estimate', r.totalNet, bold: true, color: _teal),
          ],
        ),
      );

  Widget _yearCard(YearResult y) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _mintBadge,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(y.year.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _teal,
                            fontSize: 13)),
                  ),
                  const Spacer(),
                  Text(_fmt.format(y.grossBackPay),
                      style: const TextStyle(
                          fontSize: 13,
                          color: _teal,
                          fontWeight: FontWeight.w700)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('→',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400])),
                  ),
                  Text(_fmt.format(y.net),
                      style: const TextStyle(
                          fontSize: 13,
                          color: _teal,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              children: [
                _row(
                  widget.mode == CalcMode.payScale
                      ? 'Band 5 pay (this period)'
                      : 'Your HMRC earnings',
                  y.proRatedOldSalary,
                ),
                _row(
                  widget.mode == CalcMode.payScale
                      ? 'Band 6 pay (this period)'
                      : 'Expected Band 6 pay',
                  y.proRatedNewSalary,
                ),
                _row('Gross back pay', y.grossBackPay, bold: true),
                _row('  Income tax (est.)', -y.incomeTax),
                _row('  National Insurance (est.)', -y.nationalInsurance),
                if (widget.pension)
                  _row('  Pension contribution (est.)', -y.pension),
                const Divider(height: 20),
                _row('Take-home', y.net, bold: true, color: _teal),
              ],
            ),
          ),
        ),
      );

  Widget _row(String label, double value, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      color: color ?? Colors.black87,
      fontSize: 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
}

// ── Animated Reveal Button ────────────────────────────────────────────────

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
    _scale = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
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
            backgroundColor: const Color(0xFFFFC837),
            foregroundColor: Colors.black87,
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
