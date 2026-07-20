/// Address book entry.
///
/// The `/users/me/addresses` endpoints map Mongo's `_id` to `id` before
/// responding, but the same entity embedded in `GET /users/me` keeps `_id`.
/// [fromJson] accepts either so a payload from any source parses.
class Address {
  const Address({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.phone,
    this.label,
    this.isDefault = false,
  });

  final String id;
  final String? label;
  final String firstName;
  final String lastName;

  /// Single free-text line — the server has no line1/line2 split.
  final String address;
  final String city;
  final String state;

  /// String, not int — leading zeros are significant in Indian PIN codes.
  final String pincode;
  final String phone;
  final bool isDefault;

  String get fullName => '$firstName $lastName'.trim();

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      label: json['label'] as String?,
      firstName: (json['firstName'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      address: (json['address'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      state: (json['state'] ?? '') as String,
      pincode: (json['pincode'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      isDefault: json['isDefault'] == true,
    );
  }

  /// Write payload. `id` is never sent — it travels in the URL on update.
  /// The server silently drops unknown keys, so only the known set is emitted.
  Map<String, dynamic> toJson() => {
        if (label != null && label!.isNotEmpty) 'label': label,
        'firstName': firstName,
        'lastName': lastName,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'phone': phone,
        'isDefault': isDefault,
      };

  Address copyWith({
    String? id,
    String? label,
    String? firstName,
    String? lastName,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    bool? isDefault,
  }) =>
      Address(
        id: id ?? this.id,
        label: label ?? this.label,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        pincode: pincode ?? this.pincode,
        phone: phone ?? this.phone,
        isDefault: isDefault ?? this.isDefault,
      );
}
