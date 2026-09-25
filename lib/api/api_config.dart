class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'MAILFLOW_API_URL',
    defaultValue: 'https://celllaunch.shop/api/',
  );

  static const String apiKey = String.fromEnvironment(
    'MAILFLOW_API_KEY',
    defaultValue: 'dev-key-change-me',
  );
  static const String mailbox = 'yesdaddy@celllaunch.shop';
}