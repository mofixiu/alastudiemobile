import 'dart:async';
import 'dart:convert';
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

class AiToolsScreen extends StatefulWidget {
  const AiToolsScreen({super.key, this.roomId, this.materialIds = const []});
  final String? roomId;
  final List<String> materialIds;
  @override
  State<AiToolsScreen> createState() => _AiToolsScreenState();
}

class _AiToolsScreenState extends State<AiToolsScreen> {
  final _prompt = TextEditingController();
  String _operation = 'assistant';
  bool _includePlan = false;
  bool _working = false;
  bool _uploading = false;
  String _answer = '';
  String? _error;
  List<JsonMap> _draftBlocks = [];
  final Set<int> _selectedDrafts = {};
  final Set<String> _selectedPersonalDocuments = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          unawaited(context.read<AppController>().loadPersonalStudyDocuments()),
    );
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) => Scaffold(
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
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              sliver: SliverList.list(
                children: [
                  const Eyebrow('A STUDY TOOL, WHEN YOU ASK'),
                  const SizedBox(height: 4),
                  Text(
                    'Think it through.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Submitting sends your request to Google AI. Your private plan is included only when you choose it; room chat and other members’ private data are never included.',
                    style: TextStyle(color: context.appMuted, height: 1.4),
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _ToolChip(
                        label: 'ASK',
                        selected: _operation == 'assistant',
                        onTap: () => setState(() => _operation = 'assistant'),
                      ),
                      _ToolChip(
                        label: 'QUIZ',
                        selected: _operation == 'quiz',
                        onTap: () => setState(() => _operation = 'quiz'),
                      ),
                      _ToolChip(
                        label: 'PLAN DRAFT',
                        selected: _operation == 'study_plan',
                        onTap: () => setState(() => _operation = 'study_plan'),
                      ),
                      if (widget.materialIds.isNotEmpty ||
                          _selectedPersonalDocuments.isNotEmpty)
                        _ToolChip(
                          label: 'SEARCH FILES',
                          selected: _operation == 'semantic_search',
                          onTap: () =>
                              setState(() => _operation = 'semantic_search'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _personalStudyFiles(context, app),
                  const SizedBox(height: 10),
                  SoftPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(
                          widget.materialIds.isEmpty &&
                                  _selectedPersonalDocuments.isEmpty
                              ? 'YOUR QUESTION'
                              : 'SELECTED FILES · ${widget.materialIds.length + _selectedPersonalDocuments.length}',
                        ),
                        const SizedBox(height: 7),
                        TextField(
                          controller: _prompt,
                          minLines: 3,
                          maxLines: 7,
                          maxLength: 12000,
                          decoration: InputDecoration(
                            hintText: _hint,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Submitting sends your prompt and selected files to Google AI. Selected PDFs are indexed privately and the stored copy is removed when you delete them.',
                          style: TextStyle(
                            color: context.appMuted,
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _SwitchRow(
                          label:
                              'Include my private weekly plan in this request',
                          value: _includePlan,
                          onChanged: (value) =>
                              setState(() => _includePlan = value),
                        ),
                        const SizedBox(height: 8),
                        PrimaryAction(
                          label: _working ? 'Working…' : _buttonLabel,
                          icon: Icons.arrow_upward_rounded,
                          onPressed: _working ? null : () => _submit(app),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 9),
                          InlineErrorNotice(_error!),
                        ],
                      ],
                    ),
                  ),
                  if (_answer.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Eyebrow('YOUR RESULT'),
                    const SizedBox(height: 7),
                    SoftPanel(
                      color: context.appSurface,
                      child: SelectableText(
                        _cleanAnswer(_answer),
                        style: const TextStyle(height: 1.45),
                      ),
                    ),
                    if (_draftBlocks.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      const SectionHeading('Review this draft plan'),
                      const SizedBox(height: 6),
                      for (var i = 0; i < _draftBlocks.length; i++)
                        _DraftBlockRow(
                          block: _draftBlocks[i],
                          selected: _selectedDrafts.contains(i),
                          onChanged: (value) => setState(
                            () => value
                                ? _selectedDrafts.add(i)
                                : _selectedDrafts.remove(i),
                          ),
                        ),
                      const SizedBox(height: 8),
                      PrimaryAction(
                        label: 'Add selected blocks to my calendar',
                        icon: Icons.event_available_rounded,
                        onPressed: _selectedDrafts.isEmpty
                            ? null
                            : () => _applyPlan(app),
                      ),
                    ],
                  ],
                  const SizedBox(height: 13),
                  Text(
                    'AI can make mistakes. Check important details against your source material.',
                    style: TextStyle(color: context.appMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String get _hint => switch (_operation) {
    'quiz' =>
      'Tell me what topic to quiz you on, and how challenging it should be.',
    'study_plan' =>
      'Describe the topics, deadlines, and weekly time you want to plan around.',
    'semantic_search' =>
      'What would you like to find in the selected room files?',
    _ => 'Ask a question about a topic you are studying…',
  };
  String get _buttonLabel => switch (_operation) {
    'quiz' => 'Make a practice quiz',
    'study_plan' => 'Draft a study plan',
    'semantic_search' => 'Search selected files',
    _ => 'Ask aLaStudie',
  };

  Future<void> _submit(AppController app) async {
    if (_prompt.text.trim().isEmpty) {
      setState(() => _error = 'Write a question or study request first.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
      _draftBlocks = [];
      _selectedDrafts.clear();
    });
    try {
      final result = await app.askAi(
        operation: _operation,
        prompt: _prompt.text.trim(),
        roomId: widget.roomId,
        materialIds: widget.materialIds,
        studyDocumentIds: _selectedPersonalDocuments.toList(),
        includePlan: _includePlan,
      );
      if (!mounted) return;
      setState(() => _answer = '${result['answer'] ?? ''}');
      if (_operation == 'study_plan') {
        _draftBlocks = _decodeDraftBlocks(_answer);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _personalStudyFiles(BuildContext context, AppController app) {
    final documents = app.personalStudyDocuments;
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Eyebrow('MY PRIVATE STUDY FILES')),
              GestureDetector(
                onTap: _uploading ? null : () => _uploadPdf(app),
                child: Text(
                  _uploading ? 'ADDING…' : 'ADD PDF',
                  style: TextStyle(
                    color: _uploading ? context.appMuted : AppColors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Keep PDFs for yourself. Select a file to include it with your next AI request, or open it to study.',
            style: TextStyle(
              color: context.appMuted,
              fontSize: 10,
              height: 1.35,
            ),
          ),
          if (documents.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No PDFs yet. Add a file up to 8 MB.',
              style: TextStyle(color: context.appMuted, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 6),
            for (final document in documents)
              _PersonalStudyFileRow(
                document: document,
                selected: _selectedPersonalDocuments.contains(
                  '${document['id']}',
                ),
                onSelect: () {
                  final id = '${document['id']}';
                  if (_selectedPersonalDocuments.contains(id)) {
                    setState(() {
                      _selectedPersonalDocuments.remove(id);
                      if (_selectedPersonalDocuments.isEmpty &&
                          widget.materialIds.isEmpty &&
                          _operation == 'semantic_search') {
                        _operation = 'assistant';
                      }
                    });
                  } else if (widget.materialIds.length +
                          _selectedPersonalDocuments.length >=
                      3) {
                    showAppMessage(
                      context,
                      'Use up to three files per request.',
                    );
                  } else {
                    setState(() => _selectedPersonalDocuments.add(id));
                  }
                },
                onOpen: () => _openPdf(app, document),
                onDelete: () => _deletePdf(app, document),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _uploadPdf(AppController app) async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final picked = result.files.single;
      final bytes =
          picked.bytes ??
          (picked.path == null ? null : await File(picked.path!).readAsBytes());
      if (bytes == null ||
          bytes.isEmpty ||
          !picked.name.toLowerCase().endsWith('.pdf')) {
        throw StateError('Choose a readable PDF file.');
      }
      if (bytes.length > 8 * 1024 * 1024) {
        throw StateError('PDFs are limited to 8 MB.');
      }
      await app.uploadPersonalStudyDocument(
        fileName: path.basename(picked.name),
        bytes: bytes,
      );
      if (!mounted) return;
      if (app.errorMessage != null) {
        showAppMessage(context, app.errorMessage!);
      } else {
        showAppMessage(context, 'PDF added to your private study files.');
      }
    } catch (error) {
      if (mounted) showAppMessage(context, '$error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openPdf(AppController app, JsonMap document) async {
    try {
      final bytes = await app.downloadPersonalStudyDocument(
        '${document['id']}',
      );
      final directory = await getTemporaryDirectory();
      final name = path.basename('${document['file_name'] ?? 'study.pdf'}');
      final file = File(path.join(directory.path, name));
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } catch (error) {
      if (mounted) showAppMessage(context, '$error');
    }
  }

  Future<void> _deletePdf(AppController app, JsonMap document) async {
    final id = '${document['id']}';
    await app.deletePersonalStudyDocument(id);
    if (!mounted) return;
    setState(() => _selectedPersonalDocuments.remove(id));
    if (app.errorMessage != null) showAppMessage(context, app.errorMessage!);
  }

  String _cleanAnswer(String text) => text
      .split('\n')
      .map((line) {
        final bullet = RegExp(r'^(\s*)\*\s+').firstMatch(line);
        final cleaned = bullet == null
            ? line
            : '${bullet.group(1)}• ${line.substring(bullet.end)}';
        return cleaned.replaceAll('**', '').replaceAll('*', '');
      })
      .join('\n');

  List<JsonMap> _decodeDraftBlocks(String text) {
    try {
      final cleaned = text.replaceAll(
        RegExp(r'^```(?:json)?\s*|\s*```$', multiLine: true),
        '',
      );
      final data = jsonDecode(cleaned);
      final values = data is Map ? data['blocks'] : null;
      if (values is! List) return [];
      return values
          .whereType<Map>()
          .map((value) => value.cast<String, dynamic>())
          .where(
            (block) =>
                DateTime.tryParse('${block['startsAt'] ?? ''}') != null &&
                DateTime.tryParse('${block['endsAt'] ?? ''}') != null,
          )
          .take(12)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _applyPlan(AppController app) async {
    for (final index in _selectedDrafts.toList()..sort()) {
      final block = _draftBlocks[index];
      final start = DateTime.parse('${block['startsAt']}').toLocal();
      final end = DateTime.parse('${block['endsAt']}').toLocal();
      await app.addPlannerBlock(
        title: '${block['title'] ?? 'Study block'}',
        subject: '${block['subject'] ?? ''}',
        startsAt: start,
        endsAt: end,
        reminderEnabled: false,
      );
    }
    if (mounted) {
      showAppMessage(
        context,
        app.errorMessage ??
            'Selected blocks were added to your private calendar.',
      );
    }
  }
}

class _PersonalStudyFileRow extends StatelessWidget {
  const _PersonalStudyFileRow({
    required this.document,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onDelete,
  });

  final JsonMap document;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: context.appPaper,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.appLine),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onSelect,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AppIcon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 17,
                color: selected ? AppColors.red : context.appMuted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${document['file_name'] ?? 'Study PDF'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${((int.tryParse('${document['byte_size'] ?? 0}') ?? 0) / 1024).ceil()} KB · Tap to open',
                    style: TextStyle(color: context.appMuted, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: AppIcon(
                Icons.delete_outline_rounded,
                size: 16,
                color: context.appMuted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.red : context.appSurface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: selected ? AppColors.red : context.appLine),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : context.appInk,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(color: context.appMuted, fontSize: 11),
        ),
      ),
      Switch.adaptive(
        value: value,
        activeTrackColor: AppColors.red,
        onChanged: onChanged,
      ),
    ],
  );
}

class _DraftBlockRow extends StatelessWidget {
  const _DraftBlockRow({
    required this.block,
    required this.selected,
    required this.onChanged,
  });
  final JsonMap block;
  final bool selected;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!selected),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AppIcon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 17,
            color: selected ? AppColors.red : context.appMuted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '${block['title']} · ${block['startsAt']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}
