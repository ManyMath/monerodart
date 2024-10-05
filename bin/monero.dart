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

  final settingsFilePath = getSettingsFilePath();
  File settingsFile = File(settingsFilePath);
  Map<String, dynamic> settings = {};

  // Load or create settings
  if (await settingsFile.exists()) {
    settings = jsonDecode(await settingsFile.readAsString());
  } else {
    settings = await setupSettings(settingsFile);
  }

  final binariesPath = settings['binariesPath'];
  Directory binariesDir = Directory(binariesPath);

  if (!await binariesDir.exists()) {
    print(
        'The directory does not exist. Please create it or choose a different path.');
    return;
  }

  // Scan directory for Monero archives
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
    // TODO: Check hashes for integrity
  }

  print('\nWould you like to check for the latest release? [y/N]');
  String? response = stdin.readLineSync();
  if (response != null && response.toLowerCase() == 'y') {
    await downloadLatestRelease(binariesPath, archives);
  } else {
    print('Operation cancelled.');
  }
}

Future<void> downloadLatestRelease(
    String binariesPath, List<FileSystemEntity> archives) async {
  final List<String> gitRemotes = [
    'https://api.github.com/repos/monero-project/monero/releases/latest',
    'https://repo.getmonero.org/monero-project/monero'
  ];

  print('Select a remote to use for checking the latest release:');
  for (int i = 0; i < gitRemotes.length; i++) {
    print('  ${i + 1}. ${gitRemotes[i]}');
  }
  print('Enter the number of the remote to use (default is 1):');
  String? remoteChoice = stdin.readLineSync();
  int selectedRemoteIndex = (remoteChoice == null || remoteChoice.isEmpty)
      ? 0
      : int.tryParse(remoteChoice)! - 1;

  if (selectedRemoteIndex < 0 || selectedRemoteIndex >= gitRemotes.length) {
    print('Invalid selection. Using default remote.');
    selectedRemoteIndex = 0;
  }

  final githubApiUrl = gitRemotes[selectedRemoteIndex];

  try {
    final response = await http.get(Uri.parse(githubApiUrl));
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

      print('Available files:');
      for (var link in downloadLinks) {
        print('- $link');
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

        // Fetch and compare hash from getmonero.org
        final moneroHashesUrl =
            'https://www.getmonero.org/downloads/hashes.txt';
        final moneroHashesResponse = await http.get(Uri.parse(moneroHashesUrl));
        if (moneroHashesResponse.statusCode == 200) {
          final hashesText = moneroHashesResponse.body;
          final moneroHashes = extractMoneroHashes(hashesText);
          String? moneroOrgHash =
              moneroHashes[p.basename(existingArchive.path)];

          if (moneroOrgHash != null) {
            print('Hash from release description: $expectedHash');
            print('Hash from getmonero.org: $moneroOrgHash');

            if (expectedHash != moneroOrgHash) {
              throw Exception(
                  'Hash mismatch between release and getmonero.org for file: ${existingArchive.path}');
            }
          } else {
            throw Exception(
                'No hash found on getmonero.org for file: ${existingArchive.path}');
          }
        } else {
          throw Exception(
              'Failed to fetch hashes from getmonero.org. HTTP status code: ${moneroHashesResponse.statusCode}');
        }

        String actualHash = await calculateFileHash(existingArchive.path);
        if (actualHash != expectedHash) {
          throw Exception(
              'Hash mismatch for downloaded file: ${existingArchive.path}');
        } else {
          print('Hash verification succeeded for: ${existingArchive.path}');
        }
        return;
      }

      print('\nDefault file suggested: $defaultFileName');
      print('Enter the URL to download (press Enter to use the default):');
      String? selectedLink = stdin.readLineSync();
      selectedLink = (selectedLink == null || selectedLink.isEmpty)
          ? defaultFileName
          : selectedLink;

      if (downloadLinks.contains(selectedLink)) {
        final fileName = p.basename(Uri.parse(selectedLink).path);
        final filePath = p.join(binariesPath, fileName);
        print('Downloading $selectedLink to $filePath...');

        final request = await http.Client()
            .send(http.Request('GET', Uri.parse(selectedLink)));
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

            // Verify the downloaded file's hash
            String? expectedHash = releaseHashes[fileName];

            // Fetch and compare hash from getmonero.org
            final moneroHashesUrl =
                'https://www.getmonero.org/downloads/hashes.txt';
            final moneroHashesResponse =
                await http.get(Uri.parse(moneroHashesUrl));
            if (moneroHashesResponse.statusCode == 200) {
              final hashesText = moneroHashesResponse.body;
              final moneroHashes = extractMoneroHashes(hashesText);
              String? moneroOrgHash = moneroHashes[fileName];

              if (moneroOrgHash != null) {
                print('Hash from release description: $expectedHash');
                print('Hash from getmonero.org: $moneroOrgHash');

                if (expectedHash != moneroOrgHash) {
                  throw Exception(
                      'Hash mismatch between release and getmonero.org for file: $filePath');
                }
              } else {
                throw Exception(
                    'No hash found on getmonero.org for file: $filePath');
              }
            } else {
              throw Exception(
                  'Failed to fetch hashes from getmonero.org. HTTP status code: ${moneroHashesResponse.statusCode}');
            }

            String actualHash = await calculateFileHash(filePath);
            print('Hash from file: $actualHash');
            if (actualHash != expectedHash) {
              throw Exception('Hash mismatch for downloaded file: $filePath');
            } else {
              print('Hash verification succeeded for: $filePath');
            }
          },
          onError: (e) {
            print('\nAn error occurred while downloading the file: $e');
          },
          cancelOnError: true,
        );
      } else {
        print('Error: URL not found in the available download links.');
      }
    } else {
      print(
          'Failed to fetch the latest release. HTTP status code: ${response.statusCode}');
    }
  } catch (e) {
    print('An error occurred while fetching the latest release: $e');
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

Future<Map<String, dynamic>> setupSettings(File settingsFile) async {
  Directory parentDir = settingsFile.parent;
  if (!await parentDir.exists()) {
    await parentDir.create(recursive: true);
  }

  print('Welcome to the Monero CLI Manager!');
  String defaultPath = Platform.isWindows
      ? p.join(Platform.environment['APPDATA']!, 'Monero')
      : p.join(Platform.environment['HOME']!, 'Monero');

  print(
      'Where should Monero binaries be stored? (Press Enter to use the default: $defaultPath)');
  String? inputPath = stdin.readLineSync();
  String binariesPath =
      inputPath != null && inputPath.isNotEmpty ? inputPath : defaultPath;

  Map<String, dynamic> settings = {'binariesPath': binariesPath};
  await settingsFile.writeAsString(jsonEncode(settings));

  return settings;
}

Future<void> editSettings() async {
  final settingsFilePath = getSettingsFilePath();
  File settingsFile = File(settingsFilePath);

  if (!await settingsFile.exists()) {
    print('Settings file does not exist. Setting up new settings...');
    await setupSettings(settingsFile);
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
  print('Monero:');
  print(
      'An unofficial tool for downloading and managing official Monero binaries.');
  print('');
  print('Usage: monero_cli_manager [options]');
  print('Options:');
  print('  -h, --help                Show this help message');
  print('  -s, --settings            Edit the current settings');
  print('Description:');
  print('  This tool allows you to manage Monero binaries easily.');
  print(
      '  On first run, it will ask for a directory to store Monero binaries.');
  print(
      '  It can also download the latest Monero release and verify its integrity.');
  print(
      'The tool supports multiple Git remotes as sources for Monero releases.');
  print(
      '  You can select which remote to use when checking for the latest release.');
}
