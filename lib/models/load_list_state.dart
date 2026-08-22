import 'load_model.dart';

class LoadListState {
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
      loads: loads ?? this.loads,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
