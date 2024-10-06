# `monero`
## Library
This is a library for using Monero in Dart.  It uses `monero-rust`, whose cargo 
build is integrated into the Dart build process by 
[`native_toolchain_rust`](https://pub.dev/packages/native_toolchain_rust).

## Commandline interface (CLI)
The `bin` folder contains a tool for setting up the latest Monero release by 
either building it from source (by default) and/or downloading and verifying 
binary release archives.  This tool is separate from the library and its use 
is optional.  Its purpose is to set up a Monero node and (optionally) a wallet 
RPC server for testing and developing the library.  It can be installed as in:
```
dart pub global activate monero
```

and used it as in:
```
monero --help
```

## Setup
### Dart 3.6
The library requires Dart 3.6 for its native assets feature.

### Native assets
Native assets is currently an experimental feature that is available in 
Flutter's `master` branch behind an optional Flutter config.  Enable it as in: 
```
flutter config --enable-native-assets
```

See [this tracking issue](https://github.com/flutter/flutter/issues/129757) and 
[this milestone](https://github.com/dart-lang/native/milestone/15) for the 
eventual inclusion of native assets in a release.

### Quick start
With Dart ^3.6 installed and set as the default:
```
git clone git@github.com:ManyMath/monerodart
cd monerodart
dart pub get
dart --enable-experiment=native-assets run example/monero.dart
```
and wait a moment as the native assets are built.

## Development
- To generate `monero-rust_bindings_generated.dart` Dart bindings for C:
  ```
  dart --enable-experiment=native-assets run ffigen --config ffigen.yaml
  ```
- If bindings are generated for a new (not previously supported/included in 
  `lib/monero_base.dart`) function, a wrapper must be written for it by hand 
  (see: `generateMnemonic`, `generateAddress`).
