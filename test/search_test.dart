import 'package:flutter_test/flutter_test.dart';
import 'package:anned_finds/services/search_service.dart';

void main() {
  group('SearchService Tests', () {
    test('generateSearchTokens should create proper tokens', () {
      // Test the search token generation
      final tokens = SearchService.generateSearchTokens(
        'iPhone 14 Pro Max',
        'Latest Apple smartphone with advanced camera',
        'apple'
      );
      
      print('Generated tokens: $tokens');
      
      // Should contain words from name and description
      expect(tokens, contains('iphone'));
      expect(tokens, contains('14'));
      expect(tokens, contains('pro'));
      expect(tokens, contains('max'));
      expect(tokens, contains('latest'));
      expect(tokens, contains('apple'));
      expect(tokens, contains('smartphone'));
      
      // Should contain partial matches for longer words
      expect(tokens, contains('ip')); // from 'iphone'
      expect(tokens, contains('iph')); 
      expect(tokens, contains('late')); // from 'latest'
    });

    test('generateSearchTokens should handle empty inputs', () {
      final tokens = SearchService.generateSearchTokens('', '');
      expect(tokens, isEmpty);
    });

    test('generateSearchTokens should filter short tokens', () {
      final tokens = SearchService.generateSearchTokens('A B CD EFG', 'X Y');
      
      // Should not contain single characters or short words
      expect(tokens, isNot(contains('a')));
      expect(tokens, isNot(contains('b')));
      expect(tokens, isNot(contains('x')));
      expect(tokens, isNot(contains('y')));
      
      // Should contain words >= 2 characters
      expect(tokens, contains('cd'));
      expect(tokens, contains('efg'));
    });
  });
}