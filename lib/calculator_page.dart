import 'dart:math';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html show window;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'domain/calculator.dart';
import 'domain/pay_scales.dart';

enum CalcMode { payScale, hmrc }

// ── Page ──────────────────────────────────────────────────────────────────────

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage>
    with SingleTickerProviderStateMixin {
  static const _teal = Color(0xFF005C69);
  static const _gold = Color(0xFFFFC837);
  static const _mintBadge = Color(0xFFCCEDE9);
  static const _textSecondary = Color(0xFF677C7E);
  static const _borderColor = Color(0xFFD8EDEA);

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

  SpinePoint get _spine => _spineAt(DateTime.now());

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

  // Pulse animation for the empty-state icon
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_recalculate);
    for (final c in _hmrcControllers.values) {
      c.addListener(_recalculate);
    }

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _recalculate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _hmrcControllers.values) {
      c.dispose();
    }
    _pulseCtrl.dispose();
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
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(context),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 28),
                      _section('01', 'Your name', _nameField()),
                      const SizedBox(height: 24),
                      _section('02', 'Calculation method', _modeSelector()),
                      const SizedBox(height: 24),
                      _section('03', 'Your employment', _employmentContent()),
                      const SizedBox(height: 24),
                      _section('04', 'Pay period', _periodContent()),
                      const SizedBox(height: 40),
                      _resultsSection(),
                      const SizedBox(height: 48),
                      _footer(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ClipPath(
      clipper: _HeroClipper(),
      child: Container(
        color: _teal,
        padding: EdgeInsets.fromLTRB(24, topPad + 36, 16, 68),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22), width: 1),
                    ),
                    child: Text(
                      'NHS Scotland  ·  AfC Review',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Band 5 Review\nCalculator',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Band 5 → Band 6  ·  Find out what back pay you\'re owed.',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Decorative element — overlapping circles + gold dot
            SizedBox(
              width: 76,
              height: 90,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _circle(64, Colors.white.withValues(alpha: 0.07)),
                  ),
                  Positioned(
                    right: 22,
                    top: 28,
                    child: _circle(38, Colors.white.withValues(alpha: 0.055)),
                  ),
                  Positioned(
                    right: 8,
                    top: 56,
                    child: _circle(20, _gold.withValues(alpha: 0.5)),
                  ),
                  Positioned(
                    right: 44,
                    top: 10,
                    child: _circle(10, Colors.white.withValues(alpha: 0.2)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  // ── Section layout ────────────────────────────────────────────────────────

  Widget _section(String number, String title, Widget content) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _teal,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          _styledCard(content),
        ],
      );

  Widget _styledCard(Widget child) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: _teal.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: child,
      );

  // ── Section content builders ──────────────────────────────────────────────

  Widget _nameField() => TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Your first name',
          hintText: 'e.g. Zoe',
          helperText: 'Optional — personalises your results',
          border: OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
      );

  Widget _modeSelector() => Column(
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
                ? 'Uses published NHS Scotland pay tables. Back pay = Band 6 expected rate − Band 5 paid rate, for each year.'
                : 'Uses your actual gross earnings from HMRC compared to the expected Band 6 rate. More accurate if you received overtime or shift enhancements.',
            style: const TextStyle(fontSize: 13, color: _textSecondary),
          ),
        ],
      );

  Widget _employmentContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
      );

  Widget _periodContent() {
    final relevantYears = PayYear.values.where((year) {
      final yearEnd = DateTime(year.endYear, 3, 31);
      return !_backPayStart.isAfter(yearEnd) &&
          !_effectiveAfcDate.isBefore(year.awardDate);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back pay start
        const Text('Back pay start date',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 4),
        const Text(
          'When your Specialist Nursing role effectively began — back pay is calculated from this date.',
          style: TextStyle(fontSize: 13, color: _textSecondary),
        ),
        const SizedBox(height: 10),
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

        const SizedBox(height: 20),
        const Divider(height: 1, color: Color(0xFFECF5F4)),
        const SizedBox(height: 20),

        // AFC date
        const Text('Band 6 start date',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 4),
        const Text(
          'The date you start (or started) receiving Band 6 pay under AfC. Back pay is calculated up to this date.',
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

        // HMRC earnings (mode-conditional)
        if (_mode == CalcMode.hmrc) ...[
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFECF5F4)),
          const SizedBox(height: 20),
          const Text('Your HMRC gross earnings',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          const Text(
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
      ],
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

  // ── Results section ───────────────────────────────────────────────────────

  Widget _resultsSection() {
    if (_result == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor, width: 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _mintBadge.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings_outlined,
                    size: 32, color: _teal),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _mode == CalcMode.hmrc
                  ? 'Enter your HMRC earnings above'
                  : 'Fill in your details above',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _teal),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your back pay estimate will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: _mintBadge,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: _teal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your estimate is ready',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _teal),
                    ),
                    Text(
                      'Tap below to see your figures',
                      style:
                          TextStyle(fontSize: 12, color: _textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _RevealButton(onPressed: _reveal),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  Widget _infoTip(String text) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _teal, width: 3)),
          color: Color(0xFFD9F0ED),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 14, color: _teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, color: _teal, height: 1.4)),
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
          child:
              Text(_dateFmt.format(date), style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }

  void _openUrl(String url) => html.window.open(url, '_blank');

  Widget _link(String label, String url) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _openUrl(url),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: _teal,
              decoration: TextDecoration.underline,
              decorationColor: _teal.withValues(alpha: 0.4),
              decorationThickness: 1,
            ),
          ),
        ),
      );

  Widget _footer() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Made by ',
                    style: TextStyle(fontSize: 13, color: _textSecondary)),
                _link('Aidan Neil',
                    'https://www.linkedin.com/in/aidan-neil/'),
                Text(' · ',
                    style: TextStyle(fontSize: 13, color: _textSecondary)),
                _link('Kelvin Systems', 'https://kelvin.systems'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Well done Zoe and those at NSD on the recognition of your specialised work ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ],
        ),
      );
}

