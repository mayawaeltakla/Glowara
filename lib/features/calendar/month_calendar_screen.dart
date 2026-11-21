/// التقويم الشهري الذكي: عرض شهر ميلادي يُظهر «وجود حياة» في كل يوم من السجلات
/// الموجودة، دون نسب إنجاز ولا تقييم ولا كتابة في قاعدة البيانات.
library glowara.feature.calendar.month_calendar;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/calendar_models.dart';
import 'package:glowara/core/repositories/calendar_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';
import 'package:glowara/features/calendar/calendar_layout.dart';
import 'package:glowara/features/calendar/calendar_style.dart';
import 'package:glowara/features/calendar/widgets/day_details.dart';
import 'package:glowara/features/calendar/widgets/layer_mark.dart';
import 'package:glowara/features/calendar/widgets/month_grid.dart';
import 'package:go_router/go_router.dart';

/// عرض الشاشة الذي يبدأ منه التخطيط العريض (عمودان).
const double kCalendarWideBreakpoint = 900;

class MonthCalendarScreen extends StatefulWidget {
  const MonthCalendarScreen({super.key, this.initialDay});

  final DateTime? initialDay;

  @override
  State<MonthCalendarScreen> createState() => _MonthCalendarScreenState();
}

class _MonthCalendarScreenState extends State<MonthCalendarScreen> {
  final Map<String, MonthSnapshot> _cache = <String, MonthSnapshot>{};
  final FocusNode _focus = FocusNode(debugLabel: 'calendar');
  late DateTime _selected;
  late DateTime _month;
  CalendarLayer? _layer;
  String? _locale;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _selected = startOfDay(widget.initialDay ?? DateTime.now());
    _month = firstOfMonth(_selected);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = AppState.of(context).locale;
    if (_locale != locale) {
      _locale = locale;
      _load();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  String _cacheKey(AppState state) => '${monthKey(_month)}|${weekStartFor(state.locale)}';

  MonthSnapshot? get _snapshot => _cache[_cacheKey(AppState.of(context))];

  Future<void> _load() async {
    final state = AppState.of(context);
    final key = _cacheKey(state);
    if (_cache.containsKey(key)) {
      setState(() => _loading = false);
      return;
    }
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await CalendarRepository(state.db).monthSnapshot(
        userId: state.userId,
        month: month,
        weekStart: weekStartFor(state.locale),
      );
      if (!mounted) return;
      _cache[key] = snapshot;
      setState(() => _loading = isSameDay(_month, month) ? false : _loading);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  /// ينتقل إلى [day] (ويعرض شهره) ويحدده.
  void _select(DateTime day) {
    final target = startOfDay(day);
    final monthChanged = !isInMonth(target, _month);
    setState(() {
      _selected = target;
      _month = firstOfMonth(target);
    });
    if (monthChanged) _load();
  }

  void _shiftMonth(int delta) {
    final month = addMonths(_month, delta);
    final day = _selected.day < daysInMonth(month) ? _selected.day : daysInMonth(month);
    _select(DateTime(month.year, month.month, day));
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (!mounted) return;
    // قد يكون الشهر تغيّر في القسم الأصلي (إضافة مهمة مثلًا).
    _cache.clear();
    _load();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && mounted) _select(picked);
  }

  void _onDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // الاتجاه نفسه الذي تنزلق إليه الصفحات: في RTL التالي إلى اليسار.
    final next = rtl ? velocity > 0 : velocity < 0;
    _shiftMonth(next ? 1 : -1);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _select(addDays(_selected, rtl ? 1 : -1));
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _select(addDays(_selected, rtl ? -1 : 1));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _select(addDays(_selected, -7));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _select(addDays(_selected, 7));
    } else if (key == LogicalKeyboardKey.pageUp) {
      _shiftMonth(-1);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _shiftMonth(1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _showDetailsSheet() {
    final c = context.glowColors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.scaffold,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: _details((String route) {
                Navigator.of(sheetContext).pop();
                _open(route);
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _details(ValueChanged<String> onOpen) {
    final state = AppState.of(context);
    final snapshot = _snapshot;
    return DayDetails(
      day: _selected,
      locale: state.locale,
      activity: snapshot?.dayFor(_selected) ?? DayActivity(),
      subjectNames: snapshot?.subjectNames ?? const <String, String>{},
      layer: _layer,
      onOpen: onOpen,
    );
  }

  Future<void> _showLegend() {
    final c = context.glowColors;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.scaffold,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  sheetContext.tr('calLegendTitle'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.onSurface),
                ),
                const SizedBox(height: 12),
                for (final layer in CalendarLayer.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: <Widget>[
                        LayerMark(layer: layer, size: 10),
                        const SizedBox(width: 12),
                        Icon(layerIcon(layer), size: 18, color: c.primary),
                        const SizedBox(width: 8),
                        Text(sheetContext.tr(layerLabelKey(layer))),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  sheetContext.tr('calLegendNote'),
                  style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    return GlowPage(
      title: context.tr('calendarTitle'),
      actions: <Widget>[
        IconButton(
          onPressed: _showLegend,
          icon: const Icon(Icons.info_outline),
          tooltip: context.tr('calLegendTitle'),
        ),
        IconButton(
          onPressed: () => _select(DateTime.now()),
          icon: const Icon(Icons.today),
          tooltip: context.tr('calToday'),
        ),
      ],
      child: Focus(
        autofocus: true,
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final wide = constraints.maxWidth >= kCalendarWideBreakpoint;
            if (_error != null) {
              return _buildError(context);
            }
            final calendar = _buildCalendar(context, state, wide);
            if (!wide) {
              return SingleChildScrollView(child: calendar);
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 3, child: SingleChildScrollView(child: calendar)),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _details(_open),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final c = context.glowColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.cloud_off_outlined, size: 36, color: c.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(context.tr('calLoadError'), style: TextStyle(color: c.onSurfaceVariant)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              _cache.clear();
              _load();
            },
            child: Text(context.tr('calRetry')),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, AppState state, bool wide) {
    final c = context.glowColors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              _chip(context.tr('calLayerAll'), _layer == null, () => setState(() => _layer = null)),
              for (final layer in CalendarLayer.values)
                _chip(
                  context.tr(layerLabelKey(layer)),
                  _layer == layer,
                  () => setState(() => _layer = layer),
                  icon: layerIcon(layer),
                ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        GestureDetector(
          onHorizontalDragEnd: _onDrag,
          child: GlowCard(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => _shiftMonth(-1),
                      icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left),
                      tooltip: context.tr('calPrevMonth'),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _pickMonth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Semantics(
                              header: true,
                              child: Text(
                                formatMonthYear(_month, state.locale),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: c.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _shiftMonth(1),
                      icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right),
                      tooltip: context.tr('calNextMonth'),
                    ),
                  ],
                ),
                MonthGrid(
                  month: _month,
                  weekStart: weekStartFor(state.locale),
                  locale: state.locale,
                  snapshot: _snapshot,
                  selected: _selected,
                  layer: _layer,
                  cellHeight: wide ? 64 : 52,
                  onSelect: (DateTime day) {
                    _select(day);
                    if (!wide) _showDetailsSheet();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GlowChoiceChip(label: label, selected: selected, onTap: onTap, icon: icon),
    );
  }
}
