library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as international; // this package has a TextDirection which interferes with material.dart

enum EventAlignment { earlyPartial, latePartial, bothPartial, full }

typedef TimeEventWidgetBuilder = Widget Function(TimeEvent event, double maximumHeight, double pixelsPerMinute, EventAlignment eventAlignment);

const _defaultDateLabelFormat = "d MMMM yyyy";
const _defaultDateLabelStyle = TextStyle();
const _defaultTimelineStyle = TextStyle();
const _defaultLaneTitleStyle = TextStyle();
const _dividerHeight = 4.0;

const double timelineHeight = 25;

class TimeEvent {
  DateTime start;
  DateTime? end;
  int laneIndex;
  int priority;
  TimeEventWidgetBuilder? builder;
  String title;
  double offsetLeft;
  TextStyle? titleStyle;

  TimeEvent({
    required this.start,
    this.end,
    required this.laneIndex,
    this.priority = 1,
    this.builder,
    required this.title,
    this.offsetLeft = 0,
  });
}

enum TimelaneTitlePosition { left, right, both }

class Timelanes extends StatelessWidget {
  final List<String> lanesAbove;
  final List<String> lanesBelow;
  final DateTime earliestDate;
  final DateTime latestDate;
  final double? dateLabelOffset;
  final String? dateLabelFormat;
  final TextStyle dateLabelStyle;
  final TextStyle timelineStyle;
  final TextStyle laneTitleStyle;
  final TimelaneTitlePosition laneTitlePosition;
  final Axis laneTitleOrientation;
  final bool showSwimlanes;
  final TimeEventWidgetBuilder? fallbackEventBuilder;
  final List<TimeEvent>? events;

  const Timelanes({
    super.key,
    required this.earliestDate,
    required this.latestDate,
    List<String>? lanesAbove,
    List<String>? lanesBelow,
    this.dateLabelOffset,
    this.dateLabelFormat = _defaultDateLabelFormat,
    this.dateLabelStyle = _defaultDateLabelStyle,
    this.timelineStyle = _defaultTimelineStyle,
    this.laneTitleStyle = _defaultLaneTitleStyle,
    this.laneTitlePosition = TimelaneTitlePosition.left,
    this.laneTitleOrientation = Axis.horizontal,
    this.showSwimlanes = true,
    this.fallbackEventBuilder,
    this.events,
  })  : lanesAbove = lanesAbove ?? const <String>[],
        lanesBelow = lanesBelow ?? const <String>[];

