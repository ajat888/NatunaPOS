part of '../settings_screen.dart';

class _StoreInfoSection extends StatefulWidget {
  const _StoreInfoSection();

  @override
  State<_StoreInfoSection> createState() => _StoreInfoSectionState();
}

class _StoreInfoSectionState extends State<_StoreInfoSection> {
  late final TextEditingController _nameController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _footerController;

  final _nameFocus = FocusNode();
  final _subtitleFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _footerFocus = FocusNode();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.instance;
    _nameController = TextEditingController(text: s.storeName.value);
    _subtitleController = TextEditingController(text: s.storeSubtitle.value);
    _addressController = TextEditingController(text: s.storeAddress.value);
    _phoneController = TextEditingController(text: s.storePhone.value);
    _footerController = TextEditingController(text: s.receiptFooter.value);

    s.storeName.addListener(_syncName);
    s.storeSubtitle.addListener(_syncSubtitle);
    s.storeAddress.addListener(_syncAddress);
    s.storePhone.addListener(_syncPhone);
    s.receiptFooter.addListener(_syncFooter);
  }

  void _syncName() {
    if (_nameFocus.hasFocus) return;
    final v = AppSettings.instance.storeName.value;
    if (_nameController.text != v) _nameController.text = v;
  }

  void _syncSubtitle() {
    if (_subtitleFocus.hasFocus) return;
    final v = AppSettings.instance.storeSubtitle.value;
    if (_subtitleController.text != v) _subtitleController.text = v;
  }

  void _syncAddress() {
    if (_addressFocus.hasFocus) return;
    final v = AppSettings.instance.storeAddress.value;
    if (_addressController.text != v) _addressController.text = v;
  }

  void _syncPhone() {
    if (_phoneFocus.hasFocus) return;
    final v = AppSettings.instance.storePhone.value;
    if (_phoneController.text != v) _phoneController.text = v;
  }

  void _syncFooter() {
    if (_footerFocus.hasFocus) return;
    final v = AppSettings.instance.receiptFooter.value;
    if (_footerController.text != v) _footerController.text = v;
  }

  @override
  void dispose() {
    final s = AppSettings.instance;
    s.storeName.removeListener(_syncName);
    s.storeSubtitle.removeListener(_syncSubtitle);
    s.storeAddress.removeListener(_syncAddress);
    s.storePhone.removeListener(_syncPhone);
    s.receiptFooter.removeListener(_syncFooter);
    _nameController.dispose();
    _subtitleController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerController.dispose();
    _nameFocus.dispose();
    _subtitleFocus.dispose();
    _addressFocus.dispose();
    _phoneFocus.dispose();
    _footerFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppSettings.instance.saveStoreInfo(
        name: _nameController.text,
        subtitle: _subtitleController.text,
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
                  focusNode: _nameFocus,
                  decoration: const InputDecoration(labelText: 'Nama Toko'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subtitleController,
                  focusNode: _subtitleFocus,
                  decoration: const InputDecoration(
                      labelText: 'Subtitle (Cafe & Resto)'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  focusNode: _addressFocus,
                  decoration: const InputDecoration(labelText: 'Alamat'),
                  minLines: 1,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  decoration: const InputDecoration(labelText: 'No. Telepon'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _footerController,
                  focusNode: _footerFocus,
                  decoration: const InputDecoration(
                    labelText: 'Footer Struk / Promo',
                    helperText: 'Contoh: Ada acara spesial? Hubungi WA...',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
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