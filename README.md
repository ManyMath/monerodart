# `monero`

## Setup

### Native assets

Native assets is currently an experimental feature that is available in Flutter's `master` branch behind an optional Flutter config:

```
flutter config --enable-native-assets
```

See [this tracking issue](https://github.com/flutter/flutter/issues/129757) and [this milestone](https://github.com/dart-lang/native/milestone/15) for the eventual inclusion of native assets in a release.

### Quick setup

```
git clone git@github.com:ManyMath/monerodart
cd monerodart
git submodule update --init --recursive
dart pub get
dart --enable-experiment=native-assets run bin/monero_example.dart
```
<!--- TODO: Remove the `git submodule update --init --recursive` step after libxmr transitions from monero-serai to monero-wallet. --->
and wait a moment as the native assets are built.

## Development

- To generate `monero-rust_bindings_generated.dart` Dart bindings for C:
  ```
  dart --enable-experiment=native-assets run ffigen --config ffigen.yaml
  ```
- If bindings are generated for a new (not previously supported/included in `lib/monero_base.dart`) 
  function, a wrapper must be written for it by hand (see: `generateMnemonic`, `generateAddress`).
