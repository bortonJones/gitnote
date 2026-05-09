import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/path_utils.dart';
import '../../data/models/repo_config.dart';
import '../../domain/services/config_setup_service.dart';
import '../notes_tree/notes_tree_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static final RegExp _githubRepoUrlPattern = RegExp(
    r'^(?:https?:\/\/)?(?:www\.)?github\.com\/([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+?)(?:\.git)?\/?$',
    caseSensitive: false,
  );

  final _formKey = GlobalKey<FormState>();
  final _repoUrlController = TextEditingController();
  final _branchController = TextEditingController(text: 'main');
  final _tokenController = TextEditingController();
  final _rootPathController = TextEditingController(text: '/');

  bool _obscureToken = true;
  bool _initialized = false;
  bool _isTesting = false;

  @override
  void dispose() {
    _repoUrlController.dispose();
    _branchController.dispose();
    _tokenController.dispose();
    _rootPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configValue = ref.watch(repoConfigControllerProvider);
    final isBusy = _isTesting || configValue.isLoading;

    if (!_initialized) {
      final config = configValue.valueOrNull;
      if (config != null) {
        _repoUrlController.text =
            'https://github.com/${config.owner}/${config.repo}';
        _branchController.text = config.branch;
        _tokenController.text = config.token;
        _rootPathController.text = _displayRootPath(config.rootPath);
      }
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('GitHub 仓库设置')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _repoUrlController,
                enabled: !isBusy,
                decoration: const InputDecoration(
                  labelText: '仓库链接',
                  hintText: 'https://github.com/owner/repo',
                ),
                keyboardType: TextInputType.url,
                validator: _repoUrlValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _branchController,
                enabled: !isBusy,
                decoration: const InputDecoration(
                  labelText: 'branch',
                  hintText: 'main',
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tokenController,
                enabled: !isBusy,
                obscureText: _obscureToken,
                decoration: InputDecoration(
                  labelText: 'token（可选）',
                  suffixIcon: IconButton(
                    onPressed: isBusy
                        ? null
                        : () {
                            setState(() {
                              _obscureToken = !_obscureToken;
                            });
                          },
                    icon: Icon(
                      _obscureToken ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rootPathController,
                enabled: !isBusy,
                decoration: const InputDecoration(
                  labelText: 'rootPath（可选）',
                  hintText: '/',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: isBusy ? null : _testConnection,
                child: Text(_isTesting ? '测试中...' : '测试连接'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: isBusy ? null : _saveConfigWithSteps,
                child: Text(configValue.isLoading ? '保存中...' : '保存配置'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayRootPath(String rootPath) {
    return rootPath.isEmpty ? '/' : rootPath;
  }

  String _normalizeRootPathInput(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '/') {
      return '';
    }
    return PathUtils.normalizeRootPath(trimmed);
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return '该字段不能为空';
    }
    return null;
  }

  String? _repoUrlValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return '请输入 GitHub 仓库链接';
    }
    if (_parseRepoUrl(trimmed) == null) {
      return '请输入正确的 GitHub 仓库链接';
    }
    return null;
  }

  RepoConfig? _buildConfig() {
    if (!_formKey.currentState!.validate()) {
      return null;
    }

    final repoInfo = _parseRepoUrl(_repoUrlController.text.trim());
    if (repoInfo == null) {
      return null;
    }

    return RepoConfig(
      owner: repoInfo.owner,
      repo: repoInfo.repo,
      branch: _branchController.text,
      token: _tokenController.text,
      rootPath: _normalizeRootPathInput(_rootPathController.text),
    ).normalized();
  }

  _RepoUrlInfo? _parseRepoUrl(String value) {
    final match = _githubRepoUrlPattern.firstMatch(value);
    if (match == null) {
      return null;
    }

    final owner = match.group(1);
    final repo = match.group(2);
    if (owner == null || repo == null || owner.isEmpty || repo.isEmpty) {
      return null;
    }

    return _RepoUrlInfo(owner: owner, repo: repo);
  }

  Future<void> _testConnection() async {
    final config = _buildConfig();
    if (config == null) {
      return;
    }

    setState(() {
      _isTesting = true;
    });

    try {
      await ref.read(notesRepositoryProvider).testConnection(config);
      _showSnackBar('连接成功');
    } catch (error) {
      _showSnackBar('连接失败: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveConfigWithSteps() async {
    final newConfig = _buildConfig();
    if (newConfig == null) {
      return;
    }

    final navigator = Navigator.of(context);
    final currentConfig = ref.read(repoConfigControllerProvider).valueOrNull;
    final setupService = ref.read(configSetupServiceProvider);

    final result = await showDialog<ConfigSetupResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ConfigSetupDialog(
          currentConfig: currentConfig,
          newConfig: newConfig,
          setupService: setupService,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    try {
      await ref.read(repoConfigControllerProvider.notifier).save(result.config);
      ref.invalidate(syncIndexProvider);
      ref.invalidate(syncFileMetaMapProvider);
      ref.invalidate(notesTreeProvider);
      ref.invalidate(lastSyncLabelProvider);
      _showSnackBar('配置已保存，目录树已同步');
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const NotesTreePage(),
        ),
      );
    } catch (error) {
      _showSnackBar('保存失败: $error');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RepoUrlInfo {
  const _RepoUrlInfo({
    required this.owner,
    required this.repo,
  });

  final String owner;
  final String repo;
}

class _ConfigSetupDialog extends StatefulWidget {
  const _ConfigSetupDialog({
    required this.currentConfig,
    required this.newConfig,
    required this.setupService,
  });

  final RepoConfig? currentConfig;
  final RepoConfig newConfig;
  final ConfigSetupService setupService;

  @override
  State<_ConfigSetupDialog> createState() => _ConfigSetupDialogState();
}

class _ConfigSetupDialogState extends State<_ConfigSetupDialog> {
  late final Map<ConfigSetupStep, ConfigSetupStepStatus> _statuses = {
    for (final step in ConfigSetupStep.values) step: ConfigSetupStepStatus.undo,
  };

  ConfigSetupResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_run);
  }

  Future<void> _run() async {
    try {
      final result = await widget.setupService.applyConfig(
        newConfig: widget.newConfig,
        currentConfig: widget.currentConfig,
        onStepUpdate: (update) async {
          if (!mounted) {
            return;
          }
          setState(() {
            _statuses[update.step] = update.status;
            _errorMessage = update.status == ConfigSetupStepStatus.failed
                ? update.message
                : _errorMessage;
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _result != null;

    return AlertDialog(
      title: const Text('保存配置'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final step in ConfigSetupStep.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StepRow(
                  label: _labelForStep(step),
                  status: _statuses[step] ?? ConfigSetupStepStatus.undo,
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (completed)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_result),
            child: const Text('确定'),
          ),
      ],
    );
  }

  String _labelForStep(ConfigSetupStep step) {
    switch (step) {
      case ConfigSetupStep.testConnection:
        return '测试链接';
      case ConfigSetupStep.checkRepoChanged:
        return '检查仓库是否变更';
      case ConfigSetupStep.clearLocalCache:
        return '清空本地缓存（如果仓库变更了）';
      case ConfigSetupStep.downloadDirectoryTree:
        return '下载目录结构（rootPath下所有）';
      case ConfigSetupStep.completeTreeSync:
        return '同步目录树完成';
    }
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.status,
  });

  final String label;
  final ConfigSetupStepStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_iconForStatus(status), size: 18, color: _colorForStatus(context)),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Text(
          _textForStatus(status),
          style: TextStyle(color: _colorForStatus(context)),
        ),
      ],
    );
  }

  IconData _iconForStatus(ConfigSetupStepStatus status) {
    switch (status) {
      case ConfigSetupStepStatus.undo:
        return Icons.radio_button_unchecked;
      case ConfigSetupStepStatus.pending:
        return Icons.hourglass_top;
      case ConfigSetupStepStatus.done:
        return Icons.check_circle;
      case ConfigSetupStepStatus.failed:
        return Icons.error;
    }
  }

  Color _colorForStatus(BuildContext context) {
    switch (status) {
      case ConfigSetupStepStatus.undo:
        return Theme.of(context).colorScheme.outline;
      case ConfigSetupStepStatus.pending:
        return Theme.of(context).colorScheme.primary;
      case ConfigSetupStepStatus.done:
        return Colors.green;
      case ConfigSetupStepStatus.failed:
        return Theme.of(context).colorScheme.error;
    }
  }

  String _textForStatus(ConfigSetupStepStatus status) {
    switch (status) {
      case ConfigSetupStepStatus.undo:
        return 'undo';
      case ConfigSetupStepStatus.pending:
        return 'pending';
      case ConfigSetupStepStatus.done:
        return 'done';
      case ConfigSetupStepStatus.failed:
        return 'failed';
    }
  }
}