  int get laneCount => lanesAbove.length + lanesBelow.length;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      if (laneCount == 0) {
        return buildTimeline(constraints.maxWidth);
      }
      double availableLanesHeight = constraints.maxHeight - timelineHeight;
      if (showSwimlanes) {
        availableLanesHeight -= (_dividerHeight * (laneCount + 1));
      }
      double heightPerLane = availableLanesHeight / laneCount;
      return buildTimelanes(context, constraints, heightPerLane, constraints.maxWidth);
    });
  }

  // TODO: make separate title Widget instead of placing a title Widget within a lane
  Widget buildTimelanes(BuildContext context, BoxConstraints constraints, double laneHeight, double laneWidth) {
    Size maxLanesAboveTitleSize = _maxTextSize(lanesAbove, laneTitleStyle);
    Size maxLanesBelowTitleSize = _maxTextSize(lanesBelow, laneTitleStyle);
    double maxLaneTitleWidth = max(maxLanesAboveTitleSize.width, maxLanesBelowTitleSize.width);

    double remainingLaneWidth = constraints.maxWidth - maxLaneTitleWidth;
    if (laneTitlePosition == TimelaneTitlePosition.both) {
      remainingLaneWidth = constraints.maxWidth - (maxLaneTitleWidth * 2);
    }

    Map<TimeEvent, Widget> eventWidgets = createEventWidgets(events, remainingLaneWidth, maxLaneTitleWidth, laneHeight);

    List<Widget> rows = List<Widget>.empty(growable: true);

    for (int index = 0; index < lanesAbove.length; index++) {
      if (showSwimlanes) {
        rows.add(const Divider(height: _dividerHeight));
      }

      List<TimeEvent> laneEvents = eventsForLane(events, index);
      List<TimeEvent> sortedEvents = sortEventsPriorityDescending(laneEvents);

      rows.add(buildLane(sortedEvents, eventWidgets, lanesAbove[index], laneWidth, laneHeight));
    }

    rows.add(buildTimeline(laneWidth));
    if (showSwimlanes) {
      rows.add(const Divider(height: _dividerHeight));
    }

    for (int index = 0; index < lanesBelow.length; index++) {
      int laneIndex = index + lanesAbove.length;

      List<TimeEvent> laneEvents = eventsForLane(events, laneIndex);
      List<TimeEvent> sortedEvents = sortEventsPriorityDescending(laneEvents);

      rows.add(buildLane(sortedEvents, eventWidgets, lanesBelow[index], laneWidth, laneHeight));

      if (showSwimlanes) {
        rows.add(const Divider(height: _dividerHeight));
      }
    }

    return Column(children: rows);
  }

  Widget buildLane(List<TimeEvent> events, Map<TimeEvent, Widget> eventWidgets, String title, double laneWidth, double laneHeight) {
    List<Widget> children = List<Widget>.empty(growable: true);

    if (laneTitlePosition == TimelaneTitlePosition.left || laneTitlePosition == TimelaneTitlePosition.both) {
      children.add(_buildLaneTitle(title, laneTitleOrientation, laneTitleStyle, laneHeight, laneWidth, TimelaneTitlePosition.left));
    }

    for (var event in events) {
      Widget? widget = eventWidgets[event];
      if (widget != null) {
        children.add(widget);
      }
    }

    if (laneTitlePosition == TimelaneTitlePosition.right || laneTitlePosition == TimelaneTitlePosition.both) {
      children.add(_buildLaneTitle(title, laneTitleOrientation, laneTitleStyle, laneHeight, laneWidth, TimelaneTitlePosition.right));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
      width: laneWidth,
      height: laneHeight,
      clipBehavior: Clip.none,
      child: Stack(children: children),
    );
  }

  Widget _buildLaneTitle(String text, Axis orientation, TextStyle style, double laneHeight, double laneWidth, TimelaneTitlePosition alignment) {
    text = text.replaceAll("\\n", "\n");
    if (orientation == Axis.horizontal) {
      Size titleSize = _textSize(text, style, width: 500);
      double top = (laneHeight / 2) - (titleSize.height / 2);
      double left = alignment == TimelaneTitlePosition.right ? laneWidth - (titleSize.width + 10) : 0;
      return Positioned(
          left: left,
          top: top,
          child: SizedBox(
            width: titleSize.width + 4,
            child: Text(
              text,
              style: style,
              maxLines: 5,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ));
    } else {
      double titleWidth = min(laneHeight, 150);
      Size titleSize = _textSize(text, style, width: titleWidth);
      double top = (laneHeight / 2) - (titleSize.width / 2);
      double left = alignment == TimelaneTitlePosition.right ? laneWidth - (titleSize.height + 10) : 0;
      return Positioned(
          left: left,
          top: top,
          child: SizedBox(
            width: titleSize.height + 4,
            height: titleSize.width + 4,
            child: RotatedBox(
                quarterTurns: -1,
                child: Text(
                  text,
                  style: style,
                  maxLines: 5,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                )),
          ));
    }
  }

  Widget buildTimeline(double laneWidth) {
    Duration timelineDuration = latestDate.difference(earliestDate);

    String earliestDateText = formatDateTime(earliestDate, timelineDuration, dateLabelFormat);
    String latestDateText = formatDateTime(latestDate, timelineDuration, dateLabelFormat);

    return SizedBox(
      width: laneWidth,
      height: timelineHeight,
      child: Column(children: [
        //  TODO: intermediate ticks: calculate total time and pick a good intermediate tick frequency
        const Divider(height: 5),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(earliestDateText),
              Text(latestDateText),
            ]),
          ),
        ),
      ]),
    );
  }

  Map<TimeEvent, Widget> createEventWidgets(List<TimeEvent>? events, double laneWidth, double left, double laneHeight) {
    Map<TimeEvent, Widget> result = {};
    Duration timelineDuration = latestDate.difference(earliestDate);
    double pixelsPerMinute = laneWidth / timelineDuration.inMinutes;
    events?.forEach((TimeEvent event) {
      if (event.laneIndex < 0 || event.laneIndex >= laneCount) {
        return;
      }
      if (event.start.isAfter(latestDate)) {
        return;
      }
      if (event.end == null && event.start.isBefore(earliestDate)) {
        return;
      }
      if (event.end != null && event.end!.isBefore(earliestDate)) {
        return;
      }

      EventAlignment eventAlignment;
      if (event.end == null || (!event.start.isBefore(earliestDate) && !event.end!.isAfter(latestDate))) {
        eventAlignment = EventAlignment.full;
      } else if (event.start.isBefore(earliestDate)) {
        if (event.end!.isAfter(latestDate)) {
          eventAlignment = EventAlignment.bothPartial;
        } else {
          eventAlignment = EventAlignment.earlyPartial;
        }
      } else {
        eventAlignment = EventAlignment.latePartial;
      }

      Widget eventWidget;
      if (event.builder != null) {
        eventWidget = event.builder!(event, laneHeight, pixelsPerMinute, eventAlignment);
      } else if (fallbackEventBuilder != null) {
        eventWidget = fallbackEventBuilder!(event, laneHeight, pixelsPerMinute, eventAlignment);
      } else if (event.title != "") {
        eventWidget = Text(event.title);
      } else {
        return;
      }

      Duration eventOffset = event.start.difference(earliestDate);
      double eventOffsetRatio = eventOffset.inSeconds / timelineDuration.inSeconds;
      double eventLeft = left + event.offsetLeft + (laneWidth * eventOffsetRatio);

      result[event] = Positioned(left: eventLeft, child: eventWidget);
    });
    return result;
  }

  static List<TimeEvent> sortEventsPriorityDescending(List<TimeEvent> laneEvents) {
    laneEvents.sort((TimeEvent event2, event1) => event1.priority.compareTo(event2.priority));
    return laneEvents;
  }

  static List<TimeEvent> eventsForLane(List<TimeEvent>? events, int laneIndex) {
    List<TimeEvent> result = List<TimeEvent>.empty(growable: true);
    events?.forEach((TimeEvent event) {
      if (event.laneIndex == laneIndex) {
        result.add(event);
      }
    });
    return result;
  }
}

