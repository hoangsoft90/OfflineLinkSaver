import 'package:flutter_test/flutter_test.dart';
import 'package:offline_link_saver/models/content_block.dart';

void main() {
  group('ContentBlock', () {
    test('creates paragraph block', () {
      final block = ContentBlock(
        type: BlockType.paragraph,
        text: 'This is a paragraph.',
      );

      expect(block.type, BlockType.paragraph);
      expect(block.text, 'This is a paragraph.');
    });

    test('creates heading block', () {
      final block = ContentBlock(
        type: BlockType.heading,
        text: 'Heading 1',
        level: 1,
      );

      expect(block.type, BlockType.heading);
      expect(block.text, 'Heading 1');
      expect(block.level, 1);
    });

    test('creates image block', () {
      final block = ContentBlock(
        type: BlockType.image,
        imageUrl: 'https://example.com/image.jpg',
        altText: 'Test image',
      );

      expect(block.type, BlockType.image);
      expect(block.imageUrl, 'https://example.com/image.jpg');
      expect(block.altText, 'Test image');
    });

    test('creates quote block', () {
      final block = ContentBlock(
        type: BlockType.quote,
        text: 'This is a quote.',
      );

      expect(block.type, BlockType.quote);
      expect(block.text, 'This is a quote.');
    });

    test('creates list block', () {
      final block = ContentBlock(
        type: BlockType.list,
        items: ['Item 1', 'Item 2', 'Item 3'],
      );

      expect(block.type, BlockType.list);
      expect(block.items, ['Item 1', 'Item 2', 'Item 3']);
    });

    test('creates code block', () {
      final block = ContentBlock(
        type: BlockType.code,
        text: 'print("Hello")',
        language: 'dart',
      );

      expect(block.type, BlockType.code);
      expect(block.text, 'print("Hello")');
      expect(block.language, 'dart');
    });

    test('toJson creates correct JSON', () {
      final block = ContentBlock(
        type: BlockType.heading,
        text: 'Heading',
        level: 2,
      );

      final json = block.toJson();
      expect(json['type'], 'heading');
      expect(json['text'], 'Heading');
      expect(json['level'], 2);
    });

    test('fromJson creates block correctly', () {
      final json = {
        'type': 'paragraph',
        'text': 'Test text',
      };

      final block = ContentBlock.fromJson(json);
      expect(block.type, BlockType.paragraph);
      expect(block.text, 'Test text');
    });

    test('fromJson handles unknown type', () {
      final json = {
        'type': 'unknown_type',
        'text': 'Test text',
      };

      final block = ContentBlock.fromJson(json);
      expect(block.type, BlockType.paragraph); // defaults to paragraph
    });
  });

  group('ArticleContent', () {
    test('creates content with blocks', () {
      final blocks = [
        ContentBlock(type: BlockType.heading, text: 'Title'),
        ContentBlock(type: BlockType.paragraph, text: 'Content'),
      ];

      final content = ArticleContent(blocks: blocks);
      expect(content.blocks.length, 2);
    });

    test('toPlainText combines all text', () {
      final blocks = [
        ContentBlock(type: BlockType.heading, text: 'Title'),
        ContentBlock(type: BlockType.paragraph, text: 'This is content.'),
        ContentBlock(type: BlockType.quote, text: 'A quote.'),
      ];

      final content = ArticleContent(blocks: blocks);
      final plainText = content.toPlainText();
      expect(plainText, contains('Title'));
      expect(plainText, contains('This is content.'));
      expect(plainText, contains('A quote.'));
    });

    test('wordCount counts words correctly', () {
      final blocks = [
        ContentBlock(type: BlockType.paragraph, text: 'This is a test'),
      ];

      final content = ArticleContent(blocks: blocks);
      expect(content.wordCount, 4);
    });

    test('wordCount handles empty content', () {
      final content = ArticleContent(blocks: []);
      expect(content.wordCount, 0);
    });

    test('toJson creates correct JSON', () {
      final blocks = [
        ContentBlock(type: BlockType.paragraph, text: 'Test'),
      ];

      final content = ArticleContent(blocks: blocks);
      final json = content.toJson();
      expect(json['blocks'], isA<List>());
      expect(json['blocks'].length, 1);
    });

    test('fromJson creates content correctly', () {
      final json = {
        'blocks': [
          {'type': 'paragraph', 'text': 'Test text'},
        ],
      };

      final content = ArticleContent.fromJson(json);
      expect(content.blocks.length, 1);
      expect(content.blocks.first.text, 'Test text');
    });
  });
}
