part of 'sync_runner.dart';

class _SyncSettings {
  final SupabaseClient _client;
  final LocalDb _localDb;

  _SyncSettings(SyncRunner r)
      : _client = r.client,
        _localDb = r.localDb;

  Future<int> sync() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final settings = AppSettings.instance;
    int failures = 0;

    bool shouldPush = settings.isDirty;
    if (!shouldPush) {
      try {
        final existing = await _client
            .from('store_settings')
            .select('id')
            .eq('user_id', userId)
            .limit(1);
        if ((existing as List).isEmpty && _hasLocalData(settings)) {
          shouldPush = true;
        }
      } catch (e) {
        debugPrint('Settings probe failed: $e');
      }
    }

    if (shouldPush) {
      if (!settings.isDirty) await settings.markDirty();
      failures += await _push(userId);
    }
    failures += await _pull(userId);
    return failures;
  }

  bool _hasLocalData(AppSettings s) {
    final logo = s.logoPath.value;
    final hasLogo = logo != null && File(logo).existsSync();
    return s.storeName.value.isNotEmpty ||
        s.storeSubtitle.value.isNotEmpty ||
        s.storeAddress.value.isNotEmpty ||
        s.storePhone.value.isNotEmpty ||
        s.receiptFooter.value.isNotEmpty ||
        hasLogo;
  }

  Future<int> _push(String userId) async {
    final settings = AppSettings.instance;
    final tax = TaxSettings.instance;
    try {
      String? logoUrl = settings.logoUrl;
      final localLogo = settings.logoPath.value;
      final localExists = localLogo != null && File(localLogo).existsSync();
      final needUpload =
          settings.isLogoDirty || (logoUrl == null && localExists);

      if (needUpload) {
        if (localExists) {
          final fileName =
              'store_logo_${DateTime.now().millisecondsSinceEpoch}.png';
          await _client.storage
              .from('product_images')
              .upload(fileName, File(localLogo));
          logoUrl =
              _client.storage.from('product_images').getPublicUrl(fileName);
          await settings.saveLogoUrl(logoUrl);
        } else {
          logoUrl = null;
          await settings.saveLogoUrl(null);
        }
        await settings.clearLogoDirty();
      }

      final payload = <String, dynamic>{
        ...settings.toServerJson(logoUrl: logoUrl),
        'user_id': userId,
        'tax_enabled': tax.isEnabled,
        'tax_rate': tax.currentRate,
      };

      final existing = await _client
          .from('store_settings')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      Map<String, dynamic> res;
      if ((existing as List).isEmpty) {
        res = await _client
            .from('store_settings')
            .insert(payload)
            .select()
            .single();
      } else {
        final id = (existing.first as Map)['id'] as int;
        res = await _client
            .from('store_settings')
            .update(payload)
            .eq('id', id)
            .select()
            .single();
      }
      final serverMs =
          DateTime.parse(res['updated_at'] as String).millisecondsSinceEpoch;
      await settings.markSynced(serverMs);
      return 0;
    } catch (e) {
      debugPrint('Push settings failed: $e');
      return 1;
    }
  }

  Future<int> _pull(String userId) async {
    try {
      final settings = AppSettings.instance;
      if (settings.isDirty) return 0;

      final res = await _client
          .from('store_settings')
          .select()
          .eq('user_id', userId)
          .limit(1);
      if ((res as List).isEmpty) return 0;
      final row = res.first as Map<String, dynamic>;

      final rawUpdated = row['updated_at'];
      if (rawUpdated == null) return 0;
      final serverMs = rawUpdated is num
          ? rawUpdated.toInt()
          : DateTime.parse(rawUpdated.toString()).millisecondsSinceEpoch;

      if (settings.updatedAtMs >= serverMs) return 0;

      final logoUrl = row['logo_url'] as String?;
      final currentLocal = settings.logoPath.value;
      final currentUrl = settings.logoUrl;
      String? localLogoPath;

      if (logoUrl != null && logoUrl.isNotEmpty) {
        if (currentLocal != null &&
            File(currentLocal).existsSync() &&
            currentUrl == logoUrl) {
          localLogoPath = currentLocal;
        } else {
          try {
            final dir = await getApplicationDocumentsDirectory();
            if (!await dir.exists()) await dir.create(recursive: true);
            final response = await http
                .get(Uri.parse(logoUrl))
                .timeout(const Duration(seconds: 15));
            if (response.statusCode == 200) {
              final file = File(
                  '${dir.path}/logo_${DateTime.now().millisecondsSinceEpoch}.png');
              await file.writeAsBytes(response.bodyBytes);
              localLogoPath = file.path;
            }
          } catch (e) {
            debugPrint('Download logo failed: $e');
          }
        }
      }

      await settings.applyFromServer(
        storeName: row['store_name'] as String? ?? '',
        storeSubtitle: row['store_subtitle'] as String? ?? '',
        storeAddress: row['store_address'] as String? ?? '',
        storePhone: row['store_phone'] as String? ?? '',
        receiptFooter: row['receipt_footer'] as String? ?? '',
        logoPath: localLogoPath,
        logoUrl: logoUrl,
        serverUpdatedAtMs: serverMs,
      );

      await TaxSettings.instance.applyFromServer(
        enabled: row['tax_enabled'] as bool? ?? false,
        rate: (row['tax_rate'] as num?)?.toDouble() ?? 11.0,
      );

      return 0;
    } catch (e) {
      debugPrint('Pull settings failed: $e');
      return 1;
    }
  }
}