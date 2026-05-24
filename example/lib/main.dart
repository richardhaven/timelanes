import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:timelanes/timelanes.dart';
import 'package:url_launcher/url_launcher.dart';

import "usa_date_formatter.dart";

const debounceDuration = Duration(milliseconds: 500);

final _isWellFormedDate = RegExp(r"\d\d?/\d\d?/\-?\d+");

const TextStyle _hintStyle = TextStyle(fontStyle: FontStyle.italic, fontSize: 11);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timelanes Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(floatingLabelBehavior: FloatingLabelBehavior.always),
      ),
      home: MyHomePage(title: 'Timelanes Demo'),
    );
  }
}

class TimeEventBuilder {
  DateTime? start;
  DateTime? end;
  int? laneIndex;
  int? priority;
  double? offsetLeft;
  String? title;
  EventWidgetType? widgetType;
  TimeEventWidgetBuilder? widgetBuilder;

  TimeEventBuilder({this.start, this.end, this.laneIndex, this.priority, this.offsetLeft, this.title, this.widgetBuilder});

  bool isValid() {
    return (start != null) && (laneIndex != null);
  }

  TimeEvent timeEvent() {
    return TimeEvent(
      start: this.start!,
      end: this.end,
      laneIndex: this.laneIndex!,
      priority: this.priority ?? 1,
      builder: this.builder,
      title: this.title ?? "",
      offsetLeft: this.offsetLeft ?? 0,
    );
  }

  Widget builder(TimeEvent event, double maximumHeight, double pixelsPerMinute, EventAlignment eventAlignment) {
    if (this.widgetBuilder != null) {
      return this.widgetBuilder!(event, maximumHeight, pixelsPerMinute, eventAlignment);
    }
    switch (this.widgetType) {
      case EventWidgetType.image:
        return Image.network(
          'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl-2.jpg',
          height: maximumHeight,
        );
      case EventWidgetType.box:
        return Container(
          height: maximumHeight,
          width: maximumHeight,
          color: Colors.orange,
        );
      default:
        return Text(event.title, style: event.titleStyle);
    }
  }
}

