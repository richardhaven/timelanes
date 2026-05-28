import 'package:flutter/services.dart';

// this allows m/d/yyyy, mm/d/yyyy, m/dd/yyyy, and mm/dd/yyyy

// note that DateFormat.yMd('en_US').tryParseLoose(newDate) can import this format

final _onlyDigitsAndSlashes = RegExp(r'^[0-9\/]*(\-\d{1,4})?$');
final _elements = RegExp(r'(\d\d?)(/(\d\d?)(/-?\d+)?)?');
final _tripleMonth = RegExp(r'^\d{3}$');
final _tripleDay = RegExp(r'\d\d?/\d{3}$');

class USADateFormatter extends TextInputFormatter {
  const USADateFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text;

    if (!_onlyDigitsAndSlashes.hasMatch(newText)) {
      return oldValue;
    }

    if (newText.length < oldValue.text.length) {
      return newValue;
    }

    if (newText.contains("//")) {
      // deletes leaving two adjacent slashes are okay (see above)
      return oldValue;
    }

    Iterable<RegExpMatch> matches = _elements.allMatches(newText);

    int? monthValue, dayValue, yearValue;
    if (matches.isNotEmpty) {
      RegExpMatch firstMatch = matches.elementAt(0);
      if (firstMatch.groupCount >= 1) {
        String? monthString = firstMatch.group(1);
        if (monthString != null) {
          monthValue = int.parse(monthString);
          if (monthValue > 12) {
            return oldValue;
          }
        }
      }
      if (firstMatch.groupCount >= 4) {
        String? yearString = firstMatch.group(4);
        if (yearString != null) {
          if (yearString.length > 5) {
            return oldValue;
          }
          yearValue = int.parse(yearString.substring(1));
        }
      }
      if (firstMatch.groupCount >= 3) {
        String? dayString = firstMatch.group(3);
        if (dayString != null) {
          dayValue = int.parse(dayString);
          if (dayValue > _daysPerMonth(monthValue!, yearValue)) {
            return oldValue;
          }
        }
      }
    }

    switch (newValue.selection.baseOffset) {
      case 3:
        if (_tripleMonth.hasMatch(newText)) {
          String nextText = newText.substring(0, 2) + '/' + newText.substring(2);
          TextSelection newSelection = const TextSelection.collapsed(offset: 4);
          TextEditingValue result = newValue.copyWith(text: nextText, selection: newSelection);
          return result;
        }

      case 5:
      case 6:
        if (_tripleDay.hasMatch(newText)) {
          String nextText = newText.penultimate + '/' + newText.last;
          int nextBaseOffset = newValue.selection.baseOffset + 1;
          TextSelection newSelection = TextSelection.collapsed(offset: nextBaseOffset);
          TextEditingValue result = newValue.copyWith(text: nextText, selection: newSelection);
          return result;
        }
    }

    return newValue;
  }

  int _daysPerMonth(int month, int? year) {
    if (month == 2) {
      if (year == null || ((year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0)))) {
        return 29;
      } else {
        return 28;
      }
    } else {
      const monthDays = [31, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      return monthDays[month];
    }
  }
}

extension on String {
  String get penultimate {
    if (this.length < 2) {
      return "";
    } else {
      return this.substring(0, this.length - 1);
    }
  }

  String get last {
    if (this.isEmpty) {
      return "";
    } else {
      return this.substring(this.length - 1);
    }
  }
}
