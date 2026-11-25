import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/services/usage_counter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/test_db.dart';

const String _url = 'https://collector.example.test/ping';

void main() {
  late LocalDatabase db;
  late SettingsRepository settings;
  late List<http.Request> sent;
  late DateTime clock;

  UsageCounter make({String endpoint = _url, int status = 204, bool throws = false}) {
    final client = MockClient((req) async {
      sent.add(req);
      if (throws) throw http.ClientException('offline');
      return http.Response('', status);
    });
    return UsageCounter(settings: settings, endpoint: endpoint, client: client, now: () => clock);
  }

  setUp(() async {
    db = await openTestDatabase();
    settings = SettingsRepository(db);
    sent = <http.Request>[];
    clock = DateTime(2026, 11, 25, 9);
  });

  group('configuration', () {
    test('disabled with no endpoint, a non-https or a malformed one', () {
      expect(make(endpoint: '').configured, isFalse);
      expect(make(endpoint: 'http://insecure.example.test').configured, isFalse);
      expect(make(endpoint: 'not a url').configured, isFalse);
      expect(make().configured, isTrue);
    });

    test('this build has no collector configured, so nothing can be sent', () {
      expect(kUsagePingUrl, isEmpty, reason: 'an endpoint must come only from --dart-define');
    });
  });

  group('consent', () {
    test('nothing is sent before the user agrees', () async {
      final c = make();
      expect(await c.consent(), UsageConsent.unset);
      expect(await c.maybePing(platform: 'android', locale: 'ar'), isFalse);
      expect(sent, isEmpty);
    });

    test('declining sends nothing, and consent can be changed later', () async {
      final c = make();
      await c.setConsent(false);
      expect(await c.consent(), UsageConsent.declined);
      expect(await c.maybePing(platform: 'android', locale: 'ar'), isFalse);
      expect(sent, isEmpty);
      await c.setConsent(true);
      expect(await c.consent(), UsageConsent.granted);
      expect(await c.maybePing(platform: 'android', locale: 'ar'), isTrue);
      expect(sent, hasLength(1));
    });

    test('turning it off stops further pings the same day and later days', () async {
      final c = make();
      await c.setConsent(true);
      expect(await c.maybePing(platform: 'web', locale: 'en'), isTrue);
      await c.setConsent(false);
      clock = DateTime(2026, 11, 26, 9);
      expect(await c.maybePing(platform: 'web', locale: 'en'), isFalse);
      expect(sent, hasLength(1));
    });
  });

  group('what is sent', () {
    test('exactly five anonymous fields and nothing else', () async {
      final c = make();
      await c.setConsent(true);
      await c.maybePing(platform: 'android', locale: 'ar');
      final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), <String>{'id', 'v', 'p', 'l', 'd'});
      expect(body['p'], 'android');
      expect(body['l'], 'ar');
      expect(body['d'], '2026-11-25');
      expect(body['v'], kUsageAppVersion);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(body['id'] as String), isTrue);
      expect(sent.single.method, 'POST');
      expect(sent.single.url.toString(), _url);
      // لا مسار لتسرّب أي نص من بياناتها: الجسم كله ما سبق.
      expect(sent.single.body.length, lessThan(200));
    });

    test('an unknown language is sent as en, never as free text', () async {
      final c = make();
      await c.setConsent(true);
      final p = await c.payload(platform: 'web', locale: 'fr');
      expect(p['l'], 'en');
    });

    test('the install id is stable on a device and is random between devices', () async {
      final c = make();
      final a = await c.installId();
      expect(await c.installId(), a);
      final other = SettingsRepository(await openTestDatabase());
      final b = await UsageCounter(settings: other, endpoint: _url).installId();
      expect(b, isNot(a));
    });

    test('a damaged stored id is replaced by a valid one', () async {
      await settings.set(kUsageInstallIdKey, 'not-an-id');
      final id = await make().installId();
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
    });
  });

  group('once a day and failure handling', () {
    test('only one ping per day, then again the next day', () async {
      final c = make();
      await c.setConsent(true);
      expect(await c.maybePing(platform: 'android', locale: 'ar'), isTrue);
      expect(await c.maybePing(platform: 'android', locale: 'ar'), isFalse);
      expect(sent, hasLength(1));
      clock = DateTime(2026, 11, 26, 8);
      expect(await c.maybePing(platform: 'android', locale: 'ar'), isTrue);
      expect(sent, hasLength(2));
    });

    test('a failed send is swallowed and retried next time, not marked as done', () async {
      final bad = make(throws: true);
      await bad.setConsent(true);
      expect(await bad.maybePing(platform: 'android', locale: 'ar'), isFalse);
      final serverError = make(status: 500);
      expect(await serverError.maybePing(platform: 'android', locale: 'ar'), isFalse);
      expect(await settings.get<String>(kUsageLastPingKey), isNull);
      final good = make();
      expect(await good.maybePing(platform: 'android', locale: 'ar'), isTrue);
      expect(await settings.get<String>(kUsageLastPingKey), '2026-11-25');
    });

    test('an unconfigured counter never reaches the network even with consent', () async {
      final c = make(endpoint: '');
      await settings.set(kUsageConsentKey, '1');
      expect(await c.maybePing(platform: 'android', locale: 'ar'), isFalse);
      expect(sent, isEmpty);
    });
  });

  group('privacy of the device-only settings', () {
    test('consent, install id and last ping are never exported', () async {
      for (final k in <String>[kUsageConsentKey, kUsageInstallIdKey, kUsageLastPingKey]) {
        expect(LocalDatabase.isExportableSetting(k), isFalse, reason: k);
      }
      final c = make();
      await c.setConsent(true);
      await c.maybePing(platform: 'android', locale: 'ar');
      final export = await db.exportAll();
      expect(jsonEncode(export).contains('usage_'), isFalse);
      expect(jsonEncode(export).contains(await c.installId()), isFalse);
    });
  });
}
