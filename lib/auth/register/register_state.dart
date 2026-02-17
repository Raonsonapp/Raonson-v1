class RegisterState {
  final String username;
  final String password;
  final String confirmPassword;
  final bool isLoading;
  final String? error;

  const RegisterState({
    this.username = '',
    this.password = '',
    this.confirmPassword = '',
    this.isLoading = false,
    this.error,
  });

  RegisterState copyWith({
    String? username,
    String? password,
    String? confirmPassword,
    bool? isLoading,
    String? error,
  }) {
    return RegisterState(
      username: username ?? this.username,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get passwordsMatch => password.isNotEmpty && password == confirmPassword;

  bool get canSubmit =>
      username.isNotEmpty && passwordsMatch && !isLoading;
}
