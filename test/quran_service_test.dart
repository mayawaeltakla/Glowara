import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/services/quran_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _surahBody() => jsonEncode(<String, dynamic>{
      'code': 200,
      'status': 'OK',
      'data': <String, dynamic>{
        'number': 2,
        'name': 'سورة البقرة',
        'englishName': 'Al-Baqarah',
        'numberOfAyahs': 2,
        'ayahs': <Map<String, dynamic>>[
          <String, dynamic>{'number': 9, 'text': 'الٓمٓ', 'numberInSurah': 1},
          <String, dynamic>{'number': 10, 'text': 'ذَٰلِكَ', 'numberInSurah': 2},
        ],
      },
    });

http.Response _okResponse() => http.Response.bytes(utf8.encode(_surahBody()), 200);

RemoteQuranService _service(http.Client client, {int maxAttempts = 3}) =>
    RemoteQuranService(
      client: client,
      maxAttempts: maxAttempts,
      retryDelay: Duration.zero,
    );

void main() {
  test('returns the surah data on a 200 response', () async {
    final requested = <Uri>[];
    final service = _service(MockClient((request) async {
      requested.add(request.url);
      return _okResponse();
    }));

    final result = await service.getSurah(2);

    expect(result.ok, isTrue);
    expect(result.errorType, isNull);
    expect(requested.single.path, endsWith('/surah/2/quran-uthmani'));
    final surah = Surah.fromApi(result.data!);
    expect(surah.name, 'سورة البقرة');
    expect(surah.ayahs, hasLength(2));
  });

  test('Ayah keeps the global number separate from the number in the surah', () {
    final surah = Surah.fromApi(
      (jsonDecode(_surahBody()) as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
    expect(surah.ayahs.first.number, 9);
    expect(surah.ayahs.first.numberInSurah, 1);
    expect(surah.ayahs.last.number, 10);
    expect(surah.ayahs.last.numberInSurah, 2);
  });

  test('rejects an out-of-range surah without calling the network', () async {
    var calls = 0;
    final service = _service(MockClient((request) async {
      calls++;
      return _okResponse();
    }));

    expect((await service.getSurah(0)).errorType, QuranErrorType.invalidRequest);
    expect((await service.getSurah(115)).errorType, QuranErrorType.invalidRequest);
    expect(calls, 0);
  });

  test('does not retry a client error such as 404', () async {
    var calls = 0;
    final service = _service(MockClient((request) async {
      calls++;
      return http.Response('not found', 404);
    }));

    final result = await service.getSurah(1);

    expect(result.ok, isFalse);
    expect(result.errorType, QuranErrorType.server);
    expect(result.error, 'HTTP 404');
    expect(calls, 1);
  });

  test('retries a server error and succeeds on a later attempt', () async {
    var calls = 0;
    final service = _service(MockClient((request) async {
      calls++;
      return calls < 3
          ? http.Response('busy', 503)
          : _okResponse();
    }));

    final result = await service.getSurah(2);

    expect(result.ok, isTrue);
    expect(calls, 3);
  });

  test('gives up after the maximum attempts on repeated server errors', () async {
    var calls = 0;
    final service = _service(MockClient((request) async {
      calls++;
      return http.Response('busy', 503);
    }));

    final result = await service.getSurah(1);

    expect(result.ok, isFalse);
    expect(result.errorType, QuranErrorType.server);
    expect(calls, 3);
  });

  test('reports a timeout after retrying', () async {
    var calls = 0;
    final service = _service(MockClient((request) async {
      calls++;
      throw TimeoutException('slow');
    }));

    final result = await service.getSurah(1);

    expect(result.errorType, QuranErrorType.timeout);
    expect(calls, 3);
  });

  test('reports a network failure', () async {
    final service = _service(
      MockClient((request) async => throw http.ClientException('offline')),
      maxAttempts: 2,
    );

    final result = await service.getSurah(1);

    expect(result.ok, isFalse);
    expect(result.errorType, QuranErrorType.network);
  });

  test('reports a malformed response without retrying', () async {
    var calls = 0;
    final service = _service(MockClient((request) async {
      calls++;
      return http.Response('<html>oops</html>', 200);
    }));

    final result = await service.getSurah(1);

    expect(result.errorType, QuranErrorType.invalidResponse);
    expect(calls, 1);
  });

  test('reports an API-level error code', () async {
    final service = _service(MockClient((request) async => http.Response(
          jsonEncode(<String, dynamic>{'code': 404, 'status': 'Not Found'}),
          200,
        )));

    final result = await service.getSurah(1);

    expect(result.ok, isFalse);
    expect(result.errorType, QuranErrorType.server);
    expect(result.error, 'Not Found');
  });
}
