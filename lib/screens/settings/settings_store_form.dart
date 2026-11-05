part of '../settings_screen.dart';

class _StoreInfoSection extends StatefulWidget {
  const _StoreInfoSection();

  @override
  State<_StoreInfoSection> createState() => _StoreInfoSectionState();
}

class _StoreInfoSectionState extends State<_StoreInfoSection> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _footerController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.instance;
    _nameController = TextEditingController(text: s.storeName.value);
    _addressController = TextEditingController(text: s.storeAddress.value);
    _phoneController = TextEditingController(text: s.storePhone.value);
    _footerController = TextEditingController(text: s.receiptFooter.value);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppSettings.instance.saveStoreInfo(
        name: _nameController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        footer: _footerController.text,
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Info toko disimpan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan info toko'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Info Toko'),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama Toko'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Alamat'),
                  minLines: 1,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'No. Telepon'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _footerController,
                  decoration: const InputDecoration(
                    labelText: 'Footer Struk',
                    helperText: 'Contoh: Terima kasih atas kunjungan Anda',
                  ),
                  minLines: 1,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('SIMPAN INFO TOKO'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}