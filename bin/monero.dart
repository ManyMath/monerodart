import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

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

  // Load or create settings
  if (await settingsFile.exists()) {
    settings = jsonDecode(await settingsFile.readAsString());
  } else {
    settings = await setupSettings(settingsFile, autoMode, customRemote);
  }

  final binariesPath = settings['binariesPath'];
  Directory binariesDir = Directory(binariesPath);
  String remoteUrl = customRemote ??
      settings['remote'] ??
      'https://api.github.com/repos/monero-project/monero/releases/latest';

  if (!await binariesDir.exists()) {
    if (autoMode) {
      await binariesDir.create(recursive: true);
      print('Created binaries directory: $binariesPath');
    } else {
      print(
          'The directory does not exist. Please create it or choose a different path.');
      return;
    }
  }

  if (autoMode ||
      (await promptYesNo(
          'Would you like to check for the latest release? [y/N]'))) {
    // Scan directory for Monero archives.  Used later to check if the latest
    // archive has already been downloaded.
    List<FileSystemEntity> files = await binariesDir.list().toList();
    List<FileSystemEntity> archives = files.where((file) {
      return file is File &&
          RegExp(r'monero-.*-v\d+\.\d+\.\d+\.\d+\.(zip|tar\.bz2)')
              .hasMatch(file.path);
    }).toList();

    if (archives.isEmpty) {
      print('No Monero archives found in $binariesPath.');
    } else {
      print('Found Monero archives:');
      for (var archive in archives) {
        print('- ${p.basename(archive.path)}');
      }
    }

    await downloadLatestRelease(binariesPath, archives, autoMode, remoteUrl);

    // Save the custom remote to settings if it was provided via the `-r` flag
    if (customRemote != null) {
      settings['remote'] = customRemote;
      await settingsFile.writeAsString(jsonEncode(settings));
    }
  } else {
    print('Operation cancelled.');
  }
}

Future<void> downloadLatestRelease(String binariesPath,
    List<FileSystemEntity> archives, bool autoMode, String remoteUrl) async {
  print('Using remote: $remoteUrl');
  try {
    final response = await http.get(Uri.parse(remoteUrl));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tagName = data['tag_name'];
      final bodyHtml = data['body'];

      print('Latest release found: $tagName');
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
            'You already have the latest release downloaded: ${existingArchive.path}');
        // Verify the file's hash for integrity
        String? expectedHash = releaseHashes[p.basename(existingArchive.path)];
        await verifyFileHash(existingArchive.path, expectedHash, autoMode);

        // Ask if the user wants to extract the archive, even if it already exists
        if (await promptYesNo(
            'The archive is already downloaded. Do you want to extract the archive? [y/N]')) {
          await extractArchive(
              existingArchive.path, binariesPath, defaultFileName);
        }
        return;
      }

      print('Downloading the default file: $defaultFileName...');
      await downloadFile(
          defaultFileName, binariesPath, releaseHashes, autoMode);
    } else {
      print(
          'Failed to fetch the latest release. HTTP status code: ${response.statusCode}');
    }
  } catch (e) {
    print('An error occurred while fetching the latest release: $e');
  }
}

Future<String> promptForCustomRemote() async {
  print('Please enter the custom remote URL:');
  String? customRemote = stdin.readLineSync();

  if (customRemote == null || customRemote.isEmpty) {
    print('No remote URL entered. Using the default remote.');
    return 'https://api.github.com/repos/monero-project/monero/releases/latest';
  }

  print('Validating remote URL: $customRemote');
  try {
    final response = await http.head(Uri.parse(customRemote));
    if (response.statusCode >= 200 && response.statusCode < 400) {
      print('Custom remote validated successfully.');
      return customRemote;
    } else {
      print('Invalid remote URL. HTTP status code: ${response.statusCode}');
      exit(1); // Terminate the program
    }
  } catch (e) {
    print('An error occurred while validating the remote URL: $e');
    exit(1); // Terminate the program
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
        stdout.write('\rProgress: ${progress.toStringAsFixed(2)}%');
      }
    },
    onDone: () async {
      File file = File(filePath);
      await file.writeAsBytes(bytes);
      print('\nDownload completed: $filePath');

      String? expectedHash = releaseHashes[fileName];
      await verifyFileHash(filePath, expectedHash, autoMode);

      // Ask if the user wants to extract the archive after verification
      if (await promptYesNo('Do you want to extract the archive? [y/N]')) {
        await extractArchive(filePath, binariesPath, fileName);
      }
    },
    onError: (e) {
      print('\nAn error occurred while downloading the file: $e');
    },
    cancelOnError: true,
  );
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
      print('Unsupported archive format: $archiveExtension');
      return;
    }
  } catch (e) {
    print('An error occurred while extracting the archive: $e');
  }
}

