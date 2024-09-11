import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'libxmr_bindings_generated.dart';

const String _libName = 'libxmr';

/// The dynamic library in which the symbols for [LibxmrBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open(
        'rust/target/release/$_libName.framework/lib$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('rust/target/release/lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('rust/target/release/lib$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final LibxmrBindings _bindings = LibxmrBindings(_dylib);

/// Generates a mnemonic in the specified language.
/// Language: 0 = German, 1 = English, 2 = Spanish, ..., 12 = Old English.
String generateMnemonic({int language = 1}) {
  final Pointer<Char> seedPtr = _bindings.generate_mnemonic(language);
  final utf8Pointer = seedPtr.cast<Utf8>();
  final seed = utf8Pointer.toDartString();

  calloc.free(utf8Pointer);

  return seed;
}

/// Generates a Monero address from the given mnemonic.
/// - [mnemonic]: A string representing the mnemonic.
/// - [network]: Network type (0 = Mainnet, 1 = Testnet, 2 = Stagenet).
/// - [account]: The account index.
/// - [index]: The subaddress index.
String generateAddress(
    {String mnemonic = "", int network = 0, int account = 0, int index = 0}) {
  Pointer<Char> mnemonicPtr = mnemonic.toNativeUtf8().cast<Char>();
  final Pointer<Char> addressPtr =
      _bindings.generate_address(mnemonicPtr, network, account, index);

  final utf8Pointer = addressPtr.cast<Utf8>();
  final address = utf8Pointer.toDartString();

  calloc.free(utf8Pointer);

  return address;
}