// ── Hero clip path ────────────────────────────────────────────────────────────

class _HeroClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 28)
      ..quadraticBezierTo(size.width * 0.5, size.height + 12, 0, size.height - 28)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_HeroClipper old) => false;
}

// ── Full-screen result view ───────────────────────────────────────────────────

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
    with TickerProviderStateMixin {
  static const _teal = Color(0xFF005C69);
  static const _gold = Color(0xFFFFC837);
  static const _mintBadge = Color(0xFFCCEDE9);

  late final AnimationController _ctrl;
  late final Animation<double> _counterAnim;
  late final Animation<double> _fadeAnim;

  late final AnimationController _confettiCtrl;
  late final Animation<double> _confettiAnim;
  final List<_ConfettiParticle> _particles =
      _generateParticles(Random(42), 55);

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

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _confettiAnim = CurvedAnimation(
      parent: _confettiCtrl,
      curve: Curves.easeOut,
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _confettiCtrl.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 300),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return Scaffold(
      backgroundColor: _teal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dot grid background texture
          CustomPaint(
            painter: _DotGridPainter(color: Colors.white.withValues(alpha: 0.055)),
          ),

          // Content
          Column(
            children: [
              // Safe area + AppBar
              SafeArea(
                bottom: false,
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  foregroundColor: Colors.white,
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: const Text('Your Band 5 Review Estimate',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),

              // Scrollable body
              Expanded(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final done =
                        _ctrl.status == AnimationStatus.completed;
                    final net = done
                        ? r.totalNet
                        : r.totalNet * _counterAnim.value;
                    final fade = _fadeAnim.value;

                    return SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(24, 8, 24, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Personalised greeting
                          if (widget.name.isNotEmpty) ...[
                            Text(
                              'Congratulations, ${widget.name}.',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'I hope this feels like the recognition your work deserves. We\'d be a worse society without you.',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                          ] else
                            const SizedBox(height: 8),

                          // Hero figures
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Take-home estimate',
                                        style: GoogleFonts.outfit(
                                            color: Colors.white
                                                .withValues(alpha: 0.58),
                                            fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _fmt.format(net),
                                      style: GoogleFonts.outfit(
                                        color: _gold,
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1.5,
                                        height: 1.1,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Gross back pay',
                                          style: GoogleFonts.outfit(
                                              color: Colors.white
                                                  .withValues(alpha: 0.58),
                                              fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _fmt.format(r.totalGross),
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.5,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
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
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.38),
                                  fontSize: 12),
                            ),
                          ),

                          const SizedBox(height: 32),

                          Opacity(opacity: fade, child: _breakdownCard(r)),
                          const SizedBox(height: 16),

                          Opacity(
                            opacity: fade,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: r.years.map(_yearCard).toList(),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Opacity(
                            opacity: fade,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 1),
                              ),
                              child: Text(
                                'These are estimates based on published NHS Scotland pay scales and standard Scottish tax rates. '
                                'Your actual back pay may differ — please verify with your payroll department.',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.58),
                                    fontSize: 12,
                                    height: 1.5),
                              ),
                            ),
                          ),

                          // Bottom safe area space
                          SizedBox(
                              height:
                                  MediaQuery.of(context).padding.bottom +
                                      16),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Confetti overlay (non-interactive)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _confettiAnim,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(
                  progress: _confettiAnim.value,
                  particles: _particles,
                ),
              ),
            ),
          ),
        ],
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
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: _mintBadge,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_outlined,
                      size: 16, color: _teal),
                ),
                const SizedBox(width: 10),
                const Text('How it breaks down',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
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
            data:
                Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
                      borderRadius: BorderRadius.circular(6),
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
                            fontSize: 12,
                            color: Colors.grey[400])),
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

  Widget _row(String label, double value,
      {bool bold = false, Color? color}) {
    final labelStyle = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      color: color ?? Colors.black87,
      fontSize: 14,
    );
    final valueStyle = labelStyle.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(
            value >= 0 ? _fmt.format(value) : '-${_fmt.format(-value)}',
            style: valueStyle,
          ),
        ],
      ),
    );
  }
}

