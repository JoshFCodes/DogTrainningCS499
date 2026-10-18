import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../data/profile_repository.dart';

class PetEditorScreen extends StatefulWidget {
  const PetEditorScreen({
    super.key,
    required this.repository,
    this.petId,
    this.initialData = const {},
  });

  final ProfileRepository repository;
  final String? petId;
  final Map<String, dynamic> initialData;

  @override
  State<PetEditorScreen> createState() => _PetEditorScreenState();
}

class _PetEditorScreenState extends State<PetEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _birthDate;
  late final TextEditingController _goals;
  late final TextEditingController _notes;

  static const _focusOptions = [
    'Trust',
    'Obedience',
    'Patience',
    'Confidence',
    'Fitness',
    'Socialization',
  ];

  late String _focus;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final data = widget.initialData;

    _name = TextEditingController(text: data['name'] as String? ?? '');
    _breed = TextEditingController(text: data['breed'] as String? ?? '');
    _birthDate = TextEditingController(
      text: data['birthDate'] as String? ?? '',
    );
    _goals = TextEditingController(text: data['goals'] as String? ?? '');
    _notes = TextEditingController(text: data['notes'] as String? ?? '');

    final initialFocus = data['focus'] as String? ?? 'Trust';
    _focus = _focusOptions.contains(initialFocus) ? initialFocus : 'Trust';
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _birthDate.dispose();
    _goals.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _validateBirthDate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return 'Use YYYY-MM-DD, or leave blank if unknown.';
    }

    final date = DateTime.tryParse(text);
    if (date == null) return 'Enter a valid date.';

    final normalized =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    if (normalized != text ||
        date.isAfter(DateTime.now()) ||
        date.year < 1900) {
      return 'Enter a valid birth date in the past.';
    }

    return null;
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.repository.savePet(
        petId: widget.petId,
        name: _name.text,
        breed: _breed.text,
        birthDate: _birthDate.text,
        focus: _focus,
        goals: _goals.text,
        notes: _notes.text,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error = accountErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this pet profile?'),
        content: const Text('This removes the saved profile permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.repository.deletePet(widget.petId!);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error = accountErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int maxLength, {
    bool required = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !_busy,
        maxLength: maxLength,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator:
            validator ??
            (value) {
              if (required && (value?.trim().isEmpty ?? true)) {
                return 'This field is required.';
              }
              return null;
            },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.petId == null ? 'Add pet' : 'Edit pet'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field(_name, 'Pet name', 80, required: true),
                      _field(_breed, 'Breed or mix — optional', 120),
                      _field(
                        _birthDate,
                        'Birth date — optional, YYYY-MM-DD',
                        10,
                        validator: _validateBirthDate,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _focus,
                        decoration: const InputDecoration(
                          labelText: 'Current training focus',
                        ),
                        items: _focusOptions
                            .map(
                              (focus) => DropdownMenuItem(
                                value: focus,
                                child: Text(focus),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) {
                                setState(() => _focus = value!);
                              },
                      ),
                      const SizedBox(height: 20),
                      _field(_goals, 'Training goals', 1000, maxLines: 3),
                      _field(
                        _notes,
                        'Temperament, preferences, and relevant notes',
                        2000,
                        maxLines: 4,
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? 'Working...' : 'Save pet'),
                      ),
                      if (widget.petId != null)
                        TextButton(
                          onPressed: _busy ? null : _delete,
                          child: const Text('Delete pet profile'),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(_error!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