Widget createTimePeriod(
    {required Color color,
    required double rowHeight,
    required DateTime start,
    required DateTime end,
    required double pixelsPerMinute,
    String? title,
    TextStyle? titleStyle,
    EventAlignment eventAlignment = EventAlignment.full}) {
  Duration duration = end.difference(start);
  double width = duration.inMinutes * pixelsPerMinute;
  if (title == null) {
    return SizedBox(width: width, height: rowHeight, child: ColoredBox(color: color));
  } else {
    Size titleSize = _textSize(title, titleStyle ?? const TextStyle());
    if (titleSize.width > width) {
      eventAlignment = EventAlignment.full;
    }
    MainAxisAlignment titleAlign = MainAxisAlignment.center;
    Widget? box;
    switch (eventAlignment) {
      case EventAlignment.full:
      case EventAlignment.bothPartial:
        box = ColoredBox(color: color, child: Center(child: Text(title, style: titleStyle)));
      case EventAlignment.earlyPartial:
        titleAlign = MainAxisAlignment.end;
      case EventAlignment.latePartial:
        titleAlign = MainAxisAlignment.start;
    }
    box ??= ColoredBox(
        color: color, child: Row(mainAxisAlignment: titleAlign, crossAxisAlignment: CrossAxisAlignment.center, children: [Text(title, style: titleStyle)]));

    return SizedBox(width: width, height: rowHeight, child: box);
  }
}

Size _textSize(String text, TextStyle style, {double width = double.infinity}) {
  final TextPainter textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(text: text, style: style),
  )..layout(minWidth: 0, maxWidth: width);
  return textPainter.size;
}

Size _maxTextSize(List<String>? texts, TextStyle style) {
  double width = 0;
  double height = 0;
  if (texts != null) {
    for (String text in texts) {
      Size size = _textSize(text, style);
      if (size.width > width) {
        width = size.width;
      }
      if (size.height > height) {
        height = size.height;
      }
    }
  }
  return Size(width, height);
}

String formatDateTime(DateTime dateTime, Duration scope, String? format) {
  if (format == null) {
    if (scope < const Duration(days: 1)) {
      format = "HH:mm";
    } else if (scope < const Duration(days: 365)) {
      format = "dd MMMM yy";
    } else if (scope < const Duration(days: 1500)) {
      format = "MMMM yyyy";
    } else {
      format = "yyyy";
    }
  }
  international.DateFormat dateFormatter = international.DateFormat(format);
  return dateFormatter.format(dateTime);
}
