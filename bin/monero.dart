import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

void printHelp() {
  print('''
Monero:
  An unofficial tool for downloading and managing official Monero binaries.

Usage:
  monero [options]
Options:
  -a, --auto                Skip prompts, use defaults (build from source).
  -b, --build (default)     Build the latest Monero release from source.
  -d, --dl, --download      Download and verify the latest Monero release.
  -h, --help                Show this help message.
  -r, --remote              Use the specified remote.
  -s, --settings            Edit the current settings.
Description:
  This tool builds Monero from source and/or manages binary releases.
''');
}

Future<bool> promptYesNo(String message) async {
  print(message);
  String? response = stdin.readLineSync();
  return response != null && response.toLowerCase() == 'y';
}

Future<Map<String, dynamic>> setupSettings(
    File settingsFile, bool autoMode, String? customRemote) async {
  Directory parentDir = settingsFile.parent;
  if (!await parentDir.exists()) {
    await parentDir.create(recursive: true);
  }

  String defaultPath = Platform.isWindows
      ? p.join(Platform.environment['APPDATA']!, 'Monero')
      : p.join(Platform.environment['HOME']!, 'Monero');

  String moneroDir;
  if (autoMode) {
    moneroDir = defaultPath;
    print('Using default Monero directory: $moneroDir.');
  } else {
    print(
        'Where should Monero binaries and repository be stored? (Press Enter to use the default: $defaultPath).');
    String? inputPath = stdin.readLineSync();
    moneroDir =
        inputPath != null && inputPath.isNotEmpty ? inputPath : defaultPath;
  }

  String remoteUrl = customRemote ??
      'https://api.github.com/repos/monero-project/monero/releases/latest';

  Map<String, dynamic> settings = {'moneroDir': moneroDir, 'remote': remoteUrl};
  await settingsFile.writeAsString(jsonEncode(settings));

  return settings;
}

Future<void> editSettings() async {
  final settingsFilePath = getSettingsFilePath();
  File settingsFile = File(settingsFilePath);

  if (!await settingsFile.exists()) {
    print('Settings file does not exist. Setting up new settings...');
    await setupSettings(settingsFile, false, null);
    return;
  }

  Map<String, dynamic> settings = jsonDecode(await settingsFile.readAsString());
  print('Current Monero directory: ${settings['moneroDir']}.');
  print(
      'Enter new path for Monero directory (or press Enter to keep current):');
  String? newPath = stdin.readLineSync();

  if (newPath != null && newPath.isNotEmpty) {
    settings['moneroDir'] = newPath;
    await settingsFile.writeAsString(jsonEncode(settings));
    print('Settings updated successfully.');
  } else {
    print('No changes made to settings.');
  }
}

String getSettingsFilePath() {
  if (Platform.isWindows) {
    return p.join(Platform.environment['APPDATA']!, 'Monero', 'settings.json');
  } else {
    return p.join(
        Platform.environment['HOME']!, '.config', 'Monero', 'settings.json');
  }
}

Future<void> handleBuildMode(
    String remoteUrl, String moneroDir, bool autoMode) async {
  // Step 1: Check for dependencies.
  if (Platform.isWindows) {
    await checkWindowsDependencies();
  } else if (Platform.isLinux || Platform.isMacOS) {
    await checkUnixDependencies();
  }

  // Step 2: Select remote and clone the repository.
  final tagName = await fetchLatestReleaseTag(remoteUrl);
  final repoUrl =
      'https://github.com/monero-project/monero.git'; // Correct remote for cloning.
  await cloneMoneroRepo(repoUrl, tagName, moneroDir);

  // Step 3: Build the project.
  if (Platform.isWindows) {
    await buildOnWindows(moneroDir);
  } else if (Platform.isLinux || Platform.isMacOS) {
    await buildOnUnix(moneroDir);
  }
}

Future<void> handleDownloadMode(String moneroDir, bool autoMode,
    String remoteUrl, String? customRemote, File settingsFile) async {
  Directory moneroDirectory = Directory(moneroDir);
  List<FileSystemEntity> files = await moneroDirectory.list().toList();
  List<FileSystemEntity> archives = files.where((file) {
    return file is File &&
        RegExp(r'monero-.*-v\d+\.\d+\.\d+\.\d+\.(zip|tar\.bz2)')
            .hasMatch(file.path);
  }).toList();

  if (archives.isEmpty) {
    print('No Monero archives found in $moneroDir.');
  } else {
    print('Found Monero archives:');
    for (var archive in archives) {
      print('- ${p.basename(archive.path)}');
    }
  }

  await downloadLatestRelease(moneroDir, archives, autoMode, remoteUrl);

  if (customRemote != null) {
    Map<String, dynamic> settings =
        jsonDecode(await settingsFile.readAsString());
    settings['remote'] = customRemote;
    await settingsFile.writeAsString(jsonEncode(settings));
  }
}