List<TimeEvent> buildTimeEvents(List<TimeEventBuilder> events) {
  List<TimeEvent> result = List<TimeEvent>.empty(growable: true);
  for (var event in events) {
    if (event.isValid()) {
      result.add(event.timeEvent());
    }
  }
  return result;
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.title});

  final String title;

  DateTime earliestDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime latestDate = DateTime.now().add(const Duration(days: 30));
  List<String> lanesAbove = List<String>.empty();
  List<String> lanesBelow = List<String>.empty();

  double? laneHeight = 0;
  TextSelection laneHeightCursorSelection = const TextSelection(baseOffset: 0, extentOffset: 0);
  bool showSwimlanes = true;
  Axis laneTitleOrientation = Axis.horizontal;
  String dateLabelFormat = "d MMMM yyyy";
  TimelaneTitlePosition laneTitlePosition = TimelaneTitlePosition.left;

  List<TimeEventBuilder> events = [TimeEventBuilder(), TimeEventBuilder(), TimeEventBuilder()];

  EventWidgetType getWidgetTypeAt(int index) {
    if (index < this.events.length) {
      return this.events[index].widgetType ?? EventWidgetType.none;
    } else {
      return EventWidgetType.none;
    }
  }

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Timer? _debouncelanesAbove;
  Timer? _debouncelanesBelow;
  Timer? _debounceElement1;
  Timer? _debounceElement2;
  Timer? _debounceElement3;
  final TextEditingController _earliestDateController = TextEditingController();
  final TextEditingController _latestDateController = TextEditingController();
  final TextEditingController _dateLabelFormatController = TextEditingController();
  final TextEditingController _lanesAboveController = TextEditingController();
  final TextEditingController _lanesBelowController = TextEditingController();

  @override
  void dispose() {
    _debouncelanesAbove?.cancel();
    _debouncelanesBelow?.cancel();
    _debounceElement1?.cancel();
    _debounceElement2?.cancel();
    _debounceElement3?.cancel();

    _earliestDateController.dispose();
    _latestDateController.dispose();
    _dateLabelFormatController.dispose();
    _lanesAboveController.dispose();
    _lanesBelowController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    this._earliestDateController.text = DateFormat("M/d/y").format(this.widget.earliestDate);
    this._latestDateController.text = DateFormat("M/d/y").format(this.widget.latestDate);
    this._dateLabelFormatController.text = this.widget.dateLabelFormat;
    this._lanesAboveController.text = this.widget.lanesAbove.join(",").replaceAll("\n", "\\n");
    this._lanesBelowController.text = this.widget.lanesBelow.join(",").replaceAll("\n", "\\n");
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Timelanes(
              earliestDate: this.widget.earliestDate,
              latestDate: this.widget.latestDate,
              lanesAbove: this.widget.lanesAbove,
              lanesBelow: this.widget.lanesBelow,
              showSwimlanes: this.widget.showSwimlanes,
              laneTitleOrientation: this.widget.laneTitleOrientation,
              laneTitlePosition: this.widget.laneTitlePosition,
              events: buildTimeEvents(this.widget.events),
              dateLabelFormat: this.widget.dateLabelFormat,
            ),
          ),
          const SizedBox(height: 10),
          Table(children: <TableRow>[
            TableRow(children: <Widget>[
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Lanes above',
                  hintText: 'comma-separated, above-the-timeline titles',
                  hintStyle: _hintStyle,
                  border: OutlineInputBorder(),
                ),
                controller: _lanesAboveController,
                expands: false,
                keyboardType: TextInputType.multiline,
                onChanged: (String value) {
                  _debouncelanesAbove?.cancel();
                  _debouncelanesAbove = Timer(debounceDuration, () {
                    setState(() {
                      this.widget.lanesAbove = value.trim().split(",");
                    });
                  });
                },
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Lanes below',
                  hintText: 'comma-separated, below-the-timeline titles',
                  hintStyle: _hintStyle,
                  border: OutlineInputBorder(),
                ),
                controller: _lanesBelowController,
                onChanged: (String value) {
                  _debouncelanesBelow?.cancel();
                  _debouncelanesBelow = Timer(debounceDuration, () {
                    setState(() {
                      this.widget.lanesBelow = value.trim().split(",");
                    });
                  });
                },
              ),
              Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text("Show Swimlanes:"),
                        Checkbox(
                            value: this.widget.showSwimlanes,
                            onChanged: (bool? newValue) {
                              setState(() {
                                this.widget.showSwimlanes = (newValue == true);
                              });
                            }),
                      ]),
                      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                        const Text("Lane Title Orientation: "),
                        const Text("horizontal"),
                        Radio<Axis>(
                          value: Axis.horizontal,
                          onChanged: (Axis? newValue) {
                            setState(() {
                              this.widget.laneTitleOrientation = newValue ?? Axis.horizontal;
                            });
                          },
                          groupValue: this.widget.laneTitleOrientation,
                        ),
                        const Text("vertical"),
                        Radio<Axis>(
                          value: Axis.vertical,
                          onChanged: (Axis? newValue) {
                            setState(() {
                              this.widget.laneTitleOrientation = newValue ?? Axis.horizontal;
                            });
                          },
                          groupValue: this.widget.laneTitleOrientation,
                        )
                      ]),
                    ],
                  )),
            ]),
            TableRow(children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Earliest Date',
                  border: OutlineInputBorder(),
                ),
                controller: this._earliestDateController,
                keyboardType: TextInputType.datetime,
                inputFormatters: const [USADateFormatter()],
                onChanged: (String newDate) {
                  if (_isWellFormedDate.hasMatch(newDate)) {
                    DateTime? parsedDate = DateFormat.yMd('en_US').tryParseLoose(newDate);
                    if (parsedDate != null && parsedDate.isBefore(this.widget.latestDate)) {
                      setState(() {
                        this.widget.earliestDate = parsedDate;
                      });
                    }
                  }
                },
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Latest Date',
                  border: OutlineInputBorder(),
                ),
                controller: this._latestDateController,
                keyboardType: TextInputType.datetime,
                inputFormatters: const [USADateFormatter()],
                onChanged: (String newDate) {
                  if (_isWellFormedDate.hasMatch(newDate)) {
                    DateTime? parsedDate = DateFormat.yMd('en_US').tryParseLoose(newDate);
                    if (parsedDate != null && this.widget.earliestDate.isBefore(parsedDate)) {
                      setState(() {
                        this.widget.latestDate = parsedDate;
                      });
                    }
                  }
                },
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'date label format',
                  border: OutlineInputBorder(),
                ),
                controller: this._dateLabelFormatController,
                onChanged: (String newFormat) => setState(() => this.widget.dateLabelFormat = newFormat),
              ),
            ]),
            TableRow(children: [
              TimeEventSpecification(
                label: "Element #1",
                initialDate: DateTime.now().add(const Duration(days: 2)),
                onDateChange: (DateTime? newDate) {
                  this.widget.events[0].start = newDate;
                  _debounceElement1?.cancel();
                  _debounceElement1 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onTitleChange: (String newTitle) {
                  this.widget.events[0].title = newTitle;
                  _debounceElement1?.cancel();
                  _debounceElement1 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onLaneIndexChange: (int newLaneIndex) {
                  this.widget.events[0].laneIndex = newLaneIndex;
                  _debounceElement1?.cancel();
                  _debounceElement1 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onPriorityChange: (int newPriority) {
                  this.widget.events[0].priority = newPriority;
                  _debounceElement1?.cancel();
                  _debounceElement1 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onLeftOffsetChange: (double newLeftOffset) {
                  this.widget.events[0].offsetLeft = newLeftOffset;
                  _debounceElement1?.cancel();
                  _debounceElement1 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                widgetType: this.widget.getWidgetTypeAt(0),
                onWidgetTypeChange: (String newWidgetType) {
                  setState(() => this.widget.events[0].widgetType = newWidgetType.toEventWidgetType);
                },
              ),
              TimeEventSpecification(
                label: "Element #2",
                initialDate: DateTime.now().add(const Duration(days: 2)),
                onDateChange: (DateTime? newDate) {
                  this.widget.events[1].start = newDate;
                  _debounceElement2?.cancel();
                  _debounceElement2 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onTitleChange: (String newTitle) {
                  this.widget.events[1].title = newTitle;
                  _debounceElement2?.cancel();
                  _debounceElement2 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onLaneIndexChange: (int newLaneIndex) {
                  this.widget.events[1].laneIndex = newLaneIndex;
                  _debounceElement2?.cancel();
                  _debounceElement2 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onPriorityChange: (int newPriority) {
                  this.widget.events[1].priority = newPriority;
                  _debounceElement2?.cancel();
                  _debounceElement2 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onLeftOffsetChange: (double newLeftOffset) {
                  this.widget.events[1].offsetLeft = newLeftOffset;
                  _debounceElement2?.cancel();
                  _debounceElement2 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                widgetType: this.widget.getWidgetTypeAt(1),
                onWidgetTypeChange: (String newWidgetType) {
                  setState(() => this.widget.events[1].widgetType = newWidgetType.toEventWidgetType);
                },
              ),
              TimeEventSpecification(
                label: "Element #3",
                initialDate: DateTime.now().add(const Duration(days: 2)),
                onDateChange: (DateTime? newDate) {
                  this.widget.events[2].start = newDate;
                  _debounceElement3?.cancel();
                  _debounceElement3 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onTitleChange: (String newTitle) {
                  this.widget.events[2].title = newTitle;
                  _debounceElement3?.cancel();
                  _debounceElement3 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onLaneIndexChange: (int newLaneIndex) {
                  this.widget.events[2].laneIndex = newLaneIndex;
                  _debounceElement3?.cancel();
                  _debounceElement3 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onPriorityChange: (int newPriority) {
                  this.widget.events[2].priority = newPriority;
                  _debounceElement3?.cancel();
                  _debounceElement3 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                onLeftOffsetChange: (double newLeftOffset) {
                  this.widget.events[2].offsetLeft = newLeftOffset;
                  _debounceElement3?.cancel();
                  _debounceElement3 = Timer(debounceDuration, () {
                    setState(() {});
                  });
                },
                widgetType: this.widget.getWidgetTypeAt(2),
                onWidgetTypeChange: (String newWidgetType) {
                  setState(() => this.widget.events[2].widgetType = newWidgetType.toEventWidgetType);
                },
              ),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(onPressed: () => setState(() => loadWorldHistory()), child: const Text("Sample World History")),
              const SizedBox(width: 30),
              ElevatedButton(onPressed: () => setState(() => loadNASATakeoff()), child: const Text("Sample NASA Takeoff")),
              const SizedBox(width: 30),
              ElevatedButton(
                  onPressed: () => setState(() {
                        this.widget.lanesAbove = [];
                        this.widget.lanesBelow = [];
                        this.widget.earliestDate = DateTime.now().subtract(const Duration(days: 30));
                        this.widget.latestDate = DateTime.now().add(const Duration(days: 30));
                        this.widget.dateLabelFormat = "d MMM yyyy";
                        this.widget.laneTitlePosition = TimelaneTitlePosition.left;

                        this.widget.events = [TimeEventBuilder(), TimeEventBuilder(), TimeEventBuilder()];
                      }),
                  child: const Text("Clear Elements")),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  loadWorldHistory() {
    this.widget.earliestDate = DateTime(200);
    this.widget.latestDate = DateTime(1500);
    this.widget.lanesAbove = ["China", "India", "Africa", "Europe", "Americas"];
    this.widget.lanesBelow = [];
    this.widget.dateLabelFormat = "yyyy";
    this.widget.laneTitlePosition = TimelaneTitlePosition.both;
    this.widget.events = [
      TimeEventBuilder(
        title: "Ghana Empire",
        start: DateTime(300),
        end: DateTime(1230),
        laneIndex: 2,
        widgetBuilder: (TimeEvent event, double maximumHeight, double pixelsPerMinute, EventAlignment eventAlignment) {
          Widget result = createTimePeriod(
            color: Colors.blueGrey,
            rowHeight: maximumHeight,
            start: event.start,
            end: event.end!,
            pixelsPerMinute: pixelsPerMinute,
            title: event.title,
            eventAlignment: eventAlignment,
          );
          return InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () => launchAddress(r'https://en.wikipedia.org/wiki/Ghana_Empire'),
            child: result,
          );
        },
      ),
      TimeEventBuilder(
        title: "Sui dynasty",
        start: DateTime(581),
        end: DateTime(618),
        laneIndex: 0,
        widgetBuilder: (TimeEvent event, double maximumHeight, double pixelsPerMinute, EventAlignment eventAlignment) {
          Widget result = createTimePeriod(
            color: Colors.deepPurpleAccent,
            rowHeight: maximumHeight,
            start: event.start,
            end: event.end!,
            pixelsPerMinute: pixelsPerMinute,
            title: event.title,
            eventAlignment: eventAlignment,
          );
          return InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () => launchAddress(r'https://en.wikipedia.org/wiki/Sui_Dynasty'),
            child: result,
          );
        },
      ),
      TimeEventBuilder(
        title: "Toltec",
        start: DateTime(950),
        end: DateTime(1150),
        laneIndex: 4,
        widgetBuilder: (TimeEvent event, double maximumHeight, double pixelsPerMinute, EventAlignment eventAlignment) {
          Widget result = createTimePeriod(
            color: Colors.yellowAccent,
            rowHeight: maximumHeight,
            start: event.start,
            end: event.end!,
            pixelsPerMinute: pixelsPerMinute,
            title: event.title,
            eventAlignment: eventAlignment,
          );
          return InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () => launchAddress(r'https://en.wikipedia.org/wiki/Toltecs'),
            child: result,
          );
        },
      ),
      TimeEventBuilder(
        title: "Chola Empire",
        start: DateTime(848),
        end: DateTime(1279),
        laneIndex: 1,
        widgetBuilder: (TimeEvent event, double maximumHeight, double pixelsPerMinute, EventAlignment eventAlignment) {
          Widget result = createTimePeriod(
            color: Colors.indigo,
            rowHeight: maximumHeight,
            start: event.start,
            end: event.end!,
            pixelsPerMinute: pixelsPerMinute,
            title: event.title,
            eventAlignment: eventAlignment,
          );
          return InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () => launchAddress(r'https://en.wikipedia.org/wiki/Chola_Empire'),
            child: result,
          );
        },
      ),
      TimeEventBuilder(
        title: "Holy Roman Empire",
        start: DateTime(800),
        end: DateTime(1806),
        laneIndex: 3,
        widgetBuilder: (TimeEvent event, double maximumHeight, double pixelsPerMinute, EventAlignment eventAlignment) {
          Widget result = createTimePeriod(
              color: Colors.black,
              rowHeight: maximumHeight,
              start: event.start,
              end: event.end!,
              pixelsPerMinute: pixelsPerMinute,
              title: event.title,
              titleStyle: const TextStyle(color: Colors.white),
              eventAlignment: eventAlignment);
          return Tooltip(
              message: "800 - 1806",
              child: InkWell(
                mouseCursor: WidgetStateMouseCursor.clickable,
                onTap: () => launchAddress(r'https://en.wikipedia.org/wiki/Holy_Roman_Empire'),
                child: result,
              ));
        },
      ),
    ];
  }

  loadNASATakeoff() {
    this.widget.earliestDate = DateTime(0000, 1, 1, 0, 0, 0);
    this.widget.latestDate = DateTime(0000, 1, 1, 40, 0, 0);
    this.widget.lanesAbove = ["rocket"];
    this.widget.lanesBelow = ["ground\ncontrol", "media"];
    this.widget.laneTitlePosition = TimelaneTitlePosition.left;
    this.widget.dateLabelFormat = "HH:MM";
    this.widget.events = [
      TimeEventBuilder(
        title: "The ICPS is powered down",
        start: DateTime(0000, 1, 1, 9),
        laneIndex: 0,
      ),
      TimeEventBuilder(
        title: "All non-essential\npersonnel\nleave Launch\nComplex",
        start: DateTime(0000, 1, 1, 27),
        laneIndex: 1,
      ),
      TimeEventBuilder(
        title: "Engine bleed kick start",
        start: DateTime(0000, 1, 1, 32, 20),
        laneIndex: 0,
      ),
      TimeEventBuilder(
        title: "Orion set to internal power",
        start: DateTime(0000, 1, 1, 39, 54),
        laneIndex: 1,
      ),
      TimeEventBuilder(
        title: "Launch team\nconducts a weather\nand tanking briefing ",
        start: DateTime(0000, 1, 1, 31, 20),
        laneIndex: 1,
      ),
    ];
  }
}

extension on String {
  EventWidgetType get toEventWidgetType {
    switch (this) {
      case "image":
        return EventWidgetType.image;
      case "box":
        return EventWidgetType.box;
      default:
        return EventWidgetType.none;
    }
  }
}

enum EventWidgetType { none, image, box }

class TimeEventSpecification extends StatefulWidget {
  late final DateTime initialDate;
  late final String label;
  EventWidgetType widgetType;

  late final Function(DateTime? newDateTime) onDateChange;
  late final Function(String newTitle) onTitleChange;
  late final Function(int newLaneIndex) onLaneIndexChange;
  late final Function(int newPriority) onPriorityChange;
  late final Function(double newLeftOffset)? onLeftOffsetChange;
  late final Function(String newWidgetType)? onWidgetTypeChange;

  TimeEventSpecification({
    super.key,
    required this.label,
    required this.initialDate,
    required this.onDateChange,
    required this.onTitleChange,
    required this.onLaneIndexChange,
    required this.onPriorityChange,
    this.onLeftOffsetChange,
    required this.widgetType,
    required this.onWidgetTypeChange,
  });

  @override
  State<TimeEventSpecification> createState() => _TimeEventSpecificationState();
}

class _TimeEventSpecificationState extends State<TimeEventSpecification> {
  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(this.widget.label),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            onChanged: (String newTitle) {
              this.widget.onTitleChange(newTitle);
            },
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Date',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.datetime,
            inputFormatters: const [USADateFormatter()],
            onChanged: (String newDate) {
              DateTime? parsedDate = DateFormat.yMd('en_US').tryParseLoose(newDate);
              this.widget.onDateChange(parsedDate);
            },
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'lanes index',
              hintText: 'zero-based lane',
              hintStyle: _hintStyle,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (String newLaneIndex) {
              this.widget.onLaneIndexChange(int.parse(newLaneIndex));
            },
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'priority',
              hintText: '1 is highest, default to 100',
              hintStyle: _hintStyle,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (String newPriority) {
              int priorityValue = int.tryParse(newPriority) ?? 100;
              this.widget.onPriorityChange(priorityValue);
            },
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'left offset',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[\-0-9]+.?[0-9]*'))],
            onChanged: (String newOffset) {
              double offsetValue = double.tryParse(newOffset) ?? 0;
              this.widget.onLeftOffsetChange?.call(offsetValue);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
            child: Column(
              children: [
                Wrap(children: [
                  Radio<String>(
                    value: "none",
                    onChanged: (String? newValue) {
                      this.widget.onWidgetTypeChange?.call("none");
                    },
                    groupValue: this.widget.widgetType.name,
                  ),
                  const Text("none (title)"),
                  Radio<String>(
                    value: "image",
                    onChanged: (String? newValue) {
                      this.widget.onWidgetTypeChange?.call("image");
                    },
                    groupValue: this.widget.widgetType.name,
                  ),
                  const Text("image"),
                  Radio<String>(
                    value: "box",
                    onChanged: (String? newValue) {
                      this.widget.onWidgetTypeChange?.call("box");
                    },
                    groupValue: this.widget.widgetType.name,
                  ),
                  const Text("box"),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> launchAddress(String address) async {
  final Uri url = Uri.parse(address);

  if (!await launchUrl(url)) {
    throw Exception('Could not launch $url');
  }
}
