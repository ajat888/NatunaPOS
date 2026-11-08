part of 'sync_runner.dart';

class _SyncExpensesPusher {
  final SupabaseClient _client;
  final LocalDb _localDb;

  _SyncExpensesPusher(SyncRunner r)
      : _client = r.client,
        _localDb = r.localDb;

  Future<int> pushAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    int failures = 0;
    failures += await pushDeletedCategories();
    failures += await pushDeletedItems();
    failures += await pushDeletedExpenses();
    final catRes = await pushCategories(userId);
    failures += catRes.failures;
    failures += await remapItems(catRes.categoryIdMap);
    final itemRes = await pushItems(userId, catRes.categoryIdMap);
    failures += itemRes.failures;
    failures += await pushExpenses(userId, catRes.categoryIdMap, itemRes.itemIdMap);
    return failures;
  }

  Future<int> pushDeletedCategories() async {
    int failures = 0;
    final deleted = await _localDb.getDeletedExpenseCategories();
    for (final c in deleted) {
      try {
        if (c.id > 0) {
          await _client
              .from('expense_categories')
              .update({'is_active': false})
              .eq('id', c.id);
        }
        await _localDb.markExpenseCategorySynced(c.id, skipSync: true);
      } catch (err) {
        debugPrint('Deactivate expense category ${c.id} failed: $err');
        failures++;
      }
    }
    return failures;
  }

  Future<int> pushDeletedItems() async {
    int failures = 0;
    final deleted = await _localDb.getDeletedExpenseItems();
    for (final it in deleted) {
      try {
        if (it.id > 0) {
          await _client
              .from('expense_items')
              .update({'is_active': false})
              .eq('id', it.id);
        }
        await _localDb.markExpenseItemSynced(it.id, skipSync: true);
      } catch (err) {
        debugPrint('Deactivate expense item ${it.id} failed: $err');
        failures++;
      }
    }
    return failures;
  }

  Future<int> pushDeletedExpenses() async {
    int failures = 0;
    final deleted = await _localDb.getDeletedExpenses();
    for (final e in deleted) {
      try {
        if (e.id > 0) {
          await _client
              .from('expenses')
              .update({'is_active': false})
              .eq('id', e.id);
        }
        await _localDb.markExpenseSyncedAndDeleted(e.id, skipSync: true);
      } catch (err) {
        debugPrint('Deactivate expense ${e.id} failed: $err');
        failures++;
      }
    }
    return failures;
  }

  Future<({int failures, Map<int, int> categoryIdMap})> pushCategories(String userId) async {
    int failures = 0;
    final map = <int, int>{};
    final unsynced = await _localDb.getUnsyncedExpenseCategories();
    for (final c in unsynced) {
      try {
        if (c.id < 0) {
          int? existingId;
          try {
            final probe = await _client
                .from('expense_categories')
                .select('id')
                .eq('user_id', userId)
                .eq('name', c.name)
                .limit(1);
            if ((probe as List).isNotEmpty) {
              existingId = (probe.first['id'] as num).toInt();
            }
          } catch (err) {
            debugPrint('Expense category idempotency probe failed: $err');
          }

          int newId;
          Map<String, dynamic> response;
          if (existingId != null) {
            newId = existingId;
            response = {'id': newId, 'name': c.name, 'is_active': true};
          } else {
            response = await _client
                .from('expense_categories')
                .insert({'user_id': userId, 'name': c.name, 'is_active': true})
                .select()
                .single();
            newId = (response['id'] as num).toInt();
          }
          map[c.id] = newId;
          await _localDb.deleteExpenseCategoryLocal(c.id, skipSync: true);
          await _localDb.upsertExpenseCategory(ExpenseCategory.fromJson(response), skipSync: true);
        } else {
          final payload = <String, dynamic>{'name': c.name, 'is_active': true};
          final res = await _client
              .from('expense_categories')
              .update(payload)
              .eq('id', c.id)
              .select();
          if ((res as List).isEmpty) {
            payload['id'] = c.id;
            payload['user_id'] = userId;
            await _client.from('expense_categories').insert(payload);
          }
          await _localDb.upsertExpenseCategory(c.copyWith(isSynced: true), skipSync: true);
        }
      } catch (err) {
        debugPrint('Push expense category ${c.id} failed: $err');
        failures++;
      }
    }
    return (failures: failures, categoryIdMap: map);
  }

  Future<int> remapItems(Map<int, int> categoryIdMap) async {
    int failures = 0;
    for (final entry in categoryIdMap.entries) {
      try {
        await _localDb.remapExpenseItemCategory(entry.key, entry.value, skipSync: true);
      } catch (err) {
        debugPrint('Remap expense category ${entry.key} -> ${entry.value} failed: $err');
        failures++;
      }
    }
    return failures;
  }

  Future<({int failures, Map<int, int> itemIdMap})> pushItems(String userId, Map<int, int> categoryIdMap) async {
    int failures = 0;
    final map = <int, int>{};
    final unsynced = await _localDb.getUnsyncedExpenseItems();
    for (final it in unsynced) {
      try {
        int finalCategoryId = it.categoryId;
        if (finalCategoryId < 0) {
          final mapped = categoryIdMap[finalCategoryId];
          if (mapped == null) {
            debugPrint('Defer expense item ${it.id}: category $finalCategoryId belum sync');
            continue;
          }
          finalCategoryId = mapped;
        }

        if (it.id < 0) {
          int? existingId;
          try {
            final probe = await _client
                .from('expense_items')
                .select('id')
                .eq('user_id', userId)
                .eq('category_id', finalCategoryId)
                .eq('name', it.name)
                .limit(1);
            if ((probe as List).isNotEmpty) {
              existingId = (probe.first['id'] as num).toInt();
            }
          } catch (err) {
            debugPrint('Expense item idempotency probe failed: $err');
          }

          int newId;
          Map<String, dynamic> response;
          if (existingId != null) {
            newId = existingId;
            response = {
              'id': newId,
              'category_id': finalCategoryId,
              'name': it.name,
              'is_active': true,
            };
          } else {
            response = await _client
                .from('expense_items')
                .insert({
                  'user_id': userId,
                  'category_id': finalCategoryId,
                  'name': it.name,
                  'is_active': true,
                })
                .select()
                .single();
            newId = (response['id'] as num).toInt();
          }
          map[it.id] = newId;
          await _localDb.deleteExpenseItemLocal(it.id, skipSync: true);
          await _localDb.upsertExpenseItem(ExpenseItem.fromJson(response), skipSync: true);
        } else {
          final payload = <String, dynamic>{
            'category_id': finalCategoryId,
            'name': it.name,
            'is_active': true,
          };
          final res = await _client
              .from('expense_items')
              .update(payload)
              .eq('id', it.id)
              .select();
          if ((res as List).isEmpty) {
            payload['id'] = it.id;
            payload['user_id'] = userId;
            await _client.from('expense_items').insert(payload);
          }
          await _localDb.upsertExpenseItem(it.copyWith(isSynced: true), skipSync: true);
        }
      } catch (err) {
        debugPrint('Push expense item ${it.id} failed: $err');
        failures++;
      }
    }
    return (failures: failures, itemIdMap: map);
  }

  Future<int> pushExpenses(String userId, Map<int, int> categoryIdMap, Map<int, int> itemIdMap) async {
    int failures = 0;
    final unsynced = await _localDb.getUnsyncedExpenses();
    for (final e in unsynced) {
      try {
        if (e.id >= 0) {
          await _localDb.replaceExpenseId(oldId: e.id, newId: e.id, skipSync: true);
          continue;
        }

        int? finalItemId = e.itemId;
        int? finalCategoryId = e.categoryId;

        if (finalItemId != null && finalItemId < 0) {
          final mapped = itemIdMap[finalItemId];
          if (mapped == null) {
            debugPrint('Defer expense ${e.id}: item $finalItemId belum sync');
            continue;
          }
          finalItemId = mapped;
        }

        if (finalCategoryId != null && finalCategoryId < 0) {
          final mapped = categoryIdMap[finalCategoryId];
          if (mapped == null) {
            debugPrint('Defer expense ${e.id}: category $finalCategoryId belum sync');
            continue;
          }
          finalCategoryId = mapped;
        }

        final createdAtMs = e.createdAt.toUtc().millisecondsSinceEpoch;

        int? existingId;
        try {
          final probe = await _client
              .from('expenses')
              .select('id')
              .eq('user_id', userId)
              .eq('created_at_local', createdAtMs)
              .eq('amount', e.amount)
              .eq('created_by', e.createdBy)
              .limit(1);
          if ((probe as List).isNotEmpty) {
            existingId = (probe.first['id'] as num).toInt();
          }
        } catch (err) {
          debugPrint('Expense idempotency probe failed: $err');
        }

        int newId;
        if (existingId != null) {
          newId = existingId;
        } else {
          final response = await _client
              .from('expenses')
              .insert({
                'user_id': userId,
                'item_id': (finalItemId != null && finalItemId > 0) ? finalItemId : null,
                'item_name': e.itemName,
                'category_id': (finalCategoryId != null && finalCategoryId > 0) ? finalCategoryId : null,
                'category_name': e.categoryName,
                'amount': e.amount,
                'description': e.description,
                'created_at_local': createdAtMs,
                'created_by': e.createdBy,
                'is_active': true,
              })
              .select()
              .single();
          newId = (response['id'] as num).toInt();
        }

        await _localDb.replaceExpenseId(
          oldId: e.id,
          newId: newId,
          newItemId: finalItemId,
          newCategoryId: finalCategoryId,
          skipSync: true,
        );
      } catch (err) {
        debugPrint('Push expense ${e.id} failed: $err');
        failures++;
      }
    }
    return failures;
  }
}