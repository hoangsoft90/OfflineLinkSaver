/// URL validation and canonicalization helper
class UrlHelper {
  /// Tracking params to strip from canonical URL
  static const List<String> _trackingParams = [
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'fbclid',
    'gclid',
    'msclkid',
    'ref',
    'mc_cid',
    'mc_eid',
    'mc_eid',
    'mc_cid',
  ];

  /// Validate URL scheme - only http/https allowed
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'http' || uri.scheme == 'https';
    } catch (e) {
      return false;
    }
  }

  /// Reject dangerous schemes
  static bool isDangerousScheme(String url) {
    try {
      final uri = Uri.parse(url);
      final dangerousSchemes = ['javascript', 'file', 'data', 'intent', 'mailto', 'tel'];
      return dangerousSchemes.any((scheme) => uri.scheme == scheme);
    } catch (e) {
      return true; // If can't parse, consider dangerous
    }
  }

  /// Extract domain from URL
  static String extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return '';
    }
  }

  /// Canonicalize URL by stripping tracking params
  static String canonicalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final params = Map<String, String>.from(uri.queryParameters);
      
      // Remove tracking parameters
      for (final param in _trackingParams) {
        params.remove(param);
      }

      // Rebuild URI without tracking params
      // Use removeParameter approach to properly rebuild URL
      var result = url.split('?').first;
      if (params.isNotEmpty) {
        final queryString = params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
        result = '$result?$queryString';
      }
      return result;
    } catch (e) {
      return url; // Return original if parsing fails
    }
  }
}
