# Timelanes

Displays Flutter widgets positioned horizontally by date within a date range, organised vertically into named swimlanes.

![Empires over time](readme-example-1.jpg?raw=true)
![NASA launch sequence](readme-example-2.jpg?raw=true)

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  timelanes: ^0.9.0
```

## Quick start

`Timelanes` must have a bounded height. Wrap it in an `Expanded` or give it a fixed height.

```dart
import 'package:timelanes/timelanes.dart';

Expanded(
  child: Timelanes(
    earliestDate: DateTime(1330),
    latestDate: DateTime(1850),
    lanesAbove: ['Europe', 'Asia'],
    lanesBelow: ['Americas'],
    events: [
      TimeEvent(
        start: DateTime(1500),
        end: DateTime(1700),
        title: 'An Era',
        laneIndex: 0,
      ),
    ],
  ),
)
```

Without a builder, each `TimeEvent` renders its `title` as a `Text` widget.

## Core concepts

### Lanes

Lanes are named horizontal rows. They sit above and/or below the central timeline ruler.

- `lanesAbove` — list of lane names rendered above the timeline
- `lanesBelow` — list of lane names rendered below the timeline
- Lane indices are zero-based and count from `lanesAbove[0]` to `lanesBelow[last]`

```
lanesAbove[0]   ← laneIndex 0
lanesAbove[1]   ← laneIndex 1
──── timeline ────
lanesBelow[0]   ← laneIndex 2
lanesBelow[1]   ← laneIndex 3
```

### Events

Each `TimeEvent` places a widget in a lane at a horizontal position determined by its date.

| Property | Type | Required | Description |
|---|---|---|---|
| `start` | `DateTime` | yes | Horizontal position of the event |
| `end` | `DateTime?` | no | If set, the widget spans from `start` to `end` |
| `laneIndex` | `int` | yes | Zero-based lane index |
| `title` | `String` | yes | Displayed as `Text` when no builder is provided |
| `builder` | `TimeEventWidgetBuilder?` | no | Returns the widget for this event |
| `priority` | `int` | no | Higher value renders on top when events overlap (default `1`) |
| `offsetLeft` | `double` | no | Additional horizontal pixel offset (default `0`) |
| `titleStyle` | `TextStyle?` | no | Passed to the event's widget builder |

Events outside the `earliestDate`–`latestDate` range are silently ignored.

### Builder function

Both `TimeEvent.builder` and `Timelanes.fallbackEventBuilder` share the same signature:

```dart
typedef TimeEventWidgetBuilder = Widget Function(
  TimeEvent event,
  double maximumHeight,    // available lane height in pixels
  double pixelsPerMinute,  // horizontal scale
  EventAlignment eventAlignment,
);
```

`EventAlignment` tells you whether the event's date range extends outside the visible window:

| Value | Meaning |
|---|---|
| `full` | Entirely within `earliestDate`–`latestDate` |
| `earlyPartial` | Starts before `earliestDate` |
| `latePartial` | Ends after `latestDate` |
| `bothPartial` | Spans the entire visible range |

Use `eventAlignment` to decide whether to render rounded corners, arrows, or clipped edges.

## Timelanes widget parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `earliestDate` | `DateTime` | required | Left edge of the timeline |
| `latestDate` | `DateTime` | required | Right edge of the timeline |
| `lanesAbove` | `List<String>?` | `[]` | Lane names above the timeline |
| `lanesBelow` | `List<String>?` | `[]` | Lane names below the timeline |
| `events` | `List<TimeEvent>?` | — | Events to render |
| `fallbackEventBuilder` | `TimeEventWidgetBuilder?` | — | Used for events with no `builder` |
| `dateLabelFormat` | `String?` | auto | `intl` date format for the timeline labels; auto-selected from scope when `null` |
| `dateLabelOffset` | `double?` | — | Horizontal offset for date labels |
| `dateLabelStyle` | `TextStyle` | `TextStyle()` | Style for timeline date labels |
| `timelineStyle` | `TextStyle` | `TextStyle()` | Reserved for future use |
| `laneTitleStyle` | `TextStyle` | `TextStyle()` | Style for lane name labels |
| `laneTitlePosition` | `TimelaneTitlePosition` | `.left` | Where lane names appear |
| `laneTitleOrientation` | `Axis` | `Axis.horizontal` | Horizontal or vertical lane name text |
| `showSwimlanes` | `bool` | `true` | Show divider lines between lanes |

### Lane title position

```dart
enum TimelaneTitlePosition { left, right, both }
```

`both` renders the lane name at both the left and right edges of the lane.

### Date label format

When `dateLabelFormat` is `null`, the format is chosen automatically based on the span of `earliestDate`–`latestDate`:

| Span | Format |
|---|---|
| < 1 day | `HH:mm` |
| < 365 days | `dd MMMM yy` |
| < 1500 days | `MMMM yyyy` |
| ≥ 1500 days | `yyyy` |

Pass any [intl DateFormat pattern](https://pub.dev/documentation/intl/latest/intl/DateFormat-class.html) to override.

## Built-in helpers

### createTimePeriod

Renders a coloured bar spanning a date range, with an optional centred label. Useful as the return value of a `builder`.

```dart
TimeEvent(
  start: DateTime(1702),
  end: DateTime(1860),
  title: 'Colonial era',
  laneIndex: 0,
  builder: (event, maximumHeight, pixelsPerMinute, eventAlignment) {
    return createTimePeriod(
      color: Colors.blueGrey,
      rowHeight: maximumHeight,
      start: event.start,
      end: event.end!,
      pixelsPerMinute: pixelsPerMinute,
      title: event.title,
      eventAlignment: eventAlignment,
    );
  },
)
```

The label is positioned based on `eventAlignment` so it stays readable when the bar is clipped at the edge of the visible range.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `color` | `Color` | yes | Bar fill colour |
| `rowHeight` | `double` | yes | Height of the bar in pixels |
| `start` | `DateTime` | yes | Bar start date |
| `end` | `DateTime` | yes | Bar end date |
| `pixelsPerMinute` | `double` | yes | Pass through from the builder |
| `title` | `String?` | no | Label rendered inside the bar |
| `titleStyle` | `TextStyle?` | no | Style for the label |
| `eventAlignment` | `EventAlignment` | no | Controls label position (default `full`) |

### formatDateTime

Formats a `DateTime` using intl, with the same auto-format logic used by the timeline labels.

```dart
String label = formatDateTime(someDate, timelineDuration, 'dd MMM yyyy');
```

## Complete example

```dart
Expanded(
  child: Timelanes(
    earliestDate: DateTime(200),
    latestDate: DateTime(1500),
    lanesAbove: ['China', 'India', 'Africa', 'Europe', 'Americas'],
    laneTitlePosition: TimelaneTitlePosition.both,
    dateLabelFormat: 'yyyy',
    fallbackEventBuilder: (event, maximumHeight, pixelsPerMinute, eventAlignment) {
      return createTimePeriod(
        color: Colors.teal,
        rowHeight: maximumHeight,
        start: event.start,
        end: event.end ?? event.start.add(const Duration(days: 365)),
        pixelsPerMinute: pixelsPerMinute,
        title: event.title,
        eventAlignment: eventAlignment,
      );
    },
    events: [
      TimeEvent(
        start: DateTime(300),
        end: DateTime(1230),
        title: 'Ghana Empire',
        laneIndex: 2,
      ),
      TimeEvent(
        start: DateTime(800),
        end: DateTime(1806),
        title: 'Holy Roman Empire',
        laneIndex: 3,
        priority: 2,
        builder: (event, maximumHeight, pixelsPerMinute, eventAlignment) {
          return createTimePeriod(
            color: Colors.black,
            rowHeight: maximumHeight,
            start: event.start,
            end: event.end!,
            pixelsPerMinute: pixelsPerMinute,
            title: event.title,
            titleStyle: const TextStyle(color: Colors.white),
            eventAlignment: eventAlignment,
          );
        },
      ),
    ],
  ),
)
```

## Notes

- `Timelanes` must be a descendant of a `Directionality` widget (satisfied by `MaterialApp` or `WidgetsApp`).
- Events whose `laneIndex` is out of range are silently dropped.
- `priority` controls `Stack` ordering within a lane: higher values render on top.
- This is a hobby project. Issues and pull requests are welcome on [GitHub](https://github.com/richardhaven/timelanes).