Future<void> _extractZip(String zipFilePath, String extractPath) async {
  print('Extracting zip archive: $zipFilePath...');
  // Use the `unzip` command with `-o` to overwrite files
  final result =
      await Process.run('unzip', ['-o', zipFilePath, '-d', extractPath]);

  if (result.exitCode == 0) {
    print('Extraction completed successfully.');
  } else {
    print('Failed to extract zip archive: ${result.stderr}');
  }
}

Future<void> _extractTarBz2(String tarFilePath, String extractPath) async {
  print('Extracting tar.bz2 archive: $tarFilePath...');
  // Use the `tar` command with `-xjf` to extract and `--overwrite` to overwrite files
  final result = await Process.run(
      'tar', ['-xjf', tarFilePath, '-C', extractPath, '--overwrite']);

  if (result.exitCode == 0) {
    print('Extraction completed successfully.');
  } else {
    print('Failed to extract tar.bz2 archive: ${result.stderr}');
  }
}

Future<void> verifyFileHash(
    String filePath, String? expectedHash, bool autoMode) async {
  if (expectedHash == null) {
    print('No expected hash found for $filePath. Skipping verification.');
    return;
  }

  String actualHash = await calculateFileHash(filePath);
  if (actualHash == expectedHash) {
    print('Hash verification succeeded for: $filePath');
  } else {
    print(
        'Hash mismatch for $filePath. Expected: $expectedHash, Actual: $actualHash');
    // if (!autoMode &&
    //     await promptYesNo(
    //         'Would you like to delete the corrupted file? [y/N]')) {
    //   await File(filePath).delete();
    //   print('Corrupted file deleted.');
    // }
  }
}

Future<String> calculateFileHash(String filePath) async {
  File file = File(filePath);
  var bytes = await file.readAsBytes();
  return sha256.convert(bytes).toString();
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

  String binariesPath;
  if (autoMode) {
    binariesPath = defaultPath;
    print('Using default binaries path: $binariesPath');
  } else {
    print(
        'Where should Monero binaries be stored? (Press Enter to use the default: $defaultPath)');
    String? inputPath = stdin.readLineSync();
    binariesPath =
        inputPath != null && inputPath.isNotEmpty ? inputPath : defaultPath;
  }

  String remoteUrl = customRemote ??
      'https://api.github.com/repos/monero-project/monero/releases/latest';

  Map<String, dynamic> settings = {
    'binariesPath': binariesPath,
    'remote': remoteUrl
  };
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
  print('Current binaries path: ${settings['binariesPath']}');
  print('Enter new path for binaries (or press Enter to keep current):');
  String? newPath = stdin.readLineSync();

  if (newPath != null && newPath.isNotEmpty) {
    settings['binariesPath'] = newPath;
    await settingsFile.writeAsString(jsonEncode(settings));
    print('Settings updated successfully.');
  } else {
    print('No changes made to settings.');
  }
}

String getSettingsFilePath() {
  if (Platform.isWindows) {
    return p.join(Platform.environment['APPDATA']!, 'monero', 'settings.json');
  } else {
    return p.join(
        Platform.environment['HOME']!, '.config', 'monero', 'settings.json');
  }
}

void printHelp() {
  print('''
Monero:
  An unofficial tool for downloading and managing official Monero binaries.

Usage:
  monero [options]
Options:
  -a, --auto                Skip prompts, use defaults.
  -h, --help                Show this help message.
  -r, --remote              Use the specified remote.
  -s, --settings            Edit the current settings.
Description:
  This tool checks and manages Monero binary releases.
Overview:
  - On first run, the tool will where to store Monero binaries (unless on auto).
  - Supports any Git remote URL for Monero releases.
  - Fetches the latest Monero release tag and binary release archive hashes.
  - Checks if any of the latest archives have already been downloaded.
  - Downloads the latest release archive if not already downloaded.
  - Compares the GitHub release hash with the hash from getmonero.org.
  - Verifies the integrity of the downloaded archive using the expected hash.
''');
}
