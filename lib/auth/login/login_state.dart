class LoginState {
  final String username;
  final String password;
  final bool isLoading;
  final String? error;

  const LoginState({
    this.username = '',
    this.password = '',
    this.isLoading = false,
    this.error,
  });

  LoginState copyWith({
    String? username,
    String? password,
    bool? isLoading,
    String? error,
  }) {
    return LoginState(
      username: username ?? this.username,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get canSubmit =>
      username.isNotEmpty && password.isNotEmpty && !isLoading;
}
