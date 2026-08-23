import 'dart:collection';

import 'load_model.dart';

class LoadListState extends ListBase<LoadModel> {
  final List<LoadModel> loads;
  final bool isLoading;
  final String? errorMessage;

  const LoadListState({
    this.loads = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  LoadListState copyWith({
    List<LoadModel>? loads,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoadListState(
      loads: List<LoadModel>.unmodifiable(loads ?? this.loads),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  int get length => loads.length;

  @override
  set length(int value) {
    throw UnsupportedError('LoadListState is immutable.');
  }

  @override
  LoadModel operator [](int index) => loads[index];

  @override
  void operator []=(int index, LoadModel value) {
    throw UnsupportedError('LoadListState is immutable.');
  }
}
