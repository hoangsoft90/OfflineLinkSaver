import 'dart:async';
import 'package:http/http.dart' as http;

/// Network client with timeout and redirect handling
class NetworkClient {
  static const int _timeoutSeconds = 15;
  static const int _maxRedirectHops = 5;
  static const int _maxResponseSize = 2 * 1024 * 1024; // 2MB safety guard

  /// Fetch URL with redirect resolution (max 5 hops)
  /// Returns the final response after following redirects
  static Future<http.Response> fetchWithRedirects(String url) async {
    int redirectCount = 0;
    String currentUrl = url;

    while (redirectCount < _maxRedirectHops) {
      try {
        final response = await http.get(
          Uri.parse(currentUrl),
        ).timeout(const Duration(seconds: _timeoutSeconds));

        // Check response size
        if (response.bodyBytes.length > _maxResponseSize) {
          throw Exception('Response too large (${response.bodyBytes.length} bytes)');
        }

        // Check if it's a redirect
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final redirectUrl = response.headers['location'];
          if (redirectUrl == null) {
            break;
          }
          
          // Handle relative redirects
          final resolvedUri = Uri.parse(currentUrl).resolve(redirectUrl);
          currentUrl = resolvedUri.toString();
          redirectCount++;
          continue;
        }

        return response;
      } on TimeoutException {
        throw Exception('Connection timeout after ${_timeoutSeconds}s');
      }
    }

    if (redirectCount >= _maxRedirectHops) {
      throw Exception('Too many redirects (exceeded $_maxRedirectHops hops)');
    }

    // Should not reach here, but handle gracefully
    throw Exception('Failed to fetch URL');
  }

  /// Fetch URL without following redirects
  static Future<http.Response> fetchHead(String url) async {
    try {
      final response = await http.head(
        Uri.parse(url),
      ).timeout(const Duration(seconds: _timeoutSeconds));
      return response;
    } on TimeoutException {
      throw Exception('Connection timeout after ${_timeoutSeconds}s');
    }
  }
}
