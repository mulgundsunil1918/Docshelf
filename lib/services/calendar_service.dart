import 'package:add_2_calendar/add_2_calendar.dart';

import '../models/document.dart';

/// Hands DocShelf expiry reminders off to the user's system calendar app.
///
/// Why the calendar instead of in-app notifications?
/// - Works on every phone, including aggressive battery savers (Xiaomi /
///   OnePlus / Realme / etc.) that kill background scheduled notifications.
/// - Syncs to the user's other devices automatically (Google Calendar,
///   Samsung Calendar, etc.).
/// - Survives app uninstalls + phone reboots.
/// - Needs zero runtime permissions — Android opens the native "create
///   event" UI and the user confirms with one tap.
class CalendarService {
  static final CalendarService instance = CalendarService._();
  CalendarService._();

  /// Opens the system calendar's "create event" UI, pre-filled with the
  /// document's expiry details. Returns `true` if the dialog was shown
  /// successfully (the user may still cancel inside the calendar app —
  /// we have no way to know).
  Future<bool> addExpiryReminder(Document doc) async {
    if (doc.expiryDate == null) return false;

    final fireAt =
        doc.expiryDate!.subtract(Duration(days: doc.reminderDays));
    final eventStart = DateTime(fireAt.year, fireAt.month, fireAt.day, 9);
    final eventEnd = eventStart.add(const Duration(minutes: 30));

    final daysCopy = doc.reminderDays == 0
        ? 'today'
        : '${doc.reminderDays} day${doc.reminderDays == 1 ? '' : 's'} before';

    final event = Event(
      title: '📅 ${doc.name} expires',
      description:
          'Reminder $daysCopy expiry.\n\n${doc.name} expires on '
          '${doc.formattedExpiryDate}.\n\nManaged by DocShelf.',
      location: 'DocShelf',
      startDate: eventStart,
      endDate: eventEnd,
      iosParams: const IOSParams(
        reminder: Duration(hours: 9),
      ),
      androidParams: const AndroidParams(
        emailInvites: [],
      ),
    );

    return Add2Calendar.addEvent2Cal(event);
  }
}
