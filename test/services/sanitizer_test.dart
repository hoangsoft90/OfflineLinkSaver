import 'package:flutter_test/flutter_test.dart';
import 'package:offline_link_saver/models/content_block.dart';
import 'package:offline_link_saver/services/extractor/sanitizer.dart';

void main() {
  group('Sanitizer', () {
    late Sanitizer sanitizer;

    setUp(() {
      sanitizer = Sanitizer();
    });

    group('sanitize text blocks', () {
      test('removes script tags from text', () {
        final blocks = [
          ContentBlock(
            type: BlockType.paragraph,
            text: 'Hello <script>alert("xss")</script> World',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.first.text, 'Hello  World');
        expect(sanitized.first.text, isNot(contains('<script>')));
      });

      test('removes iframe tags from text', () {
        final blocks = [
          ContentBlock(
            type: BlockType.paragraph,
            text: 'Before <iframe src="evil.com"></iframe> After',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.first.text, isNot(contains('<iframe>')));
      });

      test('removes on* event handlers from text', () {
        final blocks = [
          ContentBlock(
            type: BlockType.paragraph,
            text: 'Text onclick=evil() more',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.first.text, isNot(contains('onclick=')));
      });

      test('removes any HTML tags from text', () {
        final blocks = [
          ContentBlock(
            type: BlockType.paragraph,
            text: 'Text <b>bold</b> and <i>italic</i>',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.first.text, isNot(contains('<b>')));
        expect(sanitized.first.text, isNot(contains('<i>')));
        expect(sanitized.first.text, contains('bold'));
        expect(sanitized.first.text, contains('italic'));
      });
    });

    group('sanitize image blocks', () {
      test('keeps http images', () {
        final blocks = [
          ContentBlock(
            type: BlockType.image,
            imageUrl: 'http://example.com/image.jpg',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 1);
        expect(sanitized.first.imageUrl, 'http://example.com/image.jpg');
      });

      test('keeps https images', () {
        final blocks = [
          ContentBlock(
            type: BlockType.image,
            imageUrl: 'https://example.com/image.jpg',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 1);
        expect(sanitized.first.imageUrl, 'https://example.com/image.jpg');
      });

      test('removes javascript images', () {
        final blocks = [
          ContentBlock(
            type: BlockType.image,
            imageUrl: 'javascript:alert(1)',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 0);
      });

      test('removes data URI images', () {
        final blocks = [
          ContentBlock(
            type: BlockType.image,
            imageUrl: 'data:image/png;base64,abc123',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 0);
      });

      test('removes images with empty URL', () {
        final blocks = [
          ContentBlock(
            type: BlockType.image,
            imageUrl: '',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 0);
      });

      test('removes images with null URL', () {
        final blocks = [
          ContentBlock(
            type: BlockType.image,
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 0);
      });
    });

    group('sanitize link blocks', () {
      test('keeps http links', () {
        final blocks = [
          ContentBlock(
            type: BlockType.link,
            url: 'http://example.com',
            text: 'Link',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 1);
      });

      test('keeps https links', () {
        final blocks = [
          ContentBlock(
            type: BlockType.link,
            url: 'https://example.com',
            text: 'Link',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 1);
      });

      test('removes javascript links', () {
        final blocks = [
          ContentBlock(
            type: BlockType.link,
            url: 'javascript:alert(1)',
            text: 'Link',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 0);
      });

      test('removes data links', () {
        final blocks = [
          ContentBlock(
            type: BlockType.link,
            url: 'data:text/html,<script>',
            text: 'Link',
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 0);
      });
    });

    group('sanitize list blocks', () {
      test('cleans list items', () {
        final blocks = [
          ContentBlock(
            type: BlockType.list,
            items: [
              'Item 1 <script>xss</script>',
              'Item 2 onclick=evil()',
              'Item 3 <b>bold</b>',
            ],
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.length, 1);
        expect(sanitized.first.items!.length, 3);
        expect(sanitized.first.items![0], isNot(contains('<script>')));
        expect(sanitized.first.items![1], isNot(contains('onclick=')));
        expect(sanitized.first.items![2], isNot(contains('<b>')));
      });

      test('removes empty items after sanitization', () {
        final blocks = [
          ContentBlock(
            type: BlockType.list,
            items: [
              'Valid item',
              '<script></script>',
              '',
              'Another item',
            ],
          ),
        ];

        final sanitized = sanitizer.sanitize(blocks);
        expect(sanitized.first.items!.length, 2);
        expect(sanitized.first.items![0], 'Valid item');
        expect(sanitized.first.items![1], 'Another item');
      });
    });

    group('needsSanitization', () {
      test('returns true for content with script tags', () {
        final blocks = [
          ContentBlock(
            type: BlockType.paragraph,
            text: 'Text <script>alert(1)</script>',
          ),
        ];

        expect(Sanitizer.needsSanitization(blocks), true);
      });

      test('returns true for content with iframe', () {
        final blocks = [
          ContentBlock(
            type: BlockType.paragraph,
            text: 'Text <iframe src="evil.com"></iframe>',
          ),
        ];

        expect(Sanitizer.needsSanitization(blocks), true);
      });

      test('returns true for content with javascript URI', () {
        final blocks = [
          ContentBlock(
            type: BlockType.paragraph,
            text: 'javascript:alert(1)',
          ),
        ];

        expect(Sanitizer.needsSanitization(blocks), true);
      });

      test('returns true for image with non-http URL', () {
        final blocks = [
          ContentBlock(
            type: BlockType.image,
            imageUrl: 'data:image/png;base64,abc',
          ),
        ];

        expect(Sanitizer.needsSanitization(blocks), true);
      });

      test('returns false for clean content', () {
        final blocks = [
          ContentBlock(
            type: BlockType.paragraph,
            text: 'This is clean content.',
          ),
          ContentBlock(
            type: BlockType.image,
            imageUrl: 'https://example.com/image.jpg',
          ),
        ];

        expect(Sanitizer.needsSanitization(blocks), false);
      });
    });
  });
}
