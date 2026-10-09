import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/platform/external_actions.dart';
import 'package:user_app/core/platform/photo_picker.dart';
import 'package:user_app/features/media/domain/media_repository.dart';
import 'package:user_app/features/profile/domain/profile_repository.dart';
import 'package:user_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:user_app/features/profile/presentation/views/help_view.dart';
import 'package:user_app/features/profile/presentation/views/my_reviews_view.dart';
import 'package:user_app/features/profile/presentation/views/profile_view.dart';
import 'package:user_app/features/reviews/domain/review.dart';

import '../../helpers/fake_media.dart';
import '../../helpers/fake_profile.dart';
import '../../helpers/fake_reviews.dart';
import '../../helpers/test_session.dart';

SessionService _session() {
  final s = testSession(const SignedInSession(testProfile));
  when(() => s.auth.signOut()).thenAnswer((_) async {});
  when(() => s.store.delete(any())).thenAnswer((_) async {});
  return s;
}

AppConfig _config({bool photo = true}) => AppConfig(
  flavor: Flavor.staging,
  apiBaseUrl: 'http://localhost:3000',
  appVersion: '1.2.0',
  buildNumber: '7',
  profilePhotoEnabled: photo,
);

const _photo = PickedPhoto(
  path: '/tmp/me.jpg',
  sizeBytes: 1024,
  contentType: 'image/jpeg',
);

