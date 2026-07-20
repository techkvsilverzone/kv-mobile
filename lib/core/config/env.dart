class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );

  /// Razorpay's publishable key.
  ///
  /// `kv-api` exposes no endpoint for this — the key lives only in server
  /// config, and the web app ships it as a build-time `VITE_RAZORPAY_KEY_ID`.
  /// It must be passed the same way here:
  /// `--dart-define=RAZORPAY_KEY_ID=rzp_...`. Empty means online payment is
  /// unavailable, and checkout says so rather than opening a payment sheet that
  /// is guaranteed to fail.
  static const String razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');

  static bool get hasRazorpayKey => razorpayKeyId.isNotEmpty;
}
