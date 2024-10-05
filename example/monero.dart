import 'package:monero/monero.dart' as monero;

void main() {
  // Test vector from https://xmrtests.llcoins.net/addresstests.html
  String mnemonic =
      "hemlock jubilee eden hacksaw boil superior inroads epoxy exhale orders cavernous second brunt saved richly lower upgrade hitched launching deepest mostly playful layout lower eden";
  print("Mnemonic: $mnemonic");

  // Generate address from the provided mnemonic.
  String address = monero.generateAddress(
      mnemonic: mnemonic, network: 0, account: 0, index: 0);
  print("Address: $address");

  // Generate subaddress.
  String subaddress = monero.generateAddress(
      mnemonic: mnemonic, network: 0, account: 0, index: 1);
  print("Subaddress: $subaddress");

  // Generate mnemonic.
  String generatedMnemonic = monero.generateMnemonic(language: 1);
  print("Generated mnemonic: $generatedMnemonic");

  // If needed, generate an address with the new mnemonic.
  String newAddress = monero.generateAddress(
      mnemonic: generatedMnemonic, network: 0, account: 0, index: 0);
  print("New address from generated mnemonic: $newAddress");

  // Generate subaddress with new mnemonic.
  String newSubaddress = monero.generateAddress(
      mnemonic: generatedMnemonic, network: 0, account: 0, index: 1);
  print("New subaddress from generated mnemonic: $newSubaddress");
}