Future<String> promptForCustomRemote() async {
  print('Please enter the custom remote URL:');
  String? customRemote = stdin.readLineSync();

  if (customRemote == null || customRemote.isEmpty) {
    print('No remote URL entered. Using the default remote.');
    return 'https://api.github.com/repos/monero-project/monero/releases/latest';
  }

  print('Validating remote URL: $customRemote.');
  try {
    final response = await http.head(Uri.parse(customRemote));
    if (response.statusCode >= 200 && response.statusCode < 400) {
      print('Custom remote validated successfully.');
      return customRemote;
    } else {
      print('Invalid remote URL. HTTP status code: ${response.statusCode}.');
      exit(1); // Terminate the program.
    }
  } catch (e) {
    print('An error occurred while validating the remote URL: $e.');
    exit(1); // Terminate the program.
  }
}

Future<void> checkUnixDependencies() async {
  const requiredDeps = [
    'build-essential',
    'cmake',
    'pkg-config',
    'libssl-dev',
    'libzmq3-dev',
    'libsodium-dev',
    'libunwind8-dev',
    'liblzma-dev',
    'libreadline6-dev',
    'libexpat1-dev',
    'libpgm-dev',
    'libhidapi-dev',
    'libusb-1.0-0-dev',
    'libprotobuf-dev',
    'protobuf-compiler',
    'libudev-dev',
  ];

  print('Checking Unix dependencies...');
  final missingDeps = <String>[];
  for (final dep in requiredDeps) {
    final result = await Process.run('dpkg', ['-s', dep]);
    if (result.exitCode != 0) {
      missingDeps.add(dep);
    }
  }

  if (missingDeps.isNotEmpty) {
    print('The following dependencies are missing: ${missingDeps.join(', ')}.');
    if (await promptYesNo(
        'Would you like to install missing dependencies? [y/N]')) {
      final installCommand = 'sudo apt-get install -y ${missingDeps.join(' ')}';
      await Process.run('bash', ['-c', installCommand]);
      print('Dependencies installed.');
    } else {
      print('Cannot proceed without installing dependencies.');
      exit(1);
    }
  } else {
    print('All dependencies are installed.');
  }
}

Future<void> checkWindowsDependencies() async {
  const requiredDeps = [
    'cmake',
    'mingw-w64',
    'boost',
    'openssl',
    'zeromq',
    'libsodium',
  ];

  print('Checking Windows dependencies...');
  final missingDeps = <String>[];

  for (final dep in requiredDeps) {
    final result = await Process.run('where', [dep], runInShell: true);
    if (result.exitCode != 0) {
      missingDeps.add(dep);
    }
  }

  if (missingDeps.isNotEmpty) {
    print('The following dependencies are missing: ${missingDeps.join(', ')}.');
    print(
        'Please manually install these dependencies via MSYS2 or appropriate package managers.');
    exit(1);
  } else {
    print('All dependencies are installed.');
  }
}

Future<String> fetchLatestReleaseTag(String remoteUrl) async {
  final response = await http.get(Uri.parse(remoteUrl));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['tag_name'];
  } else {
    print('Failed to fetch the latest release tag.');
    exit(1);
  }
}

Future<void> cloneMoneroRepo(
    String repoUrl, String tagName, String moneroDir) async {
  final cloneDir = p.join(moneroDir, 'monero');
  print('Cloning Monero repository...');
  final cloneCommand =
      'git clone --branch $tagName --recursive $repoUrl $cloneDir';
  final result = await Process.run('bash', ['-c', cloneCommand]);

  if (result.exitCode == 0) {
    print('Repository cloned successfully to $cloneDir.');
  } else {
    print('Failed to clone the repository: ${result.stderr}.');
    exit(1);
  }
}

Future<void> buildOnUnix(String moneroDir) async {
  print('Building Monero on Unix...');
  final buildCommand = 'cd $moneroDir/monero && make';
  final result = await Process.run('bash', ['-c', buildCommand]);

  if (result.exitCode == 0) {
    print('Monero built successfully.');
  } else {
    print('Failed to build Monero: ${result.stderr}.');
    exit(1);
  }
}

Future<void> buildOnWindows(String moneroDir) async {
  print('Building Monero on Windows...');
  final buildCommand = 'cd $moneroDir\\monero && make release-static-win64';
  final result = await Process.run('cmd', ['/c', buildCommand]);

  if (result.exitCode == 0) {
    print('Monero built successfully.');
  } else {
    print('Failed to build Monero: ${result.stderr}.');
    exit(1);
  }
}

