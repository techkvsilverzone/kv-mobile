// Sample data for screenshot tests: realistic shapes, parsed by the app's own models.
import 'package:kv_silver_mobile/core/pricing/pricing.dart';
import 'package:kv_silver_mobile/features/catalog/data/catalog_repository.dart';
import 'package:kv_silver_mobile/features/catalog/data/models/product.dart';
import 'package:kv_silver_mobile/features/orders/data/models/order.dart';
import 'package:kv_silver_mobile/features/savings/data/savings_models.dart';

Product sampleProduct(int i, {String? name, double price = 1250, bool sale = false, bool inStock = true}) =>
    Product.fromJson({
      '_id': 'p$i',
      'name': name ?? ['Peacock Anklet Pair', 'Lakshmi Silver Coin 10g', 'Kuthu Vilakku Lamp', 'Kids Bangle Set', 'Temple Jhumka Earrings', 'Ganesha Idol'][i % 6],
      'description': 'Handcrafted 925 sterling silver with an oxidised temple finish. BIS hallmarked.',
      'material': ['Anklets', 'Coins', 'Puja Items', 'Bangles', 'Earrings', 'Idols'][i % 6],
      'price': price + i * 310,
      'listedPrice': price + i * 310,
      'originalPrice': sale ? (price + i * 310) * 1.2 : null,
      'isSale': sale,
      'isNewItem': i == 1,
      'isFixedPrice': i.isOdd,
      'weight': 10 + i * 2.5,
      'purity': '925',
      'inStock': inStock,
      'stockAvailable': inStock ? 6 : 0,
      'images': [],
      'variants': i == 0
          ? [
              {'label': 'S', 'weight': '20 g'},
              {'label': 'M', 'weight': '25 g'},
              {'label': 'L', 'weight': '30 g'},
            ]
          : [],
    });

final sampleProducts = [for (var i = 0; i < 8; i++) sampleProduct(i, sale: i == 2, inStock: i != 5)];

const sampleCategories = [
  CategoryNode('Anklets'), CategoryNode('Coins'), CategoryNode('Puja Items'), CategoryNode('Bangles'),
  CategoryNode('Earrings'), CategoryNode('Idols'),
];

const sampleSilver = [MetalRate(id: 's', date: '2026-10-31', ratePerGram: 112, ratePerKg: 112000, purity: '999')];
const sampleGold = [MetalRate(id: 'g', date: '2026-10-31', ratePerGram: 7350, ratePerKg: 7350000, purity: '916')];
const sampleSilverHistory = [
  MetalRate(id: 's1', date: '2026-10-31', ratePerGram: 112, ratePerKg: 112000, purity: '999'),
  MetalRate(id: 's0', date: '2026-10-30', ratePerGram: 110.5, ratePerKg: 110500, purity: '999'),
];

Order sampleOrder(int i, {String status = 'Shipped'}) => Order.fromJson({
      '_id': '6720000000000$i',
      'invoiceNumber': 'INV-2026-00012$i',
      'status': status,
      'paymentMethod': 'razorpay',
      'paymentStatus': 'paid',
      'items': [
        {'productId': 'p1', 'productName': 'Peacock Anklet Pair', 'quantity': 1, 'unitPrice': 2450, 'totalPrice': 2450, 'weight': 25},
        {'productId': 'p2', 'productName': 'Lakshmi Silver Coin 10g', 'quantity': 2, 'unitPrice': 1180, 'totalPrice': 2360},
      ],
      'subtotal': 4810,
      'taxAmount': 144.3,
      'deliveryFee': 150,
      'couponDiscount': 0,
      'totalAmount': 5104.3,
      'createdAt': '2026-10-2${i}T10:30:00Z',
      'shippingAddress': {
        'name': 'Vinoth Kumar', 'line1': '12, Anna Salai, T. Nagar', 'city': 'Chennai', 'state': 'Tamil Nadu',
        'pincode': '600017', 'phone': '9876543210'
      },
    });

SchemePlan samplePlan(int i) => SchemePlan.fromJson({
      '_id': 'plan$i',
      'type': ['SILVER_11_1', 'GOLD_11_1', 'SILVER_SMART'][i % 3],
      'name': ['Silver Purchase Plan', 'Gold Purchase Plan', 'KV Smart Purchase Plan'][i % 3],
      'description': 'Pay monthly for 11 months; we add the 12th month free, credited in grams.',
      'metal': i == 1 ? 'GOLD' : 'SILVER',
      'durationMonths': 11,
      'bonusMonths': i == 2 ? 0 : 1,
      'paymentMode': i == 2 ? 'FLEXIBLE' : 'FIXED',
      'monthlyAmounts': [1000, 2000, 5000],
      'minPaymentAmount': 500,
    });

SavingsEnrollment sampleScheme() => SavingsEnrollment.fromJson({
      '_id': 'sch1',
      'userId': 'u1',
      'passbookNumber': 'SLV-2526-0000112',
      'schemeType': 'SILVER_11_1',
      'metal': 'SILVER',
      'planName': 'Silver Purchase Plan',
      'monthlyAmount': 2000,
      'duration': 11,
      'startDate': '2026-06-05',
      'status': 'Active',
      'totalPaid': 10000,
      'bonusAmount': 0,
      'maturityDate': '2027-05-05T00:00:00Z',
      'payments': [
        for (var m = 1; m <= 5; m++)
          {
            'month': m, 'amount': 2000, 'paidAt': '2026-0${m + 5 > 9 ? 9 : m + 5}-0${m}T10:00:00Z',
            'materialRate': 100 + m, 'materialWeight': 19.6 - m * 0.2, 'devidentAmount': 0,
            'devidentMaterialRate': 0, 'devidentMaterialWeight': 0, 'method': 'ONLINE',
          },
      ],
    });
