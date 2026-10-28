part of '../kelola_screen.dart';

class _CategoryDialog extends StatefulWidget {
  final Category? existing;
  final SupabaseService service;
  const _CategoryDialog({this.existing, required this.service});
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final name = _nameController.text.trim();
      if (widget.existing == null) {
        await widget.service.createCategory(name);
      } else {
        await widget.service
            .updateCategory(id: widget.existing!.id, name: name);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(widget.existing == null ? 'Tambah Kategori' : 'Edit Kategori'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: AppTheme.dangerColor, fontSize: 12))),
                const SizedBox(height: 12),
              ],
              TextFormField(
                  controller: _nameController,
                  decoration:
                      const InputDecoration(labelText: 'Nama Kategori'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
            child: const Text('BATAL')),
        ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('SIMPAN')),
      ],
    );
  }
}