Future<void> downloadFile(String url, String binariesPath,
    Map<String, String> releaseHashes, bool autoMode) async {
  final fileName = p.basename(Uri.parse(url).path);
  final filePath = p.join(binariesPath, fileName);
  print('Downloading $url to $filePath...');

  final request = await http.Client().send(http.Request('GET', Uri.parse(url)));
  final totalBytes = request.contentLength ?? 0;
  int receivedBytes = 0;

  List<int> bytes = [];
  await request.stream.listen(
    (List<int> chunk) {
      bytes.addAll(chunk);
      receivedBytes += chunk.length;
      if (totalBytes != 0) {
        double progress = (receivedBytes / totalBytes) * 100;
        stdout.write('\rProgress: ${progress.toStringAsFixed(2)}%.');
      }
    },
    onDone: () async {
      File file = File(filePath);
      await file.writeAsBytes(bytes);
      print('\nDownload completed: $filePath.');

      String? expectedHash = releaseHashes[fileName];
      await verifyFileHash(filePath, expectedHash, autoMode);

      // Ask if the user wants to extract the archive after verification.
      if (await promptYesNo('Do you want to extract the archive? [y/N]')) {
        await extractArchive(filePath, binariesPath, fileName);
      }
    },
    onError: (e) {
      print('\nAn error occurred while downloading the file: $e.');
    },
    cancelOnError: true,
  );
}

Future<void> downloadLatestRelease(String moneroDir,
    List<FileSystemEntity> archives, bool autoMode, String remoteUrl) async {
  print('Using remote: $remoteUrl.');
  try {
    final response = await http.get(Uri.parse(remoteUrl));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tagName = data['tag_name'];
      final bodyHtml = data['body'];

      print('Latest release found: $tagName.');
      print('Parsing download links and hashes from release description...');

      final downloadLinks = extractDownloadLinks(bodyHtml);
      final releaseHashes = extractReleaseHashes(bodyHtml);

      if (downloadLinks.isEmpty || releaseHashes.isEmpty) {
        print('No download links or hashes found in the release description.');
        return;
      }

      String defaultFileName = getDefaultDownloadLink(downloadLinks);
      FileSystemEntity? existingArchive = archives.firstWhere(
          (archive) => p.basename(archive.path) == p.basename(defaultFileName),
          orElse: () => File(''));

      if (existingArchive != File('')) {
        print(
            'You already have the latest release downloaded: ${existingArchive.path}.');
        String? expectedHash = releaseHashes[p.basename(existingArchive.path)];
        await verifyFileHash(existingArchive.path, expectedHash, autoMode);

        if (await promptYesNo(
            'The archive is already downloaded. Do you want to extract the archive? [y/N]')) {
          await extractArchive(
              existingArchive.path, moneroDir, defaultFileName);
        }
        return;
      }

      print('Downloading the default file: $defaultFileName...');
      await downloadFile(defaultFileName, moneroDir, releaseHashes, autoMode);
    } else {
      print(
          'Failed to fetch the latest release. HTTP status code: ${response.statusCode}.');
    }
  } catch (e) {
    print('An error occurred while fetching the latest release: $e.');
  }
}

Future<void> extractArchive(
    String filePath, String extractPath, String fileName) async {
  final archiveExtension = p.extension(fileName);
  try {
    if (archiveExtension == '.zip') {
      await _extractZip(filePath, extractPath);
    } else if (archiveExtension == '.bz2') {
      await _extractTarBz2(filePath, extractPath);
    } else {
      print('Unsupported archive format: $archiveExtension.');
      return;
    }
  } catch (e) {
    print('An error occurred while extracting the archive: $e.');
  }
}

Future<void> _extractZip(String zipFilePath, String extractPath) async {
  print('Extracting zip archive: $zipFilePath...');
  final result =
      await Process.run('unzip', ['-o', zipFilePath, '-d', extractPath]);

  if (result.exitCode == 0) {
    print('Extraction completed successfully.');
  } else {
    print('Failed to extract zip archive: ${result.stderr}.');
  }
}

Future<void> _extractTarBz2(String tarFilePath, String extractPath) async {
  print('Extracting tar.bz2 archive: $tarFilePath...');
  final result = await Process.run(
      'tar', ['-xjf', tarFilePath, '-C', extractPath, '--overwrite']);

  if (result.exitCode == 0) {
    print('Extraction completed successfully.');
  } else {
    print('Failed to extract tar.bz2 archive: ${result.stderr}.');
  }
}

Future<String> calculateFileHash(String filePath) async {
  File file = File(filePath);
  var bytes = await file.readAsBytes();
  return sha256.convert(bytes).toString();
}

