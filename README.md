# `monero`
A Monero Dart library.

## Binary management tool
The `bin` folder contains a tool for managing Monero binaries, mostly for 
downloading and verifying the latest release.  This can be helpful to quickly 
set up a Monero node and wallet RPC server on a fresh installation for testing 
and developing the library.  Install it with:
```
dart pub global activate monero
```
and then use it as in:
```
monero --help
```

## Setup
### Dart 3.6
This library requires Dart 3.6 for its native assets feature.

### Native assets
Native assets is currently an experimental feature that is available in 
Flutter's `master` branch behind an optional Flutter config:
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
