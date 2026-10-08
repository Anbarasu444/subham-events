import '../../../core/error/result.dart';
import '../../../core/money/money.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/budget.dart';
import '../domain/expense.dart';
import 'budget_model.dart';

/// Network-only (server-owned figures). Every change calls [_onChanged] so
/// Home and event screens refresh.
class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl(this._api, this._onChanged);

  final ApiClient _api;
  final void Function() _onChanged;

  String _path(String eventId) => '/events/$eventId/budget';

  @override
  Future<Result<Budget>> load(String eventId) async =>
      _data(await _api.get(_path(eventId), decode: BudgetModel.fromJson));

  @override
  Future<Result<Budget>> setPlanned(
    String eventId,
    String categoryId,
    Money planned,
  ) async => _changed(
    await _api.put(
      '${_path(eventId)}/allocations/$categoryId',
      body: {'planned': planned.toJson()},
      decode: BudgetModel.fromJson,
    ),
  );

  @override
  Future<Result<Budget>> clearPlanned(
    String eventId,
    String categoryId,
  ) async => _changed(
    await _api.delete(
      '${_path(eventId)}/allocations/$categoryId',
      decode: BudgetModel.fromJson,
    ),
  );

  String _expenses(String eventId) => '/events/$eventId/expenses';

  @override
  Future<Result<ExpenseList>> loadExpenses(String eventId) async => _data(
    await _api.get(_expenses(eventId), decode: BudgetModel.expenseListFromJson),
  );

  @override
  Future<Result<Expense>> addExpense(
    String eventId,
    ExpenseInput input, {
    required String idempotencyKey,
  }) async => _changed(
    await _api.post(
      _expenses(eventId),
      body: BudgetModel.expenseToJson(input),
      idempotencyKey: idempotencyKey,
      decode: BudgetModel.expenseFromJson,
    ),
  );

  @override
  Future<Result<Expense>> updateExpense(
    String eventId,
    Expense expense,
    ExpenseInput input,
  ) async => _changed(
    await _api.patch(
      '${_expenses(eventId)}/${expense.id}',
      body: {...BudgetModel.expenseToJson(input), 'version': expense.version},
      decode: BudgetModel.expenseFromJson,
    ),
  );

  @override
  Future<Result<void>> deleteExpense(String eventId, Expense expense) async =>
      _changed(
        await _api.delete(
          '${_expenses(eventId)}/${expense.id}',
          decode: (_) {},
        ),
      );

  Result<T> _data<T>(Result<ApiResponse<T>> result) => switch (result) {
    Ok(:final value) => Ok(value.data),
    Err(:final failure) => Err(failure),
  };

  Result<T> _changed<T>(Result<ApiResponse<T>> result) {
    final mapped = _data(result);
    if (mapped is Ok) _onChanged();
    return mapped;
  }
}
