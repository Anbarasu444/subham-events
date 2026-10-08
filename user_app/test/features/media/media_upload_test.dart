import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/network/api_client.dart';
import 'package:user_app/core/platform/photo_picker.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/presentation/controllers/event_detail_controller.dart';
import 'package:user_app/features/events/presentation/views/event_detail_view.dart';
import 'package:user_app/features/media/data/imagekit_uploader.dart';
import 'package:user_app/features/media/data/media_remote_data_source.dart';
import 'package:user_app/features/media/data/media_repository_impl.dart';
import 'package:user_app/features/media/domain/media_repository.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fake_events_repository.dart';
import '../../helpers/fake_media.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('photo types and size limit', () {
    expect(photoTypeOf('/x/a.JPG'), 'image/jpeg');
    expect(photoTypeOf('/x/a.heic'), 'image/heic');
    expect(photoTypeOf('/x/a.gif'), isNull);
    expect(coverMaxBytes, 5 * 1024 * 1024);
  });

  test('upload chain: intent → ImageKit → complete', () async {
    final api = FakeAdapter([
      FakeAdapter.json(201, {
        'data': {
          'mediaId': 'm1',
          'uploadUrl': 'https://upload.imagekit.io/api/v2/files/upload',
          'token': 'jwt',
          'fields': {
            'fileName': 'm1.jpg',
            'folder': '/local/event-cover/event/e1',
            'isPrivateFile': 'true',
            'useUniqueFileName': 'false',
            'overwriteFile': 'false',
            'checks': '"file.size" <= "5mb"',
          },
          'expire': 2000000000,
          'maxBytes': 5242880,
        },
        'meta': {},
      }),
      FakeAdapter.json(200, {
        'data': {'mediaId': 'm1', 'status': 'READY'},
        'meta': {},
      }),
    ]);
    final ik = FakeAdapter([
      FakeAdapter.json(200, {'fileId': 'file_123', 'filePath': '/x'}),
    ]);
    final file = File('${Directory.systemTemp.path}/cover_test.jpg')
      ..writeAsBytesSync(List.filled(64, 1));
    final repo = MediaRepositoryImpl(
      MediaRemoteDataSource(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
            ..httpClientAdapter = api,
        ),
      ),
      ImageKitUploader(dio: Dio()..httpClientAdapter = ik),
    );
    final result = await repo.uploadEventCover(
      'e1',
      PickedPhoto(path: file.path, sizeBytes: 64, contentType: 'image/jpeg'),
    );
    expect((result as Ok<String>).value, 'm1');
    expect(api.requests.first.path, '/media/uploads');
    expect(
      jsonDecode(jsonEncode(api.requests.first.data)),
      containsPair('ownerId', 'e1'),
    );
    final upload = ik.requests.single;
    expect(upload.uri.host, 'upload.imagekit.io');
    final fields = {
      for (final f in (upload.data as FormData).fields) f.key: f.value,
    };
    expect(fields, containsPair('token', 'jwt'));
    expect(fields, containsPair('folder', '/local/event-cover/event/e1'));
    expect(fields, containsPair('isPrivateFile', 'true'));
    expect(api.requests.last.path, '/media/uploads/m1/complete');
  });

  group('EventDetailController cover', () {
    EventDetailController controller(
      FakeEventsRepository events,
      FakeMediaRepository media,
      FakePhotoPicker picker,
    ) => EventDetailController(
      events,
      'e1',
      media: media,
      picker: picker,
      initial: events.events.single,
    )..onInit();

    late FakeEventsRepository events;
    setUp(() {
      events = FakeEventsRepository(
        events: [testEvent('e1', date: DateTime(2026, 12, 1))],
      );
    });

    test('uploads and sets the cover', () async {
      final media = FakeMediaRepository();
      final c = controller(events, media, FakePhotoPicker(photo));
      await _settle();
      final progress = <double?>[];
      c.coverProgress.listen(progress.add);
      expect(await c.changeCover(PhotoSource.gallery), isNull);
      expect(c.event!.cover!.mediaId, 'media-1');
      expect(c.coverProgress.value, isNull);
      expect(progress, containsAll([0.5, 1.0]));
      expect(events.calls, contains('setCover:e1:media-1'));
    });

    test(
      'checks size and type before uploading; cancel does nothing',
      () async {
        final media = FakeMediaRepository();
        final picker = FakePhotoPicker(
          const PickedPhoto(
            path: '/a.jpg',
            sizeBytes: 6 * 1024 * 1024,
            contentType: 'image/jpeg',
          ),
        );
        final c = controller(events, media, picker);
        expect(await c.changeCover(PhotoSource.gallery), contains('5 MB'));
        picker.next = const PickedPhoto(
          path: '/a.gif',
          sizeBytes: 10,
          contentType: 'image/gif',
        );
        expect(await c.changeCover(PhotoSource.camera), contains('JPEG'));
        picker.next = null;
        expect(await c.changeCover(PhotoSource.gallery), isNull);
        expect(media.uploads, isEmpty);
      },
    );

    test('explains upload failures and removes the cover', () async {
      final media = FakeMediaRepository()
        ..failNext = const ServerFailure(statusCode: 503);
      final c = controller(events, media, FakePhotoPicker(photo));
      expect(
        await c.changeCover(PhotoSource.gallery),
        contains('not available'),
      );
      expect(c.coverProgress.value, isNull);

      expect(await c.changeCover(PhotoSource.gallery), isNull);
      expect(await c.removeCover(), isNull);
      expect(c.event!.cover, isNull);
    });
  });

  test('share text and maps query', () {
    final event = FakeEventsRepository.fromInput(
      'e1',
      EventInput(
        eventType: 'Wedding',
        title: 'Asha & Ravi',
        eventDate: DateTime(2026, 12, 14),
        city: 'Chennai',
        startTime: '18:30',
        venueName: 'Lotus Hall',
        venueAddress: 'Anna Nagar',
      ),
    );
    expect(mapsQuery(event), 'Lotus Hall, Anna Nagar, Chennai');
    expect(
      eventShareText(event),
      'Asha & Ravi\nWedding · Mon, 14 Dec 2026 · 6:30 PM\nLotus Hall, Anna Nagar, Chennai',
    );
  });
}