Future<void> verifyFileHash(
    String filePath, String? expectedHash, bool autoMode) async {
  if (expectedHash == null) {
    print('No expected hash found for $filePath. Skipping verification.');
    return;
  }

  String actualHash = await calculateFileHash(filePath);
  if (actualHash == expectedHash) {
    print('Hash verification succeeded for: $filePath.');
  } else {
    print(
        'Hash mismatch for $filePath. Expected: $expectedHash, Actual: $actualHash.');
  }
}

List<String> extractDownloadLinks(String bodyHtml) {
  final downloadLinks = RegExp(
          r'\[.*?\]\((https://downloads\.getmonero\.org/cli/monero-.*?\.(zip|tar\.bz2))\)')
      .allMatches(bodyHtml)
      .map((match) => match.group(1)!)
      .toList();
  return downloadLinks;
}

Map<String, String> extractReleaseHashes(String bodyHtml) {
  final hashLines = RegExp(r'(monero-.*?\.(zip|tar\.bz2)),\s*([a-fA-F0-9]{64})')
      .allMatches(bodyHtml)
      .map((match) => MapEntry(match.group(1)!, match.group(3)!))
      .toList();
  return Map.fromEntries(hashLines);
}

Map<String, String> extractMoneroHashes(String hashesText) {
  final hashLines = RegExp(r'([a-fA-F0-9]{64})\s+(monero-.*?\.(zip|tar\.bz2))')
      .allMatches(hashesText)
      .map((match) => MapEntry(match.group(2)!, match.group(1)!))
      .toList();
  return Map.fromEntries(hashLines);
}

String getDefaultDownloadLink(List<String> downloadLinks) {
  String platformPrefix;
  if (Platform.isWindows) {
    platformPrefix = 'monero-win';
  } else if (Platform.isMacOS) {
    platformPrefix = 'monero-mac';
  } else if (Platform.isLinux) {
    platformPrefix = 'monero-linux';
  } else {
    platformPrefix = 'monero';
  }

  String architectureSuffix;
  if (Platform.isWindows || Platform.isLinux) {
    architectureSuffix = Platform.version.contains('x64') ? 'x64' : 'x86';
  } else if (Platform.isMacOS) {
    architectureSuffix = Platform.version.contains('arm') ? 'armv8' : 'x64';
  } else {
    architectureSuffix = 'x64';
  }

  return downloadLinks.firstWhere(
      (link) =>
          link.contains(platformPrefix) && link.contains(architectureSuffix),
      orElse: () => downloadLinks.isNotEmpty ? downloadLinks[0] : '');
}

void main(List<String> arguments) async {
  if (arguments.contains('-h') || arguments.contains('--help')) {
    printHelp();
    return;
  }
  if (arguments.contains('-s') || arguments.contains('--settings')) {
    await editSettings();
    return;
  }

  bool autoMode = arguments.contains('-a') || arguments.contains('--auto');
  bool buildMode = arguments.contains('-b') || arguments.contains('--build');
  bool downloadMode = arguments.contains('-d') ||
      arguments.contains('--dl') ||
      arguments.contains('--download');
  String? customRemote;
  if (arguments.contains('-r') || arguments.contains('--remote')) {
    int index = arguments.indexOf('-r') != -1
        ? arguments.indexOf('-r')
        : arguments.indexOf('--remote');
    if (index + 1 < arguments.length) {
      customRemote = arguments[index + 1];
    }
  }

  final settingsFilePath = getSettingsFilePath();
  File settingsFile = File(settingsFilePath);
  Map<String, dynamic> settings = {};

  // Load or create settings.
  if (await settingsFile.exists()) {
    settings = jsonDecode(await settingsFile.readAsString());
  } else {
    settings = await setupSettings(settingsFile, autoMode, customRemote);
  }

  final moneroDir = settings['moneroDir'];
  Directory moneroDirectory = Directory(
      moneroDir); // TODO: Make this safe when the settings file is corrupted.
  String remoteUrl = customRemote ??
      settings['remote'] ??
      'https://api.github.com/repos/monero-project/monero/releases/latest';

  if (!await moneroDirectory.exists()) {
    await moneroDirectory.create(recursive: true);
    print('Created Monero directory: $moneroDir.');
  }

  if (((autoMode || buildMode) && !downloadMode) ||
      await promptYesNo(
          "Would you like to build Monero's latest release from source? [y/N]")) {
    await handleBuildMode(remoteUrl, moneroDir, autoMode);
  }

  if (autoMode ||
      downloadMode ||
      (await promptYesNo(
          'Would you like to check for the latest release? [y/N]'))) {
    await handleDownloadMode(
        moneroDir, autoMode, remoteUrl, customRemote, settingsFile);
  } else {
    print('Operation cancelled.');
  }
}
