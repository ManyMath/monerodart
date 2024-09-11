import 'package:monero/monero.dart';
import 'package:test/test.dart';

// test vector from https://xmrtests.llcoins.net/addresstests.html
// mnemonic: hemlock jubilee eden hacksaw boil superior inroads epoxy exhale orders cavernous second brunt saved richly lower upgrade hitched launching deepest mostly playful layout lower eden
// seed (hex): 29adefc8f67515b4b4bf48031780ab9d071d24f8a674b879ce7f245c37523807
// private spend: 29adefc8f67515b4b4bf48031780ab9d071d24f8a674b879ce7f245c37523807
// private view: 3bc0b202cde92fe5719c3cc0a16aa94f88a5d19f8c515d4e35fae361f6f2120e
// private view (audit address): 4f02594e84985fd78b91bb25dbb184d673b96b8b7539cc648c9c95a095428400
// public spend: 72170da1793490ea9d0243df46c515444c35104b92b1d75a7d8c5954ba1f49cd
// public view: 21243cb8d0046baf10619d1fe7f38708095b006ef8e8350963c160478c1c0ff0
// address: 45wsWad9EwZgF3VpxQumrUCRaEtdyyh6NG8sVD3YRVVJbK1jkpJ3zq8WHLijVzodQ22LxwkdWx7fS2a6JzaRGzkNU8K2Dhi

void main() {
  group('Monero Wallet FFI Tests', () {
    test('Generate mnemonic in English', () {
      // Generate mnemonic in English (language 1 is English).
      String mnemonic = generateMnemonic(language: 1);

      // Make sure it's not empty.
      expect(mnemonic.isNotEmpty, isTrue);

      // Validate it against a regular expression for mnemonic format (24 words separated by spaces).
      final mnemonicWords = mnemonic.split(' ');
      expect(mnemonicWords.length, 24);
      // TODO integrate polyseed.
    });

    test('Generate Monero address from mnemonic', () {
      // Use the test vector mnemonic.
      const testMnemonic =
          'hemlock jubilee eden hacksaw boil superior inroads epoxy exhale orders cavernous second brunt saved richly lower upgrade hitched launching deepest mostly playful layout lower eden';

      // Expected output address from the test vector.
      const expectedAddress =
          '45wsWad9EwZgF3VpxQumrUCRaEtdyyh6NG8sVD3YRVVJbK1jkpJ3zq8WHLijVzodQ22LxwkdWx7fS2a6JzaRGzkNU8K2Dhi';

      // Generate address from the test mnemonic.
      String generatedAddress = generateAddress(
          mnemonic: testMnemonic, network: 0, account: 0, index: 0);

      // Verify that the generated address matches the expected address.
      expect(generatedAddress, equals(expectedAddress));
    });

    test('Generate mnemonic in different languages', () {
      // Generate mnemonic in German (language = 0).
      String mnemonicGerman = generateMnemonic(language: 0);
      expect(mnemonicGerman.isNotEmpty, isTrue);

      // Check the number of words.
      final mnemonicWordsGerman = mnemonicGerman.split(' ');
      expect(mnemonicWordsGerman.length, 24);

      // Generate mnemonic in Spanish (language = 2).
      String mnemonicSpanish = generateMnemonic(language: 2);
      expect(mnemonicSpanish.isNotEmpty, isTrue);

      // Check the number of words.
      final mnemonicWordsSpanish = mnemonicSpanish.split(' ');
      expect(mnemonicWordsSpanish.length, 24);
    });
  });
}
