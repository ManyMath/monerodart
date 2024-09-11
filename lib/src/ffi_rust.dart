@ffi.DefaultAsset('package:monero/libxmr')
library rust;

import 'dart:ffi' as ffi;

typedef GenerateMnemonicC = ffi.Pointer<ffi.Char> Function(ffi.Uint8);
typedef GenerateMnemonicDart = ffi.Pointer<ffi.Char> Function(int);

typedef GenerateAddressC = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>, ffi.Uint8, ffi.Uint32, ffi.Uint32);
typedef GenerateAddressDart = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>, int, int, int);

@ffi.Native<GenerateMnemonicC>()
external ffi.Pointer<ffi.Char> generateMnemonic(int language);

@ffi.Native<GenerateAddressC>()
external ffi.Pointer<ffi.Char> generateAddress(
  ffi.Pointer<ffi.Char> mnemonic,
  int network,
  int account,
  int index,
);
