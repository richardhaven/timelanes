import 'package:flutter/material.dart';
import 'package:timelanes/timelanes.dart';

Widget widget = Column(children: [
  Expanded(
    child: Timelanes(
      earliestDate: DateTime(1330),
      latestDate: DateTime(1850),
      lanesAbove: ["lane 1", "lane 2"],
      lanesBelow: ["lane 3", "lane 4"],
      events: [
        TimeEvent(start: DateTime(300), end: DateTime(1230), title: "not shown: out of bounds", laneIndex: 0),
        TimeEvent(
            start: DateTime(1500),
            title: "show a box",
            laneIndex: 3,
            builder: (TimeEvent event, double maximumHeight, double pixelsPerMinute, EventAlignment eventAlignment) {
              return Container(
                height: maximumHeight,
                width: maximumHeight,
                color: Colors.orange,
              );
            }),
        TimeEvent(
          start: DateTime(1702),
          end: DateTime(1860),
          title: "show a bar",
          laneIndex: 3,
          builder: (TimeEvent event, double maximumHeight, double pixelsPerMinute, EventAlignment eventAlignment) {
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
        ),
      ],
    ),
  )
]);
