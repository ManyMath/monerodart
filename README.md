# `monero`

## Getting started

Make sure to have Rust installed via [`rustup`](https://rustup.rs/).
<!--- TODO: Add minimum Rust toolchain version. --->

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

- To update Cargokit:
  ```
  git subtree pull --prefix cargokit https://github.com/irondash/cargokit.git main --squash
  ```
- To generate `monero-rust_bindings_generated.dart` Dart bindings for C:
  ```
  dart run ffigen --config ffigen.yaml
  ```
- If bindings are generated for a new (not previously supported/included in `lib/monero_base.dart`) 
  function, a wrapper must be written for it by hand (see: `generateMnemonic`, `generateAddress`).
