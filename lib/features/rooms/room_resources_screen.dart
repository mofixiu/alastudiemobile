import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/ui.dart';
import '../app/app_controller.dart';
import '../roadmap/ai_tools_screen.dart';

class RoomResourcesScreen extends StatefulWidget {
  const RoomResourcesScreen({
    super.key,
    required this.roomId,
    this.roomTitle = 'Room library',
  });
  final String roomId;
  final String roomTitle;
  @override
  State<RoomResourcesScreen> createState() => _RoomResourcesScreenState();
}

class _RoomResourcesScreenState extends State<RoomResourcesScreen> {
  int _tab = 0;
  final Set<String> _selected = {};
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(
        context.read<AppController>().loadRoomResources(widget.roomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) {
      final materials = app.roomMaterials[widget.roomId] ?? const <JsonMap>[];
      final notes = app.roomNotes[widget.roomId] ?? const <JsonMap>[];
      return Scaffold(
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              BrandGlassSliverBar(
                leading: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const AppIcon(Icons.arrow_back_rounded, size: 18),
                  tooltip: 'Back',
                ),
                actions: [
                  IconButton(
                    tooltip: 'Shared whiteboard',
                    onPressed: () => Navigator.push(
                      context,
                      aLaStudieRoute(
                        context: context,
                        builder: (_) => RoomWhiteboardScreen(
                          roomId: widget.roomId,
                          roomTitle: widget.roomTitle,
                        ),
                      ),
                    ),
                    icon: const AppIcon(Icons.draw_outlined, size: 18),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(19, 13, 19, 28),
                sliver: SliverList.list(
                  children: [
                    Eyebrow(widget.roomTitle.toUpperCase()),
                    const SizedBox(height: 4),
                    Text(
                      'Room library',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Files and notes are visible only to current room members.',
                      style: TextStyle(color: context.appMuted),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _TabPill(
                            label: 'FILES',
                            selected: _tab == 0,
                            onTap: () => setState(() => _tab = 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TabPill(
                            label: 'NOTES',
                            selected: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_tab == 0) ...[
                      PrimaryAction(
                        label: _uploading
                            ? 'Adding file…'
                            : 'Share a file · up to 8 MB',
                        icon: Icons.attach_file_rounded,
                        onPressed: _uploading ? null : _upload,
                      ),
                      if (materials.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        OutlinedButton.icon(
                          onPressed: _selected.isEmpty
                              ? null
                              : () => Navigator.push(
                                  context,
                                  aLaStudieRoute(
                                    context: context,
                                    builder: (_) => AiToolsScreen(
                                      roomId: widget.roomId,
                                      materialIds: _selected.toList(),
                                    ),
                                  ),
                                ),
                          icon: const AppIcon(Icons.search_rounded, size: 16),
                          label: Text(
                            'Search ${_selected.length} selected file${_selected.length == 1 ? '' : 's'} with AI',
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (materials.isEmpty)
                        const EmptyNotice(
                          title: 'A room library, built together',
                          body:
                              'Share lecture PDFs, plain text, Markdown, CSV or DOCX files with your study group.',
                          icon: Icons.folder_open_outlined,
                        ),
                      for (final file in materials)
                        _MaterialRow(
                          roomId: widget.roomId,
                          file: file,
                          selected: _selected.contains('${file['id']}'),
                          onSelected: (value) => setState(
                            () => value
                                ? _selected.add('${file['id']}')
                                : _selected.remove('${file['id']}'),
                          ),
                        ),
                    ] else ...[
                      PrimaryAction(
                        label: 'Start a shared note',
                        icon: Icons.note_add_outlined,
                        onPressed: () => _editNote(context, app),
                      ),
                      const SizedBox(height: 10),
                      if (notes.isEmpty)
                        const EmptyNotice(
                          title: 'Put the group’s thinking in one place',
                          body:
                              'Members can create and edit shared notes. Saves use a version check so an older edit cannot overwrite a newer one.',
                          icon: Icons.notes_rounded,
                        ),
                      for (final note in notes)
                        _NoteRow(
                          note: note,
                          onTap: () => _editNote(context, app, note),
                        ),
                    ],
                    const SizedBox(height: 14),
                    SoftPanel(
                      color: context.appBrandPanel,
                      child: Row(
                        children: [
                          const AppIcon(Icons.draw_outlined, size: 18),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Eyebrow('SHARED CANVAS'),
                                Text(
                                  'Sketch the idea together',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              aLaStudieRoute(
                                context: context,
                                builder: (_) => RoomWhiteboardScreen(
                                  roomId: widget.roomId,
                                  roomTitle: widget.roomTitle,
                                ),
                              ),
                            ),
                            child: const Text('Open'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _upload() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'txt', 'md', 'csv', 'docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final picked = result.files.single;
      final bytes =
          picked.bytes ??
          (picked.path == null ? null : await File(picked.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty)
        throw StateError('Could not read that file. Choose another one.');
      if (bytes.length > 8 * 1024 * 1024)
        throw StateError('Room files are limited to 8 MB.');
      final extension = path.extension(picked.name).toLowerCase();
      final contentType = switch (extension) {
        '.pdf' => 'application/pdf',
        '.txt' => 'text/plain',
        '.md' => 'text/markdown',
        '.csv' => 'text/csv',
        '.docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        _ => throw StateError('Choose a PDF, TXT, Markdown, CSV or DOCX file.'),
      };
      await context.read<AppController>().shareRoomMaterial(
        widget.roomId,
        title: path.basenameWithoutExtension(picked.name),
        fileName: picked.name,
        contentType: contentType,
        bytes: bytes,
      );
      if (mounted)
        showAppMessage(
          context,
          context.read<AppController>().errorMessage ??
              'File shared with room members.',
        );
    } catch (error) {
      if (mounted) showAppMessage(context, '$error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editNote(
    BuildContext context,
    AppController app, [
    JsonMap? note,
  ]) async {
    final title = TextEditingController(text: '${note?['title'] ?? ''}');
    final body = TextEditingController(text: '${note?['body'] ?? ''}');
    final save = await showPremiumBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 8, 19, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(
                note == null
                    ? 'SHARED WITH ROOM MEMBERS'
                    : 'VERSION ${note['version']} · ${note['author_name'] ?? 'MEMBER'}',
              ),
              const SizedBox(height: 6),
              Text(
                note == null ? 'Start a note' : 'Edit room note',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              TextField(
                controller: title,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Note title'),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: body,
                minLines: 5,
                maxLines: 10,
                maxLength: 20000,
                decoration: const InputDecoration(
                  hintText: 'Capture the group’s useful notes…',
                ),
              ),
              const SizedBox(height: 8),
              PrimaryAction(
                label: 'Save note',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
              if (note != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Delete note'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    try {
      if (save == true) {
        if (note == null)
          await app.createRoomNote(
            widget.roomId,
            title.text.trim(),
            body.text.trim(),
          );
        else
          await app.saveRoomNote(
            widget.roomId,
            note,
            title.text.trim(),
            body.text.trim(),
          );
      } else if (save == false && note != null) {
        await app.deleteRoomNote(widget.roomId, '${note['id']}');
      }
      if (save != null)
        showAppMessage(
          context,
          app.errorMessage ?? (save ? 'Note saved.' : 'Note removed.'),
        );
    } catch (error) {
      showAppMessage(context, '$error');
    }
    title.dispose();
    body.dispose();
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.roomId,
    required this.file,
    required this.selected,
    required this.onSelected,
  });
  final String roomId;
  final JsonMap file;
  final bool selected;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final id = '${file['id']}';
    final canDelete = file['uploader_id'] == app.currentUser?.id || app.isHost;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftPanel(
        color: context.appSurface,
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => onSelected(!selected),
              child: AppIcon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 17,
                color: selected ? AppColors.red : context.appMuted,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${file['title']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${file['file_name']} · ${_sizeLabel(int.tryParse('${file['byte_size']}') ?? 0)} · @${file['uploader_name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Download and open',
              onPressed: () =>
                  _download(context, roomId, id, '${file['file_name']}'),
              icon: const AppIcon(Icons.download_rounded, size: 17),
            ),
            if (file['ai_indexed'] == true)
              IconButton(
                tooltip: 'Remove your private AI index',
                onPressed: () async {
                  await app.removeAiIndex(id);
                  if (context.mounted)
                    showAppMessage(context, 'Your private index was removed.');
                },
                icon: const AppIcon(Icons.delete_sweep_outlined, size: 17),
              ),
            if (canDelete)
              IconButton(
                tooltip: 'Remove file',
                onPressed: () => app.deleteRoomMaterial(roomId, id),
                icon: const AppIcon(Icons.close_rounded, size: 15),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _download(
  BuildContext context,
  String roomId,
  String id,
  String name,
) async {
  try {
    final bytes = await context.read<AppController>().downloadRoomMaterial(
      roomId,
      id,
    );
    final directory = await getTemporaryDirectory();
    final file = File(
      path.join(directory.path, name.replaceAll(RegExp(r'[/\\]'), '_')),
    );
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  } catch (error) {
    if (context.mounted) showAppMessage(context, '$error');
  }
}

String _sizeLabel(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).ceil()} KB';

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.onTap});
  final JsonMap note;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(
      onTap: onTap,
      child: SoftPanel(
        color: context.appSurface,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${note['title']}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const AppIcon(
                  Icons.edit_outlined,
                  size: 15,
                  color: AppColors.red,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${note['body']}',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.appMuted, height: 1.35),
            ),
            const SizedBox(height: 5),
            Text(
              'Edited by @${note['author_name'] ?? 'member'} · v${note['version']}',
              style: TextStyle(color: context.appMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? context.appBrandInk : context.appSurface,
        border: Border.all(color: context.appLine),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : context.appInk,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .7,
        ),
      ),
    ),
  );
}

class RoomWhiteboardScreen extends StatefulWidget {
  const RoomWhiteboardScreen({
    super.key,
    required this.roomId,
    this.roomTitle = 'Study room',
  });
  final String roomId;
  final String roomTitle;
  @override
  State<RoomWhiteboardScreen> createState() => _RoomWhiteboardScreenState();
}

class _RoomWhiteboardScreenState extends State<RoomWhiteboardScreen> {
  late final AppController _app;
  List<JsonMap> _strokes = [];
  int _version = 0;
  bool _drawing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppController>();
    _app.addListener(_onRemoteChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  @override
  void dispose() {
    _app.removeListener(_onRemoteChange);
    super.dispose();
  }

  Future<void> _load() async {
    await _app.loadRoomResources(widget.roomId);
    if (!mounted) return;
    final board = _app.roomWhiteboards[widget.roomId] ?? {};
    setState(() {
      _strokes = (board['strokes'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      _version = int.tryParse('${board['version'] ?? 0}') ?? 0;
    });
  }

  void _onRemoteChange() {
    final board = _app.roomWhiteboards[widget.roomId];
    if (!mounted || _drawing || board == null) return;
    final next = int.tryParse('${board['version'] ?? 0}') ?? 0;
    if (next == _version) return;
    setState(() {
      _strokes = (board['strokes'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      _version = next;
    });
  }

  void _start(Offset point, Size size) {
    _drawing = true;
    setState(
      () => _strokes.add({
        'color': '003F52',
        'width': 0.006,
        'points': [
          {'x': point.dx / size.width, 'y': point.dy / size.height},
        ],
      }),
    );
  }

  void _move(Offset point, Size size) {
    if (!_drawing || _strokes.isEmpty) return;
    setState(() {
      final current = _strokes.last;
      final points = (current['points'] as List).cast<Map<String, dynamic>>();
      if (points.length >= 250) return;
      points.add({
        'x': (point.dx / size.width).clamp(0, 1),
        'y': (point.dy / size.height).clamp(0, 1),
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      top: false,
      child: CustomScrollView(
        slivers: [
          BrandGlassSliverBar(
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const AppIcon(Icons.arrow_back_rounded, size: 18),
              tooltip: 'Back',
            ),
            actions: [
              IconButton(
                tooltip: 'Reload shared marks',
                onPressed: _load,
                icon: const AppIcon(Icons.sync_rounded, size: 17),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            sliver: SliverList.list(
              children: [
                Eyebrow(widget.roomTitle.toUpperCase()),
                Text(
                  'Whiteboard',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 5),
                Text(
                  'Draw together in strokes. Members’ updates sync through the room.',
                  style: TextStyle(color: context.appMuted),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 430,
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    border: Border.all(color: context.appLine),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) =>
                          _start(details.localPosition, constraints.biggest),
                      onPanUpdate: (details) =>
                          _move(details.localPosition, constraints.biggest),
                      onPanEnd: (_) {
                        _drawing = false;
                      },
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _WhiteboardPainter(_strokes),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Version $_version',
                      style: TextStyle(color: context.appMuted, fontSize: 11),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _strokes.clear()),
                      icon: const AppIcon(
                        Icons.delete_outline_rounded,
                        size: 15,
                      ),
                      label: const Text('Clear'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: AppIcon(
                        _saving
                            ? Icons.hourglass_top_rounded
                            : Icons.check_rounded,
                        size: 15,
                      ),
                      label: Text(_saving ? 'Saving' : 'Save marks'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'If someone saved a newer board before your change, reload it and redraw to keep both edits.',
                  style: TextStyle(color: context.appMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _app.saveRoomWhiteboard(widget.roomId, _strokes, _version);
      final board = _app.roomWhiteboards[widget.roomId] ?? {};
      if (mounted)
        setState(
          () => _version =
              int.tryParse('${board['version'] ?? _version}') ?? _version,
        );
    } catch (error) {
      if (mounted) showAppMessage(context, '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _WhiteboardPainter extends CustomPainter {
  _WhiteboardPainter(this.strokes);
  final List<JsonMap> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xfff9f6ef);
    canvas.drawRect(Offset.zero & size, background);
    final grid = Paint()
      ..color = const Color(0x10003f52)
      ..strokeWidth = 1;
    for (var x = 24.0; x < size.width; x += 24)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (var y = 24.0; y < size.height; y += 24)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    for (final stroke in strokes) {
      final points = (stroke['points'] as List? ?? [])
          .whereType<Map>()
          .toList();
      if (points.isEmpty) continue;
      final colorValue =
          int.tryParse('ff${stroke['color'] ?? '003F52'}', radix: 16) ??
          0xff003f52;
      final paint = Paint()
        ..color = Color(colorValue)
        ..strokeWidth =
            (double.tryParse('${stroke['width'] ?? .006}') ?? .006) * size.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (points.length == 1) {
        final point = points.first;
        canvas.drawCircle(
          Offset(
            (point['x'] as num).toDouble() * size.width,
            (point['y'] as num).toDouble() * size.height,
          ),
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        final path = Path();
        for (var i = 0; i < points.length; i++) {
          final point = points[i];
          final offset = Offset(
            (point['x'] as num).toDouble() * size.width,
            (point['y'] as num).toDouble() * size.height,
          );
          if (i == 0)
            path.moveTo(offset.dx, offset.dy);
          else
            path.lineTo(offset.dx, offset.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_WhiteboardPainter oldDelegate) => true;
}