// ── Dot grid background ───────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  final Color color;

  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 22.0;
    const dotRadius = 1.2;
    final paint = Paint()..color = color;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}

// ── Confetti ──────────────────────────────────────────────────────────────────

class _ConfettiParticle {
  final double x, y;   // initial normalised position (0..1)
  final double vx, vy; // normalised velocity
  final double size;
  final Color color;
  final double rotation;
  final double spin;

  const _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.spin,
  });
}

List<_ConfettiParticle> _generateParticles(Random rng, int count) {
  const colors = [
    Color(0xFFFFC837), // gold
    Color(0xFFCCEDE9), // mint
    Colors.white,
    Color(0xFF80B5AF), // muted teal
    Color(0xFFFFE08A), // pale gold
  ];
  return List.generate(count, (_) {
    final angle = rng.nextDouble() * 2 * pi;
    final speed = rng.nextDouble() * 0.35 + 0.1;
    return _ConfettiParticle(
      x: 0.15 + rng.nextDouble() * 0.7,
      y: 0.05 + rng.nextDouble() * 0.25,
      vx: cos(angle) * speed,
      vy: sin(angle).abs() * 0.4 + 0.1,
      size: rng.nextDouble() * 8 + 3,
      color: colors[rng.nextInt(colors.length)],
      rotation: rng.nextDouble() * 2 * pi,
      spin: (rng.nextDouble() - 0.5) * pi * 6,
    );
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  const _ConfettiPainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final t = progress;
    for (final p in particles) {
      final opacity = (1.0 - t * 0.9).clamp(0.0, 1.0);
      final x = p.x * size.width + p.vx * t * size.width;
      // quadratic drop: gravity-like downward acceleration
      final y = p.y * size.height +
          p.vy * t * size.height +
          300 * t * t;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.55),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ── Animated Reveal Button ────────────────────────────────────────────────────

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
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.025)
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
