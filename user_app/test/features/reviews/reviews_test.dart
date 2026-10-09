import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/features/reviews/data/reviews_repository_impl.dart';
import 'package:user_app/features/reviews/domain/review.dart';
import 'package:user_app/features/reviews/presentation/controllers/review_form_controller.dart';
import 'package:user_app/features/reviews/presentation/widgets/listing_reviews_section.dart';

import '../../helpers/fake_reviews.dart';

void main() {
  tearDown(Get.reset);

  group('JSON', () {
    test('a review parses its moderation state', () {
      final r = ReviewsRepositoryImpl.reviewFromJson({
        'id': 'rv1',
        'bookingId': 'b1',
        'listing': {'id': 'l1', 'title': 'Lotus Hall'},
        'rating': 4,
        'comment': 'Great',
        'commentStatus': 'PENDING_MODERATION',
        'createdAt': '2026-11-08T10:00:00.000Z',
      });
      expect(r.commentStatus, CommentStatus.pendingModeration);
      expect(r.listingTitle, 'Lotus Hall');
      expect(
        r.commentStatus.authorNote,
        'Your comment is waiting for approval.',
      );
      expect(CommentStatus.fromApi('NONE').authorNote, isNull);
    });

    test('the summary keeps 5 stars first', () {
      final s = ReviewsRepositoryImpl.summaryFromJson({
        'average': '4.5',
        'count': 2,
        'stars': [
          {'stars': 5, 'count': 1},
          {'stars': 4, 'count': 1},
          {'stars': 3, 'count': 0},
          {'stars': 2, 'count': 0},
          {'stars': 1, 'count': 0},
        ],
      });
      expect(s.average, '4.5');
      expect(s.stars.first, (stars: 5, count: 1));
    });
  });

  group('form', () {
    test('needs stars; a retry of the same review reuses the key', () async {
      final repo = FakeReviewsRepository();
      final c = ReviewFormController(repo, 'e1', 'b1');
      expect(await c.submit(), isNull);
      expect(c.ratingError.value, 'Choose 1 to 5 stars.');
      expect(repo.calls, isEmpty);

      c.setRating(5);
      c.comment.text = '  ';
      repo.failNext = const NetworkFailure();
      expect(await c.submit(), isNull);
      expect(c.formError.value, isNotNull);
      final review = await c.submit();
      expect(review!.comment, isNull);
      expect(repo.calls, everyElement('create:b1:5:null'));
      expect(repo.idempotencyKeys.toSet(), hasLength(1));
    });

    test('a changed review gets a new key; conflicts are explained', () async {
      final repo = FakeReviewsRepository();
      final c = ReviewFormController(repo, 'e1', 'b1')..setRating(3);
      repo.failNext = const NetworkFailure();
      await c.submit();
      c.setRating(4);
      repo.failNext = const ConflictFailure(
        message: 'You have already reviewed this booking.',
      );
      await c.submit();
      expect(repo.idempotencyKeys.toSet(), hasLength(2));
      expect(c.formError.value, 'You have already reviewed this booking.');
    });
  });

  group('listing section', () {
    Future<FakeReviewsRepository> pump(
      WidgetTester tester, {
      List<int> ratings = const [],
      int written = 0,
      Failure? fail,
    }) async {
      final repo =
          Get.put<ReviewsRepository>(FakeReviewsRepository())
              as FakeReviewsRepository;
      repo.ratings['l1'] = ratings;
      repo.published['l1'] = [
        for (var i = 1; i <= written; i++) testPublicReview(i),
      ];
      repo.pageSize = 2;
      repo.failNext = fail;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListingReviewsSection(listingId: 'l1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('says when there are no ratings', (tester) async {
      await pump(tester);
      expect(find.textContaining('No ratings yet'), findsOneWidget);
    });

    testWidgets('shows the average, breakdown and approved comments', (
      tester,
    ) async {
      final repo = await pump(tester, ratings: [5, 4, 4], written: 3);
      expect(find.text('4.3'), findsOneWidget);
      expect(find.text('3 ratings'), findsOneWidget);
      expect(find.bySemanticsLabel('4 stars: 2'), findsOneWidget);
      expect(find.text('Comment number 1'), findsOneWidget);
      expect(find.text('Guest 1.'), findsOneWidget);
      expect(find.text('Comment number 3'), findsNothing);
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Comment number 3'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
      expect(repo.calls, contains('reviews:l1:2'));
    });

    testWidgets('ratings without approved comments say so', (tester) async {
      await pump(tester, ratings: [3]);
      expect(find.text('No written reviews yet.'), findsOneWidget);
    });

    testWidgets('a failure can be retried', (tester) async {
      final repo = await pump(
        tester,
        ratings: [5],
        fail: const NetworkFailure(),
      );
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('1 rating'), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('summary')), hasLength(2));
    });

    testWidgets('fits at 200 % text on a small phone', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, ratings: [5, 4, 1], written: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
