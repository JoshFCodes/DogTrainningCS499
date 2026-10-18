import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../profile/presentation/profile_screen.dart';
import 'saved_training_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.chatPageBuilder,
    this.currentFocus = 'Trust',
    this.focusDescription =
        'Build confidence through calm, consistent, rewarding interactions.',
  });

  final WidgetBuilder chatPageBuilder;
  final String currentFocus;
  final String focusDescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Account & pets',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              final user = AuthService.instance.currentUser;
              if (user == null) return;

              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(uid: user.uid),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Small steps. Stronger bonds.',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Make time for a little progress together today.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.flag_outlined, color: colors.primary),
                              const SizedBox(width: 10),
                              Text(
                                'Current Focus',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            currentFocus,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            focusDescription,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: chatPageBuilder));
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Start a New Session'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SavedTrainingPanel(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
