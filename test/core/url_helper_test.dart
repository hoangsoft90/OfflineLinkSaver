import 'package:flutter_test/flutter_test.dart';
import 'package:offline_link_saver/core/network/url_helper.dart';

void main() {
  group('UrlHelper', () {
    group('isValidUrl', () {
      test('returns true for valid http URL', () {
        expect(UrlHelper.isValidUrl('http://example.com'), true);
      });

      test('returns true for valid https URL', () {
        expect(UrlHelper.isValidUrl('https://example.com'), true);
      });

      test('returns true for URL with path', () {
        expect(UrlHelper.isValidUrl('https://example.com/article/123'), true);
      });

      test('returns true for URL with query params', () {
        expect(UrlHelper.isValidUrl('https://example.com?q=test&page=1'), true);
      });

      test('returns false for invalid URL', () {
        expect(UrlHelper.isValidUrl('not-a-url'), false);
      });

      test('returns false for empty string', () {
        expect(UrlHelper.isValidUrl(''), false);
      });
    });

    group('isDangerousScheme', () {
      test('returns true for javascript scheme', () {
        expect(UrlHelper.isDangerousScheme('javascript:alert(1)'), true);
      });

      test('returns true for file scheme', () {
        expect(UrlHelper.isDangerousScheme('file:///etc/passwd'), true);
      });

      test('returns true for data scheme', () {
        expect(UrlHelper.isDangerousScheme('data:text/html,<script>'), true);
      });

      test('returns true for intent scheme', () {
        expect(UrlHelper.isDangerousScheme('intent://example.com'), true);
      });

      test('returns true for mailto scheme', () {
        expect(UrlHelper.isDangerousScheme('mailto:test@example.com'), true);
      });

      test('returns true for tel scheme', () {
        expect(UrlHelper.isDangerousScheme('tel:+1234567890'), true);
      });

      test('returns false for http scheme', () {
        expect(UrlHelper.isDangerousScheme('http://example.com'), false);
      });

      test('returns false for https scheme', () {
        expect(UrlHelper.isDangerousScheme('https://example.com'), false);
      });
    });

    group('extractDomain', () {
      test('extracts domain from simple URL', () {
        expect(UrlHelper.extractDomain('https://example.com'), 'example.com');
      });

      test('extracts domain from URL with path', () {
        expect(UrlHelper.extractDomain('https://example.com/article'), 'example.com');
      });

      test('extracts domain from URL with subdomain', () {
        expect(UrlHelper.extractDomain('https://www.example.com'), 'www.example.com');
      });

      test('returns empty string for invalid URL', () {
        expect(UrlHelper.extractDomain('not-a-url'), '');
      });
    });

    group('canonicalizeUrl', () {
      test('removes utm_source parameter', () {
        final result = UrlHelper.canonicalizeUrl('https://example.com?q=test&utm_source=twitter');
        expect(result, contains('q=test'));
        expect(result, isNot(contains('utm_source')));
      });

      test('removes utm_medium parameter', () {
        final result = UrlHelper.canonicalizeUrl('https://example.com?utm_medium=social');
        expect(result, isNot(contains('utm_medium')));
      });

      test('removes utm_campaign parameter', () {
        final result = UrlHelper.canonicalizeUrl('https://example.com?utm_campaign=launch');
        expect(result, isNot(contains('utm_campaign')));
      });

      test('removes fbclid parameter', () {
        final result = UrlHelper.canonicalizeUrl('https://example.com?fbclid=abc123');
        expect(result, isNot(contains('fbclid')));
      });

      test('removes gclid parameter', () {
        final result = UrlHelper.canonicalizeUrl('https://example.com?gclid=xyz789');
        expect(result, isNot(contains('gclid')));
      });

      test('preserves non-tracking parameters', () {
        final result = UrlHelper.canonicalizeUrl('https://example.com?id=123&v=456');
        expect(result, contains('id=123'));
        expect(result, contains('v=456'));
      });

      test('preserves URL without tracking params', () {
        final url = 'https://example.com/article/123';
        expect(UrlHelper.canonicalizeUrl(url), url);
      });

      test('handles URL with multiple tracking params', () {
        final result = UrlHelper.canonicalizeUrl(
          'https://example.com?q=test&utm_source=fb&utm_medium=ad&fbclid=abc',
        );
        expect(result, contains('q=test'));
        expect(result, isNot(contains('utm_source')));
        expect(result, isNot(contains('utm_medium')));
        expect(result, isNot(contains('fbclid')));
      });
    });
  });
}
