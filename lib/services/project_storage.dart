import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/show_models.dart';
import 'hotkey_mapper.dart';

/// Manages self-contained `StageCommander_Data` workspaces, atomic project saves,
/// deduplicated media imports, legacy Beta 8 migration, and `.stagepack.zip` archives.
class ProjectStorage {
  ProjectStorage({Directory? initialWorkspaceDir})
    : _overrideDir = initialWorkspaceDir,
      _workspaceDir = initialWorkspaceDir ?? Directory.current;

  final Directory? _overrideDir;
  Directory _workspaceDir;
  Future<void> _pendingSave = Future<void>.value();
  int _idSeq = 0;

  Directory get workspaceDir => _workspaceDir;
  Directory get mediaDir => Directory(p.join(_workspaceDir.path, 'Media'));
  File get projectFile => File(p.join(_workspaceDir.path, 'project.json'));

  /// Generates collision-free local IDs for scenes and cues.
  String nextId([String prefix = 'id']) {
    _idSeq += 1;
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '${prefix}_${micros}_$_idSeq';
  }

  /// Resolves the initial workspace directory cleanly across Windows, macOS, and Linux.
  ///
  /// Uses portable `<exeDir>/StageCommander_Data` if it already exists or `<exeDir>`
  /// is user-writable (portable USB / stage booth mode). Otherwise falls back to the
  /// OS user Documents directory (`~/Documents/StageCommander_Data`) and remembers the
  /// most recently selected custom workspace path.
  Future<void> initialize() async {
    if (_overrideDir != null) {
      _workspaceDir = _overrideDir;
      await _ensureWorkspaceFolders();
      return;
    }

    final savedCustom = await _readLastWorkspacePref();
    if (savedCustom != null && await savedCustom.exists()) {
      _workspaceDir = savedCustom;
      await _ensureWorkspaceFolders();
      return;
    }

    final portable = await _detectWritablePortableDir();
    if (portable != null) {
      _workspaceDir = portable;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      _workspaceDir = Directory(p.join(docs.path, 'StageCommander_Data'));
    }

    await _ensureWorkspaceFolders();
  }

  /// Switches the active show workspace to [newWorkspaceDir] and remembers it.
  Future<void> switchWorkspace(Directory newWorkspaceDir) async {
    _workspaceDir = newWorkspaceDir;
    await _ensureWorkspaceFolders();
    await _writeLastWorkspacePref(newWorkspaceDir);
  }

  Future<void> _ensureWorkspaceFolders() async {
    if (!await _workspaceDir.exists()) {
      await _workspaceDir.create(recursive: true);
    }
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
  }

