import 'dart:io';

import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_rust_mirror/native_toolchain_rust.dart';

void main(List<String> args) async {
  try {
    await build(args, (BuildConfig buildConfig, BuildOutput output) async {
      final builder = RustBuilder(
        package: 'monero',
        cratePath: 'monero-rust',
        buildConfig: buildConfig,
      );
      await builder.run(output: output);
    });
  } catch (e) {
    print(e);
    exit(1);
  }
}
