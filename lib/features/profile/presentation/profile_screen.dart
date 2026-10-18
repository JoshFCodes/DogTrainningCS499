import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../data/profile_repository.dart';
import 'pet_editor_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  late final ProfileRepository _repository;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _pets;

  String _experience = 'beginner';
  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  String? _message;

  AuthService get _auth => AuthService.instance;

  @override
  void initState() {
    super.initState();

    _repository = ProfileRepository(widget.uid);
    _pets = _repository.watchPets();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final data = await _repository.loadProfile();

      if (!mounted) return;

      _name.text = data['displayName'] as String? ?? '';
      final experience = data['experience'] as String? ?? 'beginner';

      _experience =
          ['beginner', 'intermediate', 'experienced'].contains(experience)
          ? experience
          : 'beginner';
    } catch (error) {
      if (mounted) {
        _loadError = accountErrorMessage(error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await action();

      if (mounted) {
        setState(() => _message = successMessage);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = accountErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    _run(
      () => _repository.saveProfile(
        displayName: _name.text,
        experience: _experience,
      ),
      successMessage: 'Profile saved.',
    );
  }

  void _openPet({String? id, Map<String, dynamic> data = const {}}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PetEditorScreen(
          repository: _repository,
          petId: id,
          initialData: data,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account & pets')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account & pets')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final user = _auth.currentUser;

    if (user == null || user.uid != widget.uid) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final providers = user.providerData
        .map((provider) => provider.providerId)
        .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Account & pets')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your account',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(user.email ?? 'No email shared by this provider'),
                  const SizedBox(height: 6),
                  Text(
                    user.emailVerified
                        ? 'Email verified'
                        : 'Email not verified',
                  ),
                  const SizedBox(height: 6),
                  Text('Sign-in methods: ${providers.join(', ')}'),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                          ),
                          validator: (value) {
                            return value == null || value.trim().isEmpty
                                ? 'Enter a display name.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _experience,
                          decoration: const InputDecoration(
                            labelText: 'Dog-training experience',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'beginner',
                              child: Text('Beginner'),
                            ),
                            DropdownMenuItem(
                              value: 'intermediate',
                              child: Text('Intermediate'),
                            ),
                            DropdownMenuItem(
                              value: 'experienced',
                              child: Text('Experienced'),
                            ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) {
                                  setState(() => _experience = value!);
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _saveProfile,
                    child: const Text('Save profile'),
                  ),
                  if (!user.emailVerified && user.email != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              _auth.sendVerificationEmail,
                              successMessage:
                                  'Verification email sent. Open the '
                                  'link, then refresh account status.',
                            ),
                      child: const Text('Send verification email'),
                    ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            _auth.refreshUser,
                            successMessage: 'Account status refreshed.',
                          ),
                    child: const Text('Refresh account status'),
                  ),
                  if (providers.contains('password') && user.email != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _auth.sendPasswordReset(user.email!),
                              successMessage: 'Password reset email requested.',
                            ),
                      child: const Text('Reset password'),
                    ),
                  if (!providers.contains('google.com'))
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              _auth.linkGoogle,
                              successMessage: 'Google account linked.',
                            ),
                      child: const Text('Link Google sign-in'),
                    ),
                  if (!providers.contains('apple.com'))
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              _auth.linkApple,
                              successMessage: 'Apple account linked.',
                            ),
                      child: const Text('Link Apple sign-in'),
                    ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _run(_auth.signOut),
                    child: const Text('Sign out'),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_message!),
                      ),
                    ),
                  const Divider(height: 40),
                  Text(
                    'Your pets',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _pets,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(accountErrorMessage(snapshot.error!));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final pets = snapshot.data!.docs;

                      if (pets.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('Add your first pet to get started.'),
                        );
                      }

                      return Column(
                        children: pets.map((pet) {
                          final data = pet.data();

                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.pets_outlined),
                              title: Text(data['name'] as String),
                              subtitle: Text('Current focus: ${data['focus']}'),
                              trailing: const Icon(Icons.edit_outlined),
                              onTap: _busy
                                  ? null
                                  : () => _openPet(id: pet.id, data: data),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _openPet(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add pet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
