import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timelanes/timelanes.dart';

void main() {
    final DateTime jan1 = DateTime(2024, 1, 1);
    final DateTime dec31 = DateTime(2024, 12, 31);

    // ---------------------------------------------------------------------------
    // formatDateTime
    // ---------------------------------------------------------------------------

    group('formatDateTime', () {
        test('uses the provided format regardless of scope', () {
            final String result = formatDateTime(jan1, const Duration(days: 3650), 'yyyy');
            expect(result, '2024');
        });

        test('chooses HH:mm for scope under one day', () {
            final DateTime afternoon = DateTime(2024, 6, 15, 14, 30);
            final String result = formatDateTime(afternoon, const Duration(hours: 12), null);
            expect(result, '14:30');
        });

        test('chooses dd MMMM yy for scope under 365 days', () {
            final String result = formatDateTime(jan1, const Duration(days: 180), null);
            expect(result, '01 January 24');
        });

        test('chooses MMMM yyyy for scope between 365 and 1499 days', () {
            final String result = formatDateTime(jan1, const Duration(days: 400), null);
            expect(result, 'January 2024');
        });

        test('chooses yyyy for scope of 1500 days or more', () {
            final String result = formatDateTime(jan1, const Duration(days: 1500), null);
            expect(result, '2024');
        });
    });

    // ---------------------------------------------------------------------------
    // eventsForLane
    // ---------------------------------------------------------------------------

    group('eventsForLane', () {
        test('returns only events whose laneIndex matches', () {
            final List<TimeEvent> events = [
                TimeEvent(start: jan1, laneIndex: 0, title: 'lane0-a'),
                TimeEvent(start: jan1, laneIndex: 1, title: 'lane1'),
                TimeEvent(start: jan1, laneIndex: 0, title: 'lane0-b'),
            ];
            final List<TimeEvent> result = Timelanes.eventsForLane(events, 0);
            expect(result.length, 2);
            expect(result.every((TimeEvent event) => event.laneIndex == 0), isTrue);
        });

        test('returns an empty list when no events match', () {
            final List<TimeEvent> events = [
                TimeEvent(start: jan1, laneIndex: 1, title: 'wrong lane'),
            ];
            expect(Timelanes.eventsForLane(events, 0), isEmpty);
        });

        test('handles a null events list gracefully', () {
            expect(Timelanes.eventsForLane(null, 0), isEmpty);
        });
    });

    // ---------------------------------------------------------------------------
    // sortEventsPriorityDescending
    // ---------------------------------------------------------------------------

    group('sortEventsPriorityDescending', () {
        test('places higher-priority events first', () {
            final List<TimeEvent> events = [
                TimeEvent(start: jan1, laneIndex: 0, title: 'low', priority: 1),
                TimeEvent(start: jan1, laneIndex: 0, title: 'high', priority: 5),
                TimeEvent(start: jan1, laneIndex: 0, title: 'mid', priority: 3),
            ];
            final List<TimeEvent> sorted = Timelanes.sortEventsPriorityDescending(events);
            expect(sorted[0].title, 'high');
            expect(sorted[1].title, 'mid');
            expect(sorted[2].title, 'low');
        });

        test('handles an empty list without error', () {
            expect(Timelanes.sortEventsPriorityDescending([]), isEmpty);
        });
    });

    // ---------------------------------------------------------------------------
    // createEventWidgets — exclusion rules
    // ---------------------------------------------------------------------------

    group('createEventWidgets — exclusions', () {
        Timelanes makeTimelanes({
            List<TimeEvent>? events,
            TimeEventWidgetBuilder? fallbackEventBuilder,
        }) {
            return Timelanes(
                earliestDate: jan1,
                latestDate: dec31,
                lanesAbove: const ['lane'],
                events: events,
                fallbackEventBuilder: fallbackEventBuilder,
            );
        }

        test('excludes events that start after latestDate', () {
            final TimeEvent event = TimeEvent(
                start: DateTime(2025, 1, 1),
                laneIndex: 0,
                title: 'future',
            );
            final Map<TimeEvent, Widget> result =
                makeTimelanes(events: [event]).createEventWidgets([event], 700, 0, 100);
            expect(result, isEmpty);
        });

        test('excludes point events (no end) that start before earliestDate', () {
            final TimeEvent event = TimeEvent(
                start: DateTime(2023, 12, 1),
                laneIndex: 0,
                title: 'past point',
            );
            final Map<TimeEvent, Widget> result =
                makeTimelanes(events: [event]).createEventWidgets([event], 700, 0, 100);
            expect(result, isEmpty);
        });

        test('excludes ranged events whose end is before earliestDate', () {
            final TimeEvent event = TimeEvent(
                start: DateTime(2023, 10, 1),
                end: DateTime(2023, 12, 1),
                laneIndex: 0,
                title: 'past range',
            );
            final Map<TimeEvent, Widget> result =
                makeTimelanes(events: [event]).createEventWidgets([event], 700, 0, 100);
            expect(result, isEmpty);
        });

        test('excludes events with an out-of-range laneIndex', () {
            final TimeEvent event = TimeEvent(
                start: DateTime(2024, 6, 1),
                laneIndex: 5,
                title: 'bad lane',
            );
            final Map<TimeEvent, Widget> result =
                makeTimelanes(events: [event]).createEventWidgets([event], 700, 0, 100);
            expect(result, isEmpty);
        });

        test('excludes events with an empty title and no builder', () {
            final TimeEvent event = TimeEvent(
                start: DateTime(2024, 6, 1),
                laneIndex: 0,
                title: '',
            );
            final Map<TimeEvent, Widget> result =
                makeTimelanes(events: [event]).createEventWidgets([event], 700, 0, 100);
            expect(result, isEmpty);
        });
    });

    // ---------------------------------------------------------------------------
    // createEventWidgets — EventAlignment assignment
    // ---------------------------------------------------------------------------

    group('createEventWidgets — EventAlignment', () {
        EventAlignment captureAlignment(TimeEvent event) {
            EventAlignment? captured;
            final Timelanes timelanes = Timelanes(
                earliestDate: jan1,
                latestDate: dec31,
                lanesAbove: const ['lane'],
            );
            final TimeEvent capturedEvent = TimeEvent(
                start: event.start,
                end: event.end,
                laneIndex: event.laneIndex,
                title: event.title,
                builder: (TimeEvent ev, double height, double ppm, EventAlignment alignment) {
                    captured = alignment;
                    return const SizedBox();
                },
            );
            timelanes.createEventWidgets([capturedEvent], 700, 0, 100);
            return captured!;
        }

        test('full — event is entirely within the range', () {
            final TimeEvent event = TimeEvent(
                start: DateTime(2024, 3, 1),
                end: DateTime(2024, 9, 1),
                laneIndex: 0,
                title: 'full',
            );
            expect(captureAlignment(event), EventAlignment.full);
        });

        test('earlyPartial — event starts before earliestDate', () {
            final TimeEvent event = TimeEvent(
                start: DateTime(2023, 6, 1),
                end: DateTime(2024, 6, 1),
                laneIndex: 0,
                title: 'early',
            );
            expect(captureAlignment(event), EventAlignment.earlyPartial);
        });

        test('latePartial — event ends after latestDate', () {
            final TimeEvent event = TimeEvent(
                start: DateTime(2024, 6, 1),
                end: DateTime(2025, 6, 1),
                laneIndex: 0,
                title: 'late',
            );
            expect(captureAlignment(event), EventAlignment.latePartial);
        });

        test('bothPartial — event spans the entire visible range', () {
            final TimeEvent event = TimeEvent(
                start: DateTime(2023, 1, 1),
                end: DateTime(2025, 1, 1),
                laneIndex: 0,
                title: 'spanning',
            );
            expect(captureAlignment(event), EventAlignment.bothPartial);
        });
    });

    // ---------------------------------------------------------------------------
    // createEventWidgets — builder selection
    // ---------------------------------------------------------------------------

    group('createEventWidgets — builder selection', () {
        test('calls event.builder when present', () {
            bool eventBuilderCalled = false;
            final TimeEvent event = TimeEvent(
                start: DateTime(2024, 6, 1),
                laneIndex: 0,
                title: 'has builder',
                builder: (TimeEvent ev, double height, double ppm, EventAlignment alignment) {
                    eventBuilderCalled = true;
                    return const SizedBox();
                },
            );
            final Timelanes timelanes = Timelanes(
                earliestDate: jan1,
                latestDate: dec31,
                lanesAbove: const ['lane'],
            );
            timelanes.createEventWidgets([event], 700, 0, 100);
            expect(eventBuilderCalled, isTrue);
        });

        test('falls back to fallbackEventBuilder when event has no builder', () {
            bool fallbackCalled = false;
            final TimeEvent event = TimeEvent(
                start: DateTime(2024, 6, 1),
                laneIndex: 0,
                title: 'no builder',
            );
            final Timelanes timelanes = Timelanes(
                earliestDate: jan1,
                latestDate: dec31,
                lanesAbove: const ['lane'],
                fallbackEventBuilder: (TimeEvent ev, double height, double ppm, EventAlignment alignment) {
                    fallbackCalled = true;
                    return const SizedBox();
                },
            );
            timelanes.createEventWidgets([event], 700, 0, 100);
            expect(fallbackCalled, isTrue);
        });

        test('wraps title in Text when no builder is available', () {
            final TimeEvent event = TimeEvent(
                start: DateTime(2024, 6, 1),
                laneIndex: 0,
                title: 'my title',
            );
            final Timelanes timelanes = Timelanes(
                earliestDate: jan1,
                latestDate: dec31,
                lanesAbove: const ['lane'],
            );
            final Map<TimeEvent, Widget> result =
                timelanes.createEventWidgets([event], 700, 0, 100);
            final Positioned positioned = result[event]! as Positioned;
            expect(positioned.child, isA<Text>());
        });
    });

    // ---------------------------------------------------------------------------
    // Timelanes widget
    // ---------------------------------------------------------------------------

    group('Timelanes widget', () {
        // Align gives loose constraints so the SizedBox can actually be 700x500.
        // dateLabelFormat 'yyyy' keeps date labels short to avoid overflow in the
        // test font environment where text renders at a larger physical size.
        Widget buildTestWidget(Timelanes timelanes) {
            return MaterialApp(
                home: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: 700, height: 500, child: timelanes),
                ),
            );
        }

        testWidgets('renders with no lanes without error', (WidgetTester tester) async {
            await tester.pumpWidget(buildTestWidget(
                Timelanes(
                    earliestDate: jan1,
                    latestDate: dec31,
                    dateLabelFormat: 'yyyy',
                ),
            ));
            expect(tester.takeException(), isNull);
        });

        testWidgets('shows earliest and latest date labels', (WidgetTester tester) async {
            await tester.pumpWidget(buildTestWidget(
                Timelanes(
                    earliestDate: jan1,
                    latestDate: dec31,
                    dateLabelFormat: 'yyyy',
                ),
            ));
            expect(find.text('2024'), findsNWidgets(2));
        });

        testWidgets('renders lane titles', (WidgetTester tester) async {
            await tester.pumpWidget(buildTestWidget(
                Timelanes(
                    earliestDate: jan1,
                    latestDate: dec31,
                    lanesAbove: const ['Top Lane'],
                    lanesBelow: const ['Bottom Lane'],
                    dateLabelFormat: 'yyyy',
                ),
            ));
            expect(find.text('Top Lane'), findsOneWidget);
            expect(find.text('Bottom Lane'), findsOneWidget);
        });

        testWidgets('shows Dividers when showSwimlanes is true', (WidgetTester tester) async {
            await tester.pumpWidget(buildTestWidget(
                Timelanes(
                    earliestDate: jan1,
                    latestDate: dec31,
                    lanesAbove: const ['Lane'],
                    dateLabelFormat: 'yyyy',
                    showSwimlanes: true,
                ),
            ));
            // Expect the swimlane dividers plus the one inside buildTimeline
            expect(find.byType(Divider), findsAtLeastNWidgets(2));
        });

        testWidgets('suppresses swimlane Dividers when showSwimlanes is false', (WidgetTester tester) async {
            await tester.pumpWidget(buildTestWidget(
                Timelanes(
                    earliestDate: jan1,
                    latestDate: dec31,
                    lanesAbove: const ['Lane'],
                    dateLabelFormat: 'yyyy',
                    showSwimlanes: false,
                ),
            ));
            // Only the Divider inside buildTimeline remains
            expect(find.byType(Divider), findsOneWidget);
        });

        testWidgets('renders event title text inside a lane', (WidgetTester tester) async {
            await tester.pumpWidget(buildTestWidget(
                Timelanes(
                    earliestDate: jan1,
                    latestDate: dec31,
                    lanesAbove: const ['Lane'],
                    dateLabelFormat: 'yyyy',
                    events: [
                        TimeEvent(
                            start: DateTime(2024, 6, 1),
                            laneIndex: 0,
                            title: 'My Event',
                        ),
                    ],
                ),
            ));
            expect(find.text('My Event'), findsOneWidget);
        });

        testWidgets('renders both lane title positions when laneTitlePosition is both', (WidgetTester tester) async {
            await tester.pumpWidget(buildTestWidget(
                Timelanes(
                    earliestDate: jan1,
                    latestDate: dec31,
                    lanesAbove: const ['Alpha'],
                    dateLabelFormat: 'yyyy',
                    laneTitlePosition: TimelaneTitlePosition.both,
                ),
            ));
            expect(find.text('Alpha'), findsNWidgets(2));
        });
    });
}