  Future<Directory?> _detectWritablePortableDir() async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final lower = exeDir.path.toLowerCase();
      // Never write inside system-managed read-only bundles.
      if (lower.contains('.app/contents/') ||
          lower.startsWith('/usr/') ||
          lower.startsWith('/opt/') ||
          lower.contains(r'\program files')) {
        return null;
      }
      final candidate = Directory(p.join(exeDir.path, 'StageCommander_Data'));
      if (await candidate.exists()) {
        if (await _isDirWritable(candidate)) return candidate;
        return null;
      }
      if (await _isDirWritable(exeDir)) {
        return candidate;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<bool> _isDirWritable(Directory dir) async {
    try {
      final probe = File(
        p.join(dir.path, '.sc_probe_${DateTime.now().microsecondsSinceEpoch}'),
      );
      await probe.writeAsString('ok');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<File?> _prefsFile() async {
    try {
      final support = await getApplicationSupportDirectory();
      if (!await support.exists()) {
        await support.create(recursive: true);
      }
      return File(p.join(support.path, 'stage_commander_prefs.json'));
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _readLastWorkspacePref() async {
    final file = await _prefsFile();
    if (file == null || !await file.exists()) return null;
    try {
      final map = jsonDecode(await file.readAsString());
      if (map is Map && map['workspace_path'] is String) {
        final pathStr = (map['workspace_path'] as String).trim();
        if (pathStr.isNotEmpty) return Directory(pathStr);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeLastWorkspacePref(Directory dir) async {
    final file = await _prefsFile();
    if (file == null) return;
    try {
      await file.writeAsString(
        jsonEncode({'workspace_path': dir.path}),
        flush: true,
      );
    } catch (_) {}
  }

  /// Copies an external audio file into `Media/` using content-hashed deduplication,
  /// returning a portable relative path like `Media/a1b2c3d4_boom.wav`.
  Future<String> importAudioFile(String sourcePath) async {
    await _ensureWorkspaceFolders();
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;

    final normalizedSource = p.normalize(source.absolute.path);
    final normalizedMedia = p.normalize(mediaDir.absolute.path);
    if (p.isWithin(normalizedMedia, normalizedSource)) {
      return p
          .relative(normalizedSource, from: _workspaceDir.path)
          .replaceAll('\\', '/');
    }

    final hash = await _shortSha256(source);
    final ext = p.extension(sourcePath).toLowerCase();
    final rawBase = p.basenameWithoutExtension(sourcePath);
    final safeBase = rawBase
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    final cleanBase = safeBase.isEmpty ? 'audio' : safeBase;
    final targetName = '${hash}_$cleanBase$ext';
    final targetFile = File(p.join(mediaDir.path, targetName));

    if (!await targetFile.exists()) {
      await source.copy(targetFile.path);
    }

    return 'Media/$targetName';
  }

  Future<String> _shortSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().substring(0, 8);
  }

  /// Resolves a stored cue path (portable relative `Media/...` or legacy absolute)
  /// into an existing local file path on the current OS.
  String resolveCuePath(CueItem cue) {
    final raw = cue.filePath.trim();
    if (raw.isEmpty) return '';

    final normalized = raw
        .replaceAll('\\', Platform.pathSeparator)
        .replaceAll('/', Platform.pathSeparator);
    if (!p.isAbsolute(normalized) && !RegExp(r'^[A-Za-z]:').hasMatch(raw)) {
      return p.normalize(p.join(_workspaceDir.path, normalized));
    }

    final direct = File(normalized);
    if (direct.existsSync()) return direct.path;

    // Fallback: if a legacy Beta 8 absolute path moved machines, check Media/<basename>.
    final mediaFallback = File(p.join(mediaDir.path, p.basename(normalized)));
    if (mediaFallback.existsSync()) return mediaFallback.path;

    return normalized;
  }

  /// Writes complete snapshots in order and replaces the old file on success.
  Future<void> saveProject(ShowProject project) {
    final destination = projectFile;
    final save = _pendingSave.then((_) async {
      await destination.parent.create(recursive: true);
      final tempDir = await destination.parent.createTemp('.sc-save-');
      try {
        final tempFile = File(p.join(tempDir.path, 'project.json'));
        await tempFile.writeAsString(project.toPrettyJson(), flush: true);
        await tempFile.rename(destination.path);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
    _pendingSave = save.then<void>((_) {}, onError: (Object _) {});
    return save;
  }

  /// Loads `project.json` from the active workspace, migrating legacy Beta 8 data
  /// automatically if detected.
  Future<ShowProject> loadProject() async {
    await _ensureWorkspaceFolders();
    if (!await projectFile.exists()) {
      return ShowProject(
        scenes: [SceneAct(id: nextId('scene'), name: '第一幕')],
      );
    }
    return loadProjectFromFile(projectFile);
  }

  /// Reads and normalizes a standalone `project.json` file (including legacy Beta 8).
  Future<ShowProject> loadProjectFromFile(
    File file, {
    bool copyExternalMedia = false,
  }) async {
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      final parsed = ShowProject.fromDynamicJson(
        decoded,
        nextId: () => nextId('item'),
        parseLegacyHotkey: HotkeyMapper.parseLegacyString,
      );

      var project = parsed.project;
      if (parsed.migratedFromLegacy || copyExternalMedia) {
        final updatedScenes = <SceneAct>[];
        for (final scene in project.scenes) {
          final updatedCues = <CueItem>[];
          for (final cue in scene.cues) {
            var newPath = cue.filePath;
            if (copyExternalMedia && newPath.isNotEmpty) {
              final candidate = _resolveAgainstBase(newPath, file.parent);
              if (File(candidate).existsSync()) {
                newPath = await importAudioFile(candidate);
              }
            } else if (parsed.migratedFromLegacy && newPath.isNotEmpty) {
              final resolved = resolveCuePath(cue);
              if (p.isWithin(
                p.normalize(_workspaceDir.absolute.path),
                p.normalize(File(resolved).absolute.path),
              )) {
                newPath = p
                    .relative(resolved, from: _workspaceDir.path)
                    .replaceAll('\\', '/');
              }
            }
            updatedCues.add(cue.copyWith(filePath: newPath));
          }
          updatedScenes.add(scene.copyWith(cues: updatedCues));
        }
        project = project.copyWith(scenes: updatedScenes);

        if (file.path == projectFile.path && parsed.migratedFromLegacy) {
          final backup = File('${projectFile.path}.beta8.bak');
          if (!await backup.exists()) {
            await file.copy(backup.path);
          }
          await saveProject(project);
        }
      }
      return project;
    } catch (_) {
      return ShowProject(
        scenes: [SceneAct(id: nextId('scene'), name: '第一幕')],
      );
    }
  }

  String _resolveAgainstBase(String raw, Directory baseDir) {
    final norm = raw
        .replaceAll('\\', Platform.pathSeparator)
        .replaceAll('/', Platform.pathSeparator);
    if (p.isAbsolute(norm) || RegExp(r'^[A-Za-z]:').hasMatch(raw)) {
      if (File(norm).existsSync()) return norm;
      final siblingMedia = File(
        p.join(baseDir.path, 'Media', p.basename(norm)),
      );
      if (siblingMedia.existsSync()) return siblingMedia.path;
      return norm;
    }
    return p.normalize(p.join(baseDir.path, norm));
  }

  /// Exports the entire active show workspace (`project.json` + `Media/`) to a `.zip` bundle.
  Future<void> exportShowBundle(
    ShowProject project,
    String destinationZipPath,
  ) async {
    await saveProject(project);
    final encoder = ZipFileEncoder();
    await encoder.zipDirectory(_workspaceDir, filename: destinationZipPath);
  }

  /// Imports a `.zip` show bundle into [targetWorkspace] (or the current workspace).
  Future<ShowProject> importShowBundle(
    String zipPath, {
    Directory? targetWorkspace,
  }) async {
    if (targetWorkspace != null) {
      await switchWorkspace(targetWorkspace);
    }
    await _ensureWorkspaceFolders();
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    await extractArchiveToDisk(archive, _workspaceDir.path);
    return loadProject();
  }
}
