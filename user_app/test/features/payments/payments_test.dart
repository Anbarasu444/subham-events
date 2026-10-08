import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/features/budget/data/budget_model.dart';
import 'package:user_app/features/budget/domain/budget.dart';
import 'package:user_app/features/budget/presentation/widgets/expense_sheet.dart';
import 'package:user_app/features/event_vendors/data/payments_repository_impl.dart';
import 'package:user_app/features/event_vendors/domain/payment.dart';
import 'package:user_app/features/event_vendors/presentation/controllers/payment_form_controller.dart';
import 'package:user_app/features/event_vendors/presentation/views/payments_view.dart';

import '../../helpers/fake_budget_repository.dart';
import '../../helpers/fake_payments.dart';
import '../../helpers/viewport.dart';

Money _inr(String amount) => Money.parse(amount, 'INR');
Map<String, String> _json(String amount) => {
  'amount': amount,
  'currency': 'INR',
};

void main() {
  tearDown(Get.reset);

  group('payments JSON', () {
    test('reads totals and overpayment', () {
      final list = PaymentsRepositoryImpl.listFromJson({
        'bookingId': 'b1',
        'bookingStatus': 'CONFIRMED',
        'agreedAmount': _json('100.00'),
        'paid': _json('100.01'),
        'balance': null,
        'overpaidBy': _json('0.01'),
        'payments': [
          {
            'id': 'p1',
            'amount': _json('100.01'),
            'paidOn': '2026-10-01',
            'method': 'BANK_TRANSFER',
            'kind': 'FINAL',
            'note': null,
            'version': 1,
            'createdAt': '2026-10-01T10:00:00.000Z',
          },
        ],
      });
      expect(list.overpaidBy, _inr('0.01'));
      expect(list.balance, isNull);
      expect(list.payments.single.method, PaymentMethod.bankTransfer);
      expect(list.payments.single.kind, PaymentKind.finalPayment);
    });

    test('writes API names and exact amounts', () {
      expect(
        PaymentsRepositoryImpl.toJson(
          PaymentInput(
            amount: _inr('50000.50'),
            paidOn: DateTime(2026, 10, 1),
            method: PaymentMethod.bankTransfer,
            kind: PaymentKind.finalPayment,
          ),
        ),
        {
          'amount': _json('50000.50'),
          'paidOn': '2026-10-01',
          'method': 'BANK_TRANSFER',
          'kind': 'FINAL',
          'note': null,
        },
      );
    });

    test('budget reads paid to cancelled vendors and what is still owed', () {
      final budget = BudgetModel.fromJson({
        'eventId': 'e1',
        'isEditable': true,
        'totalBudget': _json('500000.00'),
        'planned': _json('0.00'),
        'unplanned': _json('500000.00'),
        'isOverPlanned': false,
        'committed': _json('180000.00'),
        'paid': _json('70000.00'),
        'paidToCancelled': _json('20000.00'),
        'outstanding': _json('130000.00'),
        'expenses': _json('0.00'),
        'spent': _json('70000.00'),
        'remaining': _json('320000.00'),
        'categories': <Object>[],
      });
      expect(budget.paidToCancelled, _inr('20000.00'));
      expect(budget.outstanding, _inr('130000.00'));
    });
  });

  test('a retried save reuses the idempotency key; zero is refused', () async {
    final repo = FakePaymentsRepository(agreed: _inr('1000.00'));
    final c = PaymentFormController(
      repo,
      'e1',
      'b1',
      today: DateTime(2026, 10, 8),
    )..onInit();
    c.amount.text = '0';
    expect(await c.submit(), isNull);
    expect(c.amountError.value, 'The amount must be more than ₹0.');
    c.amount.text = '500';
    repo.failNext = const NetworkFailure();
    expect(await c.submit(), isNull);
    expect(await c.submit(), isNotNull);
    expect(repo.idempotencyKeys[0], repo.idempotencyKeys[1]);
    c.onClose();
  });

  group('Payments screen', () {
    Future<FakePaymentsRepository> pump(WidgetTester tester) async {
      Get.testMode = true;
      usePhoneSize(tester);
      final repo =
          Get.put<PaymentsRepository>(
                FakePaymentsRepository(agreed: _inr('180000.00')),
              )
              as FakePaymentsRepository;
      await tester.pumpWidget(
        const GetMaterialApp(
          home: PaymentsView(
            eventId: 'e1',
            bookingId: 'b1',
            vendorName: 'Lotus Grand Mahal',
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('adds, edits and deletes payments with exact totals', (
      tester,
    ) async {
      final repo = await pump(tester);
      expect(find.text('Paid ₹0 of ₹1,80,000'), findsOneWidget);
      expect(find.text('Balance due ₹1,80,000'), findsOneWidget);
      expect(
        find.textContaining('no money is sent through the app'),
        findsOneWidget,
      );

      await tester.tap(find.text('Add payment'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount paid'),
        '50,000.50',
      );
      await tester.tap(find.text('Add payment').last);
      await tester.pumpAndSettle();
      expect(repo.calls, contains('add:50000.50'));
      expect(find.text('Paid ₹50,000.50 of ₹1,80,000'), findsOneWidget);
      expect(find.text('Balance due ₹1,29,999.50'), findsOneWidget);
      expect(find.textContaining('Advance · UPI'), findsOneWidget);

      await tester.tap(find.text('₹50,000.50'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount paid'),
        '180001',
      );
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();
      expect(find.text('Overpaid by ₹1'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete ₹1,80,001 payment'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repo.payments, isEmpty);
      expect(find.text('Payment deleted.'), findsOneWidget);
      expect(find.textContaining('No payments yet'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      Get.testMode = true;
      usePhoneSize(tester);
      final repo =
          Get.put<PaymentsRepository>(
                FakePaymentsRepository(agreed: _inr('1000.00'))
                  ..failNext = const NetworkFailure(),
              )
              as FakePaymentsRepository;
      await tester.pumpWidget(
        const GetMaterialApp(
          home: PaymentsView(eventId: 'e1', bookingId: 'b1', vendorName: 'X'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Paid ₹0 of ₹1,000'), findsOneWidget);
      expect(repo.calls.where((c) => c == 'list'), hasLength(2));
    });

    testWidgets('fits at 200 % text on a small phone', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = await pump(tester);
      repo.payments.add(
        Payment(
          id: 'p1',
          amount: _inr('9999999999.99'),
          paidOn: DateTime(2026, 10, 1),
          method: PaymentMethod.bankTransfer,
          kind: PaymentKind.instalment,
          note: 'Paid by uncle at the temple office',
          version: 1,
        ),
      );
      await tester.tap(find.text('Add payment'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the expense sheet warns when the category has a booked vendor', (
    tester,
  ) async {
    Get.testMode = true;
    usePhoneSize(tester);
    Get.put<BudgetRepository>(FakeBudgetRepository());
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showExpenseSheet(
              context,
              eventId: 'e1',
              categories: const [
                (id: 'cat-venue', name: 'Venue'),
                (id: 'cat-catering', name: 'Catering'),
              ],
              bookedCategoryIds: const {'cat-venue'},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paying a booked vendor?'), findsNothing);
    await tester.tap(find.text('No category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Venue').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Paying a booked vendor?'), findsOneWidget);
    await tester.tap(find.text('Venue').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catering').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Paying a booked vendor?'), findsNothing);
  });
}
