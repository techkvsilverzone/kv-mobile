/// `kv-api` returns the user with Mongo's `_id` and **no** response envelope:
/// `POST /auth/login` yields `{user, token}` while `GET /users/me` yields the
/// user object bare at the top level.
///
/// Deliberate omission: the server embeds an `addresses[]` array here, but
/// those sub-documents key their id as `_id` while the dedicated
/// `/users/me/addresses` endpoints key it as `id` — two shapes for one entity.
/// Rather than carry both, the address book is always read from its own
/// endpoint (see AddressRepository) and is not parsed off the user.
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.isAdmin = false,
    this.isActive = true,
    this.dateOfBirth,
    this.anniversaryDate,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final bool isAdmin;
  final bool isActive;

  /// `PUT /users/me` returns the raw Mongoose document, which omits the
  /// computed `role` that `GET /users/me` adds — so this must tolerate a
  /// missing value rather than assume the server always sends one.
  final String role;

  final DateTime? dateOfBirth;
  final DateTime? anniversaryDate;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phone: json['phone'] as String?,
      isAdmin: json['isAdmin'] == true,
      isActive: json['isActive'] != false,
      role: (json['role'] as String?) ?? 'customer',
      dateOfBirth: _parseDate(json['dateOfBirth']),
      anniversaryDate: _parseDate(json['anniversaryDate']),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'email': email,
        if (phone != null) 'phone': phone,
        'isAdmin': isAdmin,
        'isActive': isActive,
        'role': role,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        if (anniversaryDate != null) 'anniversaryDate': anniversaryDate!.toIso8601String(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

/// Envelope returned by `/auth/login`, `/auth/signup` and `/auth/otp/verify`.
/// The JWT is a top-level sibling of `user` — not nested inside it.
class AuthResult {
  const AuthResult({required this.user, required this.token, this.promoCoupon});

  final User user;
  final String token;

  /// Present only when signup ran during an active stall event; the key is
  /// absent (not null) otherwise.
  final String? promoCoupon;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      user: User.fromJson((json['user'] as Map).cast<String, dynamic>()),
      token: (json['token'] ?? '') as String,
      promoCoupon: json['promoCoupon'] as String?,
    );
  }
}
