/// علامة طبقة صغيرة: لون وشكل معًا (اللون وحده لا يكفي للتمييز).
library glowara.feature.calendar.layer_mark;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:glowara/core/models/calendar_models.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/features/calendar/calendar_style.dart';

class LayerMark extends StatelessWidget {
  const LayerMark({super.key, required this.layer, this.size = 7});

  final CalendarLayer layer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = layerColor(context.glowColors, layer);
    final Widget mark;
    switch (layerShape(layer)) {
      case LayerShape.circle:
        mark = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      case LayerShape.dot:
        mark = Container(
          width: size * 0.75,
          height: size * 0.75,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      case LayerShape.ring:
        mark = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        );
      case LayerShape.diamond:
        mark = Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: size * 0.8, height: size * 0.8, color: color),
        );
      case LayerShape.square:
        mark = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        );
      case LayerShape.triangle:
        mark = Icon(Icons.change_history, size: size + 3, color: color);
    }
    return ExcludeSemantics(child: SizedBox(width: size + 3, height: size + 3, child: Center(child: mark)));
  }
}
