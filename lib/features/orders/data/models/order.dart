/// Order lifecycle. Literals are capitalised on the wire.
enum OrderStatus { pending, processing, shipped, delivered, cancelled, unknown }

OrderStatus orderStatusFrom(String? raw) => switch (raw) {
      'Pending' => OrderStatus.pending,
      'Processing' => OrderStatus.processing,
      'Shipped' => OrderStatus.shipped,
      'Delivered' => OrderStatus.delivered,
      'Cancelled' => OrderStatus.cancelled,
      _ => OrderStatus.unknown,
    };

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Order placed',
        OrderStatus.processing => 'Processing',
        OrderStatus.shipped => 'Shipped',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.unknown => 'Unknown',
      };

  /// The status as the server spells it ("Pending"), which the web shows raw.
  String get wireName => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.unknown => 'Unknown',
        _ => label,
      };

  /// Position in the fulfilment timeline; -1 for states outside it.
  int get stepIndex => switch (this) {
        OrderStatus.pending => 0,
        OrderStatus.processing => 1,
        OrderStatus.shipped => 2,
        OrderStatus.delivered => 3,
        _ => -1,
      };
}

class OrderItem {
  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.weight,
    this.productId = '',
    this.image,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double? weight;

  /// Base64 or URL snapshot of the product image, when the server kept one.
  final String? image;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productName: (json['productName'] ?? '') as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
        weight: (json['weight'] as num?)?.toDouble(),
        productId: (json['productId'] ?? json['product'] ?? '').toString(),
        image: (json['image'] as String?)?.isNotEmpty == true ? json['image'] as String : null,
      );
}

class OrderAddress {
  const OrderAddress({
    required this.name,
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    required this.phone,
  });

  final String name;
  final String line1;
  final String city;
  final String state;
  final String pincode;
  final String phone;

  factory OrderAddress.fromJson(Map<String, dynamic> json) => OrderAddress(
        // Written as `name`/`line1`, but older orders may carry the aliases.
        name: (json['name'] ??
                '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim())
            .toString(),
        line1: (json['line1'] ?? json['address'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
        state: (json['state'] ?? '').toString(),
        pincode: (json['pincode'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
      );
}

class Order {
  const Order({
    required this.id,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.taxAmount,
    required this.deliveryFee,
    required this.couponDiscount,
    required this.grandTotal,
    required this.items,
    required this.createdAt,
    this.invoiceNumber,
    this.couponCode,
    this.address,
    this.deliveredAt,
    this.isInStore = false,
    this.giftWrapFee = 0,
    this.giftMessage,
    this.saleLocation,
    this.soldByName,
  });

  final String id;
  final String? invoiceNumber;
  final OrderStatus status;

  /// Stored lowercase by a model setter: `cod` or `razorpay`.
  final String paymentMethod;
  final String paymentStatus;

  final double subtotal;
  final double taxAmount;
  final double deliveryFee;
  final double couponDiscount;
  final double giftWrapFee;
  final String? giftMessage;

  /// The amount actually charged. Prefer this over the server's `totalWithTax`,
  /// which omits the discount and therefore disagrees whenever a coupon applied.
  final double grandTotal;

  final String? couponCode;
  final List<OrderItem> items;
  final OrderAddress? address;
  final DateTime? createdAt;
  final DateTime? deliveredAt;

  /// `channel == 'OFFLINE'`: billed in-store or at a stall from the admin panel.
  final bool isInStore;
  final String? saleLocation;
  final String? soldByName;

  String get shortId => id.length <= 6 ? id : id.substring(id.length - 6);

  String get paymentMethodLabel => switch (paymentMethod.toLowerCase()) {
        'razorpay' => 'Paid online',
        'cod' => 'Cash on delivery',
        _ => paymentMethod,
      };

  factory Order.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List?)
            ?.whereType<Map>()
            .map((e) => OrderItem.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false) ??
        const <OrderItem>[];

    final address = json['shippingAddress'];

    return Order(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      invoiceNumber: json['invoiceNumber'] as String?,
      status: orderStatusFrom(json['status'] as String?),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? '').toString(),
      subtotal: _d(json['subtotal']),
      taxAmount: _d(json['taxAmount']),
      deliveryFee: _d(json['deliveryFee']),
      couponDiscount: _d(json['couponDiscount']),
      giftWrapFee: _d(json['giftWrapFee']),
      giftMessage: (json['giftMessage'] as String?)?.isEmpty ?? true ? null : json['giftMessage'] as String,
      grandTotal: _d(json['grandTotal'] ?? json['totalAmount']),
      couponCode: json['couponCode'] as String?,
      items: items,
      address: address is Map ? OrderAddress.fromJson(address.cast<String, dynamic>()) : null,
      createdAt: _date(json['createdAt']),
      deliveredAt: _date(json['deliveredAt']),
      isInStore: json['channel'] == 'OFFLINE',
      saleLocation: json['saleLocation'] as String?,
      soldByName: (json['soldBy'] is Map) ? (json['soldBy'] as Map)['name'] as String? : null,
    );
  }

  static double _d(dynamic v) => v is num ? v.toDouble() : 0;

  static DateTime? _date(dynamic v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