void main() {
  tearDown(Get.reset);

  test('the profile parses the photo and member-since date', () {
    final p = MeProfile.fromJson({
      'id': 'u1',
      'displayName': 'Asha',
      'phone': null,
      'email': 'a@x.in',
      'photo': {
        'mediaId': 'm1',
        'url': 'https://img/u',
        'thumbnailUrl': 'https://img/t',
        'expiresAt': '2026-10-09T10:00:00.000Z',
      },
      'status': 'ACTIVE',
      'roles': ['USER'],
      'createdAt': '2026-01-15T10:00:00.000Z',
    });
    expect(p.photoMediaId, 'm1');
    expect(p.photoThumbnailUrl, 'https://img/t');
    expect(p.createdAt!.year, 2026);
    expect(
      MeProfile.fromJson({'id': 'u', 'roles': <String>[]}).photoUrl,
      isNull,
    );
  });

  group('controller', () {
    test('validates and saves the name; the session follows', () async {
      final repo = FakeProfileRepository();
      final session = _session();
      final c = ProfileController(repo, session);
      c.onInit();
      await pumpEventQueue();
      c.name.text = '   ';
      expect(await c.saveName(), isNull);
      expect(c.nameError.value, 'Enter your name.');
      c.name.text = 'Priya Sharma';
      expect(await c.saveName(), isNull); // unchanged → no call
      c.name.text = '  Priya   S  ';
      expect(await c.saveName(), 'Name saved.');
      expect(repo.calls, contains('name:Priya S'));
      expect(
        (session.state.value as SignedInSession).profile.displayName,
        'Priya S',
      );
    });

    test('uploads and sets a photo; size limits are checked', () async {
      final repo = FakeProfileRepository();
      final media = FakeMediaRepository();
      final picker = FakePhotoPicker(_photo);
      final c = ProfileController(
        repo,
        _session(),
        media: media,
        picker: picker,
      );
      c.onInit();
      await pumpEventQueue();
      expect(await c.changePhoto(PhotoSource.gallery), isNull);
      expect(media.uploads.single, 'user:u1:/tmp/me.jpg');
      expect(c.profile!.photoMediaId, 'media-1');
      picker.next = const PickedPhoto(
        path: '/tmp/big.jpg',
        sizeBytes: coverMaxBytes + 1,
        contentType: 'image/jpeg',
      );
      expect(await c.changePhoto(PhotoSource.camera), contains('5 MB'));
      expect(await c.removePhoto(), isNull);
      expect(c.profile!.photoMediaId, isNull);
    });

    test('deleting the account signs out with a message', () async {
      final repo = FakeProfileRepository();
      final session = _session();
      final c = ProfileController(repo, session);
      repo.failNext = const NetworkFailure();
      expect(await c.deleteAccount(), contains('offline'));
      expect(session.isSignedIn, isTrue);
      expect(await c.deleteAccount(), isNull);
      expect(repo.deleted, isTrue);
      expect(
        (session.state.value as GuestSession).message,
        contains('Sign in again any time to restore it'),
      );
    });
  });

  group('screens', () {
    Future<(FakeProfileRepository, FakeExternalActions)> pump(
      WidgetTester tester,
      Widget page, {
      bool photo = true,
    }) async {
      Get.testMode = true;
      Get.put<AppConfig>(_config(photo: photo));
      Get.put<SessionService>(_session());
      final repo =
          Get.put<ProfileRepository>(FakeProfileRepository())
              as FakeProfileRepository;
      final external =
          Get.put<ExternalActions>(FakeExternalActions())
              as FakeExternalActions;
      Get.put<MediaRepository>(FakeMediaRepository());
      Get.put<PhotoPicker>(FakePhotoPicker(_photo));
      Get.put<ReviewsRepository>(FakeReviewsRepository());
      await tester.pumpWidget(GetMaterialApp(home: page));
      await tester.pumpAndSettle();
      return (repo, external);
    }

    testWidgets('My profile shows details and saves the name', (tester) async {
      final (repo, _) = await pump(tester, const ProfileView());
      expect(find.text('+919800000001'), findsOneWidget);
      expect(find.text('Not added'), findsOneWidget); // email
      expect(find.text('Member since'), findsOneWidget);
      expect(find.bySemanticsLabel('Add profile photo'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Your name'),
        'P S',
      );
      await tester.tap(find.text('Save name'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('name:P S'));
      expect(find.text('Name saved.'), findsOneWidget);
    });

    testWidgets('the photo can be hidden by configuration', (tester) async {
      await pump(tester, const ProfileView(), photo: false);
      expect(find.bySemanticsLabel('Add profile photo'), findsNothing);
      expect(find.text('Your name'), findsOneWidget);
    });

    testWidgets('changing the photo from the sheet', (tester) async {
      final (repo, _) = await pump(tester, const ProfileView());
      await tester.tap(find.bySemanticsLabel('Add profile photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from photos'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('photo:media-1'));
      expect(find.bySemanticsLabel('Change profile photo'), findsOneWidget);
    });

    testWidgets('deleting needs DELETE typed, then signs out', (tester) async {
      final (repo, _) = await pump(tester, const ProfileView());
      await tester.scrollUntilVisible(
        find.text('Delete account'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('it is restored'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Delete my account');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(
        find.widgetWithText(TextField, 'Type DELETE to confirm'),
        'delete',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(
        find.widgetWithText(TextField, 'Type DELETE to confirm'),
        'DELETE',
      );
      await tester.pump();
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repo.deleted, isTrue);
      expect(Get.find<SessionService>().isSignedIn, isFalse);
    });

    testWidgets('Help shows FAQs, placeholder contacts and version', (
      tester,
    ) async {
      final (_, external) = await pump(tester, const HelpView());
      expect(find.text('Frequently asked questions'), findsOneWidget);
      expect(find.text('test@gmail.com'), findsOneWidget);
      expect(find.text('1234554321'), findsOneWidget);
      await tester.tap(find.text('Email support'));
      await tester.pumpAndSettle();
      expect(external.emails.single, 'test@gmail.com');
      await tester.tap(find.text('Call support'));
      await tester.pumpAndSettle();
      expect(external.calls.single, '1234554321');
      await tester.scrollUntilVisible(find.text('App version'), 100);
      expect(find.text('1.2.0 (7)'), findsOneWidget);
      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      expect(find.text('The privacy policy is coming soon.'), findsOneWidget);
    });

    testWidgets('My reviews lists reviews with their status', (tester) async {
      await pump(tester, const SizedBox());
      final reviews = Get.find<ReviewsRepository>() as FakeReviewsRepository;
      reviews.mineList.add(
        Review(
          id: 'rv1',
          bookingId: 'b1',
          listingId: 'l1',
          listingTitle: 'Lotus Grand Mahal',
          rating: 4,
          comment: 'Great hall',
          commentStatus: CommentStatus.pendingModeration,
          createdAt: DateTime(2026, 11, 8),
        ),
      );
      await tester.pumpWidget(const GetMaterialApp(home: MyReviewsView()));
      await tester.pumpAndSettle();
      expect(find.text('Lotus Grand Mahal'), findsOneWidget);
      expect(
        find.text('Your comment is waiting for approval.'),
        findsOneWidget,
      );
    });

    testWidgets('My reviews says when there are none', (tester) async {
      await pump(tester, const MyReviewsView());
      expect(find.text('No reviews yet'), findsOneWidget);
    });

    testWidgets('profile and delete screens fit at 200 % text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, const ProfileView());
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Delete account'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const GetMaterialApp(home: HelpView()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
