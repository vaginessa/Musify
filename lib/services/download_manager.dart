import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:musify/API/musify.dart';
import 'package:musify/screens/more_page.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/download_button.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> downloadSong(BuildContext context, dynamic song) async {
  try {
    if (!await checkDownloadDirectory(context)) {
      return;
    }

    final invalidCharacters = RegExp(r'[\\/*?:"<>|]');

    final filename = song['more_info']['singers'] +
        ' - ' +
        song['title'].replaceAll(invalidCharacters, '').replaceAll(' ', '');
    final filepath =
        '$downloadDirectory/$filename.${prefferedFileExtension.value}';

    lastDownloadedSongIdListener.value = song['ytid'];

    await downloadFileFromYT(
      context,
      filename,
      filepath,
      downloadDirectory!,
      song,
    );
  } catch (e) {
    debugPrint('Error while downloading song: $e');
    showToast(
      AppLocalizations.of(context)!.downloadFailed,
    );
  }
}

Future<void> downloadFileFromYT(
  BuildContext context,
  String filename,
  String filepath,
  String dlPath,
  dynamic song,
) async {
  try {
    final manifest =
        await yt.videos.streamsClient.getManifest(song['ytid'].toString());
    final audio = manifest.audioOnly.withHighestBitrate();
    final audioStream = yt.videos.streamsClient.get(audio);
    final file = File(filepath);

    if (file.existsSync()) {
      await file.delete();
    }

    final output = file.openWrite(mode: FileMode.writeOnlyAppend);

    final len = audio.size.totalBytes;
    var count = 0;
    var prevProgress = 0;

    showToast(
      AppLocalizations.of(context)!.downloadStarted,
    );

    await for (final data in audioStream) {
      count += data.length;

      final progress = ((count / len) * 100).ceil();
      if (progress - prevProgress >= 1) {
        prevProgress = progress;
        downloadListenerNotifier.value = progress;
      }

      output.add(data);
    }
    downloadListenerNotifier.value = 0;

    await output.close();

    showToast(
      AppLocalizations.of(context)!.downloadCompleted,
    );
  } catch (e) {
    debugPrint('Error while downloading song: $e');
    showToast(
      AppLocalizations.of(context)!.downloadFailed,
    );
  }
}

Future<void> checkNecessaryPermissions(BuildContext context) async {
  try {
    final statuses = await [
      Permission.storage,
      Permission.accessMediaLocation,
      Permission.audio,
      Permission.manageExternalStorage,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);
    if (allGranted) {
      showToast(AppLocalizations.of(context)!.allPermsAreGranted);
    } else {
      showToast(AppLocalizations.of(context)!.somePermsAreDenied);
    }
  } catch (e) {
    showToast(
      '${AppLocalizations.of(context)!.errorWhileRequestingPerms} + $e',
    );
  }
}

Future<bool> checkDownloadDirectory(BuildContext context) async {
  downloadDirectory ??= await FilePicker.platform.getDirectoryPath();

  if (downloadDirectory == null) {
    showToast('${AppLocalizations.of(context)!.chooseDownloadDir}!');
    return false;
  }

  addOrUpdateData('settings', 'downloadPath', downloadDirectory);

  return true;
}
