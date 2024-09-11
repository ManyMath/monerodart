import 'package:xmrdart/monero.dart' as libxmr;

void main() {
  // Test vector from https://xmrtests.llcoins.net/addresstests.html
  String mnemonic =
      "hemlock jubilee eden hacksaw boil superior inroads epoxy exhale orders cavernous second brunt saved richly lower upgrade hitched launching deepest mostly playful layout lower eden";
  print("Mnemonic: $mnemonic");

  // Generate address from the provided mnemonic.
  String address = libxmr.generateAddress(
      mnemonic: mnemonic, network: 0, account: 0, index: 0);
  print("Address: $address");

  // Generate subaddress.
  String subaddress = libxmr.generateAddress(
      mnemonic: mnemonic, network: 0, account: 0, index: 1);
  print("Subaddress: $subaddress");

  // Generate mnemonic.
  String generatedMnemonic = libxmr.generateMnemonic(language: 1);
  print("Generated mnemonic: $generatedMnemonic");

  // If needed, generate an address with the new mnemonic.
  String newAddress = libxmr.generateAddress(
      mnemonic: generatedMnemonic, network: 0, account: 0, index: 0);
  print("New address from generated mnemonic: $newAddress");

  // Generate subaddress with new mnemonic.
  String newSubaddress = libxmr.generateAddress(
      mnemonic: generatedMnemonic, network: 0, account: 0, index: 1);
  print("New subaddress from generated mnemonic: $newSubaddress");
}
