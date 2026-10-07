import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/features/events/data/models/event_model.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';

const _json = {
  'id': 'e1',
  'eventType': 'Wedding',
  'title': 'Asha & Ravi',
  'eventDate': '2026-12-14',
  'startTime': '18:30',
  'timeZone': 'Asia/Kolkata',
  'city': 'Chennai',
  'venueName': null,
  'venueAddress': null,
  'guestCountEstimate': 250,
  'totalBudget': {'amount': '400000.50', 'currency': 'INR'},
  'status': 'PLANNING',
  'version': 3,
  'createdAt': '2026-10-07T10:00:00.000Z',
  'updatedAt': '2026-10-07T10:00:00.000Z',
};

void main() {
  test('decodes an event with exact money', () {
    final event = EventModel.fromJson(_json);
    expect(event.eventDate, DateTime(2026, 12, 14));
    expect(event.totalBudget, Money.parse('400000.50', 'INR'));
    expect(event.status, EventStatus.planning);
    expect(event.version, 3);
    expect(event.venueName, isNull);
  });

  test('create body omits empty optional fields', () {
    final body = EventModel.createJson(
      EventInput(
        eventType: 'Birthday',
        title: 'Party',
        eventDate: DateTime(2026, 11, 1),
        city: 'Madurai',
        totalBudget: Money.parse('5000.00', 'INR'),
      ),
    );
    expect(body, {
      'eventType': 'Birthday',
      'title': 'Party',
      'eventDate': '2026-11-01',
      'city': 'Madurai',
      'totalBudget': {'amount': '5000.00', 'currency': 'INR'},
    });
  });

  test('update body sends only changes, null clears, plus version', () {
    final current = EventModel.fromJson(_json);
    final body = EventModel.updateJson(
      current,
      EventInput(
        eventType: 'Wedding',
        title: 'Asha & Ravi Wedding',
        eventDate: DateTime(2026, 12, 14),
        city: 'Chennai',
        startTime: null,
        guestCountEstimate: 250,
        totalBudget: Money.parse('400000.50', 'INR'),
      ),
    );
    expect(body, {
      'title': 'Asha & Ravi Wedding',
      'startTime': null,
      'version': 3,
    });
  });
}
