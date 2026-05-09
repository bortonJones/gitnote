import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'notes_tree/notes_tree_page.dart';
import 'settings/settings_page.dart';

class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ConfiguredHome();
  }
}

class _ConfiguredHome extends ConsumerWidget {
  const _ConfiguredHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configValue = ref.watch(repoConfigControllerProvider);
    return configValue.when(
      data: (config) {
        if (config == null) {
          return const SettingsPage();
        }
        return const NotesTreePage();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('读取配置失败: $error')),
      ),
    );
  }
}
