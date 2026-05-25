double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// Per-item special-price request — salesperson asks, manager decides.
// `pending` is the only state the salesperson can create; manager flips it
// to `approved` (override applied) or `rejected` (no change to order_item).
class PriceRequest {
  final String id;
  // Null when the request was created from the standalone "Price Request"
  // menu (no cart exists yet). The manager UI shows "ກ່ອນ Order" in that case.
  final String? cartNumber;
  final String itemCode;
  final String? itemName;
  final String? unitName;
  final int qty;
  final double originalPrice;
  // Null until a manager approves the request and sets the approved price.
  // Requestors never supply this — they only submit a proposal + reason.
  final double? requestedPrice;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String requestorCode;
  final String? requestorName;
  final String? reason;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? approverCode;
  final String? approverName;
  final String? approverNote;
  final String? customerName;
  final double cartAmount;

  const PriceRequest({
    required this.id,
    required this.cartNumber,
    required this.itemCode,
    this.itemName,
    this.unitName,
    this.qty = 0,
    required this.originalPrice,
    this.requestedPrice,
    required this.status,
    required this.requestorCode,
    this.requestorName,
    this.reason,
    required this.requestedAt,
    this.decidedAt,
    this.approverCode,
    this.approverName,
    this.approverNote,
    this.customerName,
    this.cartAmount = 0,
  });

  bool get isStandalone => cartNumber == null;
  // discount / discountPct collapse to 0 while requestedPrice is null
  // (i.e. the request is still pending without an approver-set price).
  double get discount =>
      requestedPrice != null ? originalPrice - requestedPrice! : 0;
  double get discountPct => originalPrice > 0 && requestedPrice != null
      ? (discount / originalPrice) * 100
      : 0;

  factory PriceRequest.fromJson(Map<String, dynamic> j) => PriceRequest(
    id: j['id'].toString(),
    cartNumber: j['cartNumber'] as String?,
    itemCode: j['itemCode'] as String,
    itemName: j['itemName'] as String?,
    unitName: j['unitName'] as String?,
    qty: (j['qty'] as num?)?.toInt() ?? 0,
    originalPrice: _toDouble(j['originalPrice']),
    requestedPrice: j['requestedPrice'] == null
        ? null
        : _toDouble(j['requestedPrice']),
    status: j['status'] as String? ?? 'pending',
    requestorCode: j['requestorCode'] as String? ?? '',
    requestorName: j['requestorName'] as String?,
    reason: j['reason'] as String?,
    requestedAt:
        DateTime.tryParse(j['requestedAt']?.toString() ?? '') ?? DateTime.now(),
    decidedAt: j['decidedAt'] != null
        ? DateTime.tryParse(j['decidedAt'].toString())
        : null,
    approverCode: j['approverCode'] as String?,
    approverName: j['approverName'] as String?,
    approverNote: j['approverNote'] as String?,
    customerName: j['customerName'] as String?,
    cartAmount: _toDouble(j['cartAmount']),
  );
}

// Pending shortfall written by POST /api/orders when stock < ordered qty.
// Lives in app_backorder; warehouse staff close rows manually via the
// Backorders screen once stock arrives.
class Backorder {
  final String id;
  final String cartNumber;
  final String itemCode;
  final String? itemName;
  final String? unitName;
  final String? warehouseCode;
  final String? locationCode;
  final double qtyPending;
  final String status; // 'open' | 'fulfilled' | 'cancelled'
  final DateTime createdAt;
  final DateTime? fulfilledAt;
  final String? fulfilledBy;
  final String? customerName;
  final double cartAmount;

  const Backorder({
    required this.id,
    required this.cartNumber,
    required this.itemCode,
    this.itemName,
    this.unitName,
    this.warehouseCode,
    this.locationCode,
    required this.qtyPending,
    required this.status,
    required this.createdAt,
    this.fulfilledAt,
    this.fulfilledBy,
    this.customerName,
    this.cartAmount = 0,
  });

  factory Backorder.fromJson(Map<String, dynamic> j) => Backorder(
    id: j['id'].toString(),
    cartNumber: j['cartNumber'] as String,
    itemCode: j['itemCode'] as String,
    itemName: j['itemName'] as String?,
    unitName: j['unitName'] as String?,
    warehouseCode: j['warehouseCode'] as String?,
    locationCode: j['locationCode'] as String?,
    qtyPending: _toDouble(j['qtyPending']),
    status: (j['status'] as String?) ?? 'open',
    createdAt:
        DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    fulfilledAt: j['fulfilledAt'] != null
        ? DateTime.tryParse(j['fulfilledAt'].toString())
        : null,
    fulfilledBy: j['fulfilledBy'] as String?,
    customerName: j['customerName'] as String?,
    cartAmount: _toDouble(j['cartAmount']),
  );
}

// Aggregated stats returned by GET /api/me/stats — powers the My Dashboard
// home tab. All amounts are in KIP.
class MyStatsPeriod {
  final int pendingCount;
  final int completedCount;
  final int cancelledCount;
  final double pendingAmount;
  final double completedAmount;
  final double cancelledAmount;

  const MyStatsPeriod({
    this.pendingCount = 0,
    this.completedCount = 0,
    this.cancelledCount = 0,
    this.pendingAmount = 0,
    this.completedAmount = 0,
    this.cancelledAmount = 0,
  });

  int get activeOrders => pendingCount + completedCount;
  double get activeAmount => pendingAmount + completedAmount;

  factory MyStatsPeriod.fromJson(Map<String, dynamic> j) => MyStatsPeriod(
    pendingCount: (j['pendingCount'] as num?)?.toInt() ?? 0,
    completedCount: (j['completedCount'] as num?)?.toInt() ?? 0,
    cancelledCount: (j['cancelledCount'] as num?)?.toInt() ?? 0,
    pendingAmount: _toDouble(j['pendingAmount']),
    completedAmount: _toDouble(j['completedAmount']),
    cancelledAmount: _toDouble(j['cancelledAmount']),
  );
}

class MyStatsRank {
  final int myRank; // 0 = not ranked (no sales today)
  final int totalSalespeople;
  final double myTodayTotal;
  final double topTotal;
  final String? topName;

  const MyStatsRank({
    this.myRank = 0,
    this.totalSalespeople = 0,
    this.myTodayTotal = 0,
    this.topTotal = 0,
    this.topName,
  });

  factory MyStatsRank.fromJson(Map<String, dynamic> j) => MyStatsRank(
    myRank: (j['myRank'] as num?)?.toInt() ?? 0,
    totalSalespeople: (j['totalSalespeople'] as num?)?.toInt() ?? 0,
    myTodayTotal: _toDouble(j['myTodayTotal']),
    topTotal: _toDouble(j['topTotal']),
    topName: j['topName'] as String?,
  );
}

class MyStatsRecentOrder {
  final String cartNumber;
  final String? customerName;
  final double amount;
  final String status; // 'PENDING' | 'COMPLETED' | 'CANCELLED'
  final DateTime createdAt;

  const MyStatsRecentOrder({
    required this.cartNumber,
    this.customerName,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory MyStatsRecentOrder.fromJson(Map<String, dynamic> j) =>
      MyStatsRecentOrder(
        cartNumber: j['cartNumber'] as String,
        customerName: j['customerName'] as String?,
        amount: _toDouble(j['amount']),
        status: j['status'] as String? ?? 'PENDING',
        createdAt:
            DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class MyStats {
  final MyStatsPeriod today;
  final MyStatsPeriod yesterday;
  final MyStatsPeriod month;
  final MyStatsRank rank;
  final List<MyStatsRecentOrder> recent;

  const MyStats({
    required this.today,
    required this.yesterday,
    required this.month,
    required this.rank,
    required this.recent,
  });

  factory MyStats.fromJson(Map<String, dynamic> j) => MyStats(
    today: MyStatsPeriod.fromJson(
      (j['today'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    yesterday: MyStatsPeriod.fromJson(
      (j['yesterday'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    month: MyStatsPeriod.fromJson(
      (j['month'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    rank: MyStatsRank.fromJson(
      (j['rank'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    recent: ((j['recent'] as List<dynamic>?) ?? const [])
        .map((e) => MyStatsRecentOrder.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// App-level permission tier, parallel to the backend's lib/roles.ts. NULL/
// unknown values fall through to [salesperson] so unprovisioned accounts can
// still create their own orders.
enum AppRole { pc, salesperson, head, manager }

AppRole _parseRole(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'pc':
      return AppRole.pc;
    case 'head':
      return AppRole.head;
    case 'manager':
      return AppRole.manager;
    case 'salesperson':
    default:
      return AppRole.salesperson;
  }
}

String roleToWire(AppRole role) {
  switch (role) {
    case AppRole.pc:
      return 'pc';
    case AppRole.salesperson:
      return 'salesperson';
    case AppRole.head:
      return 'head';
    case AppRole.manager:
      return 'manager';
  }
}

String roleLabelLao(AppRole role) {
  switch (role) {
    case AppRole.pc:
      return 'PC';
    case AppRole.salesperson:
      return 'ພະນັກງານຂາຍ';
    case AppRole.head:
      return 'ຫົວໜ້າພະນັກງານຂາຍ';
    case AppRole.manager:
      return 'ຜູ່ຈັດການ';
  }
}

class Employee {
  final int employeeId;
  final String? employeeCode;
  final String? fullnameLo;
  final String? fullnameEn;
  final String? nickname;
  final String? positionCode;
  final AppRole appRole;

  Employee({
    required this.employeeId,
    this.employeeCode,
    this.fullnameLo,
    this.fullnameEn,
    this.nickname,
    this.positionCode,
    this.appRole = AppRole.salesperson,
  });

  String get displayName =>
      fullnameLo ?? fullnameEn ?? nickname ?? employeeCode ?? '—';

  bool get canCancelOrders =>
      appRole == AppRole.head || appRole == AppRole.manager;
  bool get canCreateCustomers =>
      appRole == AppRole.head || appRole == AppRole.manager;
  bool get canBeSalesperson => appRole != AppRole.pc;

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
    employeeId: (j['employeeId'] as num).toInt(),
    employeeCode: j['employeeCode'] as String?,
    fullnameLo: j['fullnameLo'] as String?,
    fullnameEn: j['fullnameEn'] as String?,
    nickname: j['nickname'] as String?,
    positionCode: j['positionCode'] as String?,
    appRole: _parseRole(j['appRole'] as String?),
  );
}

class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String?,
    price: _toDouble(j['price']),
    stock: (j['stock'] as num).toInt(),
    imageUrl: j['imageUrl'] as String?,
  );
}

class Warehouse {
  final String code;
  final String name;
  final String? branchCode;
  final String? odCode;

  Warehouse({
    required this.code,
    required this.name,
    this.branchCode,
    this.odCode,
  });

  factory Warehouse.fromJson(Map<String, dynamic> j) => Warehouse(
    code: j['code'] as String,
    name: (j['name'] as String?) ?? (j['code'] as String),
    branchCode: j['branchCode'] as String?,
    odCode: j['odCode'] as String?,
  );
}

class TransportType {
  final String code;
  final String name;

  const TransportType({required this.code, required this.name});

  factory TransportType.fromJson(Map<String, dynamic> j) => TransportType(
    code: j['code'] as String,
    name: (j['name'] as String?) ?? (j['code'] as String),
  );
}

class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? groupCode;
  final String? groupName;
  final double discountPct;
  final double pointBalance;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.groupCode,
    this.groupName,
    this.discountPct = 0,
    this.pointBalance = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    address: j['address'] as String?,
    groupCode: j['groupCode'] as String?,
    groupName: j['groupName'] as String?,
    discountPct: _toDouble(j['discountPct']),
    pointBalance: _toDouble(j['pointBalance']),
  );
}

class LoyaltyConfig {
  final double earnKipPerPoint;
  final String pointName;
  final bool isActive;

  const LoyaltyConfig({
    this.earnKipPerPoint = 70000,
    this.pointName = 'ແຕ້ມສະສົມ',
    this.isActive = true,
  });

  factory LoyaltyConfig.fromJson(Map<String, dynamic> j) {
    final earn = _toDouble(j['earnKipPerPoint']);
    final name = (j['pointName'] as String?)?.trim();
    return LoyaltyConfig(
      earnKipPerPoint: earn > 0 ? earn : 70000,
      pointName: name == null || name.isEmpty ? 'ແຕ້ມສະສົມ' : name,
      isActive: j['isActive'] != false,
    );
  }
}

class OrderItem {
  final String id;
  final String productId;
  final Product? product;
  final int quantity;
  final double unitPrice;

  OrderItem({
    required this.id,
    required this.productId,
    this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => unitPrice * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id: j['id'] as String,
    productId: j['productId'] as String,
    product: j['product'] is Map<String, dynamic>
        ? Product.fromJson(j['product'] as Map<String, dynamic>)
        : null,
    quantity: (j['quantity'] as num).toInt(),
    unitPrice: _toDouble(j['unitPrice']),
  );
}

enum InventoryScope { company, sales }

class InventoryItem {
  final String code;
  final String nameLo;
  final String? nameEng;
  final String? unitName;
  final String? brand;
  final String? brandName;
  final String? category;
  final String? categoryName;
  final String? groupMain;
  final String? groupMainName;
  final bool hasSet;
  final int? status;
  final int? itemStatus;
  final double companyBalance;
  final double salesBalance;
  final double salesMinimumStock;
  final double salePriceKip;

  InventoryItem({
    required this.code,
    required this.nameLo,
    this.nameEng,
    this.unitName,
    this.brand,
    this.brandName,
    this.category,
    this.categoryName,
    this.groupMain,
    this.groupMainName,
    this.hasSet = false,
    this.status,
    this.itemStatus,
    this.companyBalance = 0,
    this.salesBalance = 0,
    this.salesMinimumStock = 0,
    this.salePriceKip = 0,
  });

  double balanceFor(InventoryScope scope) =>
      scope == InventoryScope.sales ? salesBalance : companyBalance;

  InventoryItem copyWith({
    bool resetCompanyBalance = false,
    double? companyBalance,
    double? salesBalance,
    double? salesMinimumStock,
    double? salePriceKip,
  }) => InventoryItem(
    code: code,
    nameLo: nameLo,
    nameEng: nameEng,
    unitName: unitName,
    brand: brand,
    brandName: brandName,
    category: category,
    categoryName: categoryName,
    groupMain: groupMain,
    groupMainName: groupMainName,
    hasSet: hasSet,
    status: status,
    itemStatus: itemStatus,
    companyBalance: resetCompanyBalance
        ? (companyBalance ?? 0)
        : (companyBalance ?? this.companyBalance),
    salesBalance: salesBalance ?? this.salesBalance,
    salesMinimumStock: salesMinimumStock ?? this.salesMinimumStock,
    salePriceKip: salePriceKip ?? this.salePriceKip,
  );

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
    code: j['code'] as String,
    nameLo: (j['nameLo'] as String?) ?? '',
    nameEng: j['nameEng'] as String?,
    unitName: j['unitName'] as String?,
    brand: j['brand'] as String?,
    brandName: j['brandName'] as String?,
    category: j['category'] as String?,
    categoryName: j['categoryName'] as String?,
    groupMain: j['groupMain'] as String?,
    groupMainName: j['groupMainName'] as String?,
    hasSet: j['hasSet'] == true,
    status: (j['status'] as num?)?.toInt(),
    itemStatus: (j['itemStatus'] as num?)?.toInt(),
    // Accept either the new field or the legacy `cachedBalance` for back-compat.
    companyBalance: _toDouble(j['companyBalance'] ?? j['cachedBalance']),
    salesBalance: _toDouble(j['salesBalance']),
    salesMinimumStock: _toDouble(j['salesMinimumStock'] ?? j['minimumStock']),
    salePriceKip: _toDouble(j['salePriceKip'] ?? j['price']),
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'nameLo': nameLo,
    'nameEng': nameEng,
    'unitName': unitName,
    'brand': brand,
    'brandName': brandName,
    'category': category,
    'categoryName': categoryName,
    'groupMain': groupMain,
    'groupMainName': groupMainName,
    'hasSet': hasSet,
    'status': status,
    'itemStatus': itemStatus,
    'companyBalance': companyBalance,
    'salesBalance': salesBalance,
    'salesMinimumStock': salesMinimumStock,
    'salePriceKip': salePriceKip,
  };
}

class ProductSetDetailItem {
  final int lineNumber;
  final String itemCode;
  final String itemName;
  final String? unitCode;
  final double quantity;
  final double price;
  final double amount;

  const ProductSetDetailItem({
    required this.lineNumber,
    required this.itemCode,
    required this.itemName,
    this.unitCode,
    required this.quantity,
    required this.price,
    required this.amount,
  });

  factory ProductSetDetailItem.fromJson(Map<String, dynamic> j) =>
      ProductSetDetailItem(
        lineNumber: (j['lineNumber'] as num?)?.toInt() ?? 0,
        itemCode: j['itemCode'] as String,
        itemName: (j['itemName'] as String?) ?? (j['itemCode'] as String),
        unitCode: j['unitCode'] as String?,
        quantity: _toDouble(j['quantity']),
        price: _toDouble(j['price']),
        amount: _toDouble(j['amount']),
      );
}

class StockBalance {
  final String code;
  final String? name;
  final double balanceQty;
  final String? unitCode;
  final double averageCost;
  final double averageCostEnd;
  final double balanceAmount;
  final List<StockLocation> locations;

  StockBalance({
    required this.code,
    this.name,
    required this.balanceQty,
    this.unitCode,
    required this.averageCost,
    required this.averageCostEnd,
    required this.balanceAmount,
    this.locations = const [],
  });

  factory StockBalance.fromJson(Map<String, dynamic> j) => StockBalance(
    code: (j['code'] as String?) ?? '',
    name: j['name'] as String?,
    balanceQty: _toDouble(j['balanceQty']),
    unitCode: j['unitCode'] as String?,
    averageCost: _toDouble(j['averageCost']),
    averageCostEnd: _toDouble(j['averageCostEnd']),
    balanceAmount: _toDouble(j['balanceAmount']),
    locations:
        (j['locations'] as List<dynamic>?)
            ?.map((e) => StockLocation.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

class StockLocation {
  final String? warehouse;
  final String? warehouseName;
  final String? location;
  final String? locationName;
  final double balanceQty;
  final String? unitCode;
  final double averageCost;
  final double averageCostEnd;
  final double balanceAmount;

  StockLocation({
    this.warehouse,
    this.warehouseName,
    this.location,
    this.locationName,
    required this.balanceQty,
    this.unitCode,
    required this.averageCost,
    required this.averageCostEnd,
    required this.balanceAmount,
  });

  factory StockLocation.fromJson(Map<String, dynamic> j) => StockLocation(
    warehouse: j['warehouse'] as String?,
    warehouseName: j['warehouseName'] as String?,
    location: j['location'] as String?,
    locationName: j['locationName'] as String?,
    balanceQty: _toDouble(j['balanceQty']),
    unitCode: j['unitCode'] as String?,
    averageCost: _toDouble(j['averageCost']),
    averageCostEnd: _toDouble(j['averageCostEnd']),
    balanceAmount: _toDouble(j['balanceAmount']),
  );
}

// Lightweight representation of the staff member credited for the sale —
// returned alongside SaleOrder. Backend only sends the bits needed for
// display (no employeeId), so we use a dedicated type instead of `Employee`.
class Salesperson {
  final String employeeCode;
  final String? fullnameLo;
  final String? fullnameEn;
  final String? nickname;

  Salesperson({
    required this.employeeCode,
    this.fullnameLo,
    this.fullnameEn,
    this.nickname,
  });

  String get displayName =>
      fullnameLo ?? fullnameEn ?? nickname ?? employeeCode;

  factory Salesperson.fromJson(Map<String, dynamic> j) => Salesperson(
    employeeCode: j['employeeCode'] as String,
    fullnameLo: j['fullnameLo'] as String?,
    fullnameEn: j['fullnameEn'] as String?,
    nickname: j['nickname'] as String?,
  );
}

class SaleOrder {
  final String id;
  // Full SML doc_no (eg. "SOK26050001"). The server already exposes this on
  // the orders list so the UI can show the canonical document number; `id`
  // remains the short cart_number suffix used in URLs / cancel calls.
  final String? docNo;
  final String customerId;
  final Customer? customer;
  final Salesperson? salesperson;
  final String status;
  final double total;
  final DateTime createdAt;
  final List<OrderItem> items;

  SaleOrder({
    required this.id,
    this.docNo,
    required this.customerId,
    this.customer,
    this.salesperson,
    required this.status,
    required this.total,
    required this.createdAt,
    required this.items,
  });

  factory SaleOrder.fromJson(Map<String, dynamic> j) => SaleOrder(
    id: j['id'] as String,
    docNo: j['docNo'] as String?,
    customerId: j['customerId'] as String,
    customer: j['customer'] is Map<String, dynamic>
        ? Customer.fromJson(j['customer'] as Map<String, dynamic>)
        : null,
    salesperson: j['salesperson'] is Map<String, dynamic>
        ? Salesperson.fromJson(j['salesperson'] as Map<String, dynamic>)
        : null,
    status: j['status'] as String? ?? 'PENDING',
    total: _toDouble(j['total']),
    createdAt:
        DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    items:
        (j['items'] as List<dynamic>?)
            ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

class Promotion {
  final String id;
  final String name;
  final String promoType;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? timeFrom; // HH:MM
  final String? timeTo; // HH:MM
  final String? triggerItemCode;
  final double? triggerQty;
  final String? bonusItemCode;
  final double? bonusQty;
  final double? bonusPriceKip;
  final double? fixedPriceKip;
  final String? note;
  final bool awardsPoints;
  final bool awardsMemberDiscount;

  const Promotion({
    required this.id,
    required this.name,
    required this.promoType,
    required this.isActive,
    this.startAt,
    this.endAt,
    this.timeFrom,
    this.timeTo,
    this.triggerItemCode,
    this.triggerQty,
    this.bonusItemCode,
    this.bonusQty,
    this.bonusPriceKip,
    this.fixedPriceKip,
    this.note,
    this.awardsPoints = true,
    this.awardsMemberDiscount = true,
  });

  factory Promotion.fromJson(Map<String, dynamic> j) => Promotion(
    id: j['id']?.toString() ?? '',
    name: j['name'] as String? ?? '',
    promoType: j['promoType'] as String? ?? '',
    isActive: j['isActive'] as bool? ?? false,
    startAt: j['startAt'] != null
        ? DateTime.tryParse(j['startAt'].toString())
        : null,
    endAt: j['endAt'] != null ? DateTime.tryParse(j['endAt'].toString()) : null,
    timeFrom: j['timeFrom'] as String?,
    timeTo: j['timeTo'] as String?,
    triggerItemCode: j['triggerItemCode'] as String?,
    triggerQty: j['triggerQty'] != null ? _toDouble(j['triggerQty']) : null,
    bonusItemCode: j['bonusItemCode'] as String?,
    bonusQty: j['bonusQty'] != null ? _toDouble(j['bonusQty']) : null,
    bonusPriceKip: j['bonusPriceKip'] != null
        ? _toDouble(j['bonusPriceKip'])
        : null,
    fixedPriceKip: j['fixedPriceKip'] != null
        ? _toDouble(j['fixedPriceKip'])
        : null,
    note: j['note'] as String?,
    awardsPoints: j['awardsPoints'] as bool? ?? true,
    awardsMemberDiscount: j['awardsMemberDiscount'] as bool? ?? true,
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Manager-facing report & config models. These back the new screens under
// the Manager Hub: salespeople rankings, cashier activity, loyalty config,
// stock refill workflow, promo effectiveness, and member directory.
// ─────────────────────────────────────────────────────────────────────────

// One row in the `/api/reports/salespeople` response — per-employee daily/
// period totals used by the team rankings screen.
class SalespersonStats {
  final String? userOwner;
  final String? employeeCode;
  final String displayName;
  final String? positionCode;
  final int pendingCount;
  final int completedCount;
  final int cancelledCount;
  final double pendingAmount;
  final double completedAmount;
  final double cancelledAmount;
  final double activeTotal;
  final int activeOrders;
  final double avgOrderValue;

  const SalespersonStats({
    this.userOwner,
    this.employeeCode,
    required this.displayName,
    this.positionCode,
    this.pendingCount = 0,
    this.completedCount = 0,
    this.cancelledCount = 0,
    this.pendingAmount = 0,
    this.completedAmount = 0,
    this.cancelledAmount = 0,
    this.activeTotal = 0,
    this.activeOrders = 0,
    this.avgOrderValue = 0,
  });

  factory SalespersonStats.fromJson(Map<String, dynamic> j) => SalespersonStats(
        userOwner: j['userOwner'] as String?,
        employeeCode: j['employeeCode'] as String?,
        displayName: j['displayName'] as String? ?? '—',
        positionCode: j['positionCode'] as String?,
        pendingCount: (j['pendingCount'] as num?)?.toInt() ?? 0,
        completedCount: (j['completedCount'] as num?)?.toInt() ?? 0,
        cancelledCount: (j['cancelledCount'] as num?)?.toInt() ?? 0,
        pendingAmount: _toDouble(j['pendingAmount']),
        completedAmount: _toDouble(j['completedAmount']),
        cancelledAmount: _toDouble(j['cancelledAmount']),
        activeTotal: _toDouble(j['activeTotal']),
        activeOrders: (j['activeOrders'] as num?)?.toInt() ?? 0,
        avgOrderValue: _toDouble(j['avgOrderValue']),
      );
}

// One row in `/api/reports/shift-summary` — per-cashier-per-day totals
// broken out by payment channel (cash / transfer / redeemed / promo).
class CashierShiftRow {
  final String cashierCode;
  final String cashierName;
  final String day; // YYYY-MM-DD
  final int billCount;
  final int voidedCount;
  final double totalKip;
  final double cashKip;
  final double transferKip;
  final double redeemedKip;
  final double promoKip;

  const CashierShiftRow({
    required this.cashierCode,
    required this.cashierName,
    required this.day,
    this.billCount = 0,
    this.voidedCount = 0,
    this.totalKip = 0,
    this.cashKip = 0,
    this.transferKip = 0,
    this.redeemedKip = 0,
    this.promoKip = 0,
  });

  factory CashierShiftRow.fromJson(Map<String, dynamic> j) => CashierShiftRow(
        cashierCode: j['cashierCode'] as String? ?? '',
        cashierName: j['cashierName'] as String? ?? '—',
        day: j['day'] as String? ?? '',
        billCount: (j['billCount'] as num?)?.toInt() ?? 0,
        voidedCount: (j['voidedCount'] as num?)?.toInt() ?? 0,
        totalKip: _toDouble(j['totalKip']),
        cashKip: _toDouble(j['cashKip']),
        transferKip: _toDouble(j['transferKip']),
        redeemedKip: _toDouble(j['redeemedKip']),
        promoKip: _toDouble(j['promoKip']),
      );
}

// (LoyaltyConfig is defined earlier in this file. Manager-facing extension
// fields — id / redeem / note / audit timestamps — are exposed via the
// LoyaltyConfigManager wrapper below so we don't break the existing call
// sites that only need {earnKipPerPoint, pointName, isActive}.)
class LoyaltyConfigManager {
  final int id;
  final double earnKipPerPoint;
  final double redeemPointsPerKip;
  final int minRedeemPoints;
  final String pointName;
  final bool isActive;
  final String? note;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LoyaltyConfigManager({
    required this.id,
    required this.earnKipPerPoint,
    required this.redeemPointsPerKip,
    required this.minRedeemPoints,
    required this.pointName,
    required this.isActive,
    this.note,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory LoyaltyConfigManager.fromJson(Map<String, dynamic> j) =>
      LoyaltyConfigManager(
        id: (j['id'] as num?)?.toInt() ?? 0,
        earnKipPerPoint: _toDouble(j['earnKipPerPoint']),
        redeemPointsPerKip: _toDouble(j['redeemPointsPerKip']),
        minRedeemPoints: (j['minRedeemPoints'] as num?)?.toInt() ?? 0,
        pointName: j['pointName'] as String? ?? 'point',
        isActive: j['isActive'] as bool? ?? true,
        note: j['note'] as String?,
        updatedBy: j['updatedBy'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'].toString())
            : null,
        updatedAt: j['updatedAt'] != null
            ? DateTime.tryParse(j['updatedAt'].toString())
            : null,
      );
}

// Stock balance below the per-warehouse minimum — surfaced under the
// "items" array of /api/reports/stock-refill so the manager can spot
// what needs reorder.
class StockRefillItem {
  final String itemCode;
  final String itemName;
  final String warehouseCode;
  final double currentBalance;
  final double minimumBalance;
  final double deficit;
  final String status; // 'needs_refill' | 'critical' | ...

  const StockRefillItem({
    required this.itemCode,
    required this.itemName,
    required this.warehouseCode,
    this.currentBalance = 0,
    this.minimumBalance = 0,
    this.deficit = 0,
    this.status = '',
  });

  factory StockRefillItem.fromJson(Map<String, dynamic> j) => StockRefillItem(
        itemCode: j['itemCode'] as String? ?? '',
        itemName: j['itemName'] as String? ?? '—',
        warehouseCode: j['warehouseCode'] as String? ?? '',
        currentBalance: _toDouble(j['currentBalance']),
        minimumBalance: _toDouble(j['minimumBalance']),
        deficit: _toDouble(j['deficit']),
        status: j['status'] as String? ?? '',
      );
}

// A submitted refill request — flows through pending -> approved/rejected
// -> fulfilled/cancelled. Mirrors the workflow on the web's stock-refill
// dashboard.
class StockRefillRequest {
  final String id;
  final String warehouseCode;
  final String itemCode;
  final String? itemName;
  final double requestedQty;
  final String? reason;
  final String status; // 'pending' | 'approved' | 'rejected' | 'fulfilled' | 'cancelled'
  final String? requestedBy;
  final DateTime? requestedAt;
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? note;
  final String? refDocNo;

  const StockRefillRequest({
    required this.id,
    required this.warehouseCode,
    required this.itemCode,
    this.itemName,
    this.requestedQty = 0,
    this.reason,
    required this.status,
    this.requestedBy,
    this.requestedAt,
    this.decidedBy,
    this.decidedAt,
    this.note,
    this.refDocNo,
  });

  factory StockRefillRequest.fromJson(Map<String, dynamic> j) =>
      StockRefillRequest(
        id: j['id']?.toString() ?? '',
        warehouseCode: j['warehouseCode'] as String? ?? '',
        itemCode: j['itemCode'] as String? ?? '',
        itemName: j['itemName'] as String?,
        requestedQty: _toDouble(j['requestedQty']),
        reason: j['reason'] as String?,
        status: j['status'] as String? ?? 'pending',
        requestedBy: j['requestedBy'] as String?,
        requestedAt: j['requestedAt'] != null
            ? DateTime.tryParse(j['requestedAt'].toString())
            : null,
        decidedBy: j['decidedBy'] as String?,
        decidedAt: j['decidedAt'] != null
            ? DateTime.tryParse(j['decidedAt'].toString())
            : null,
        note: j['note'] as String?,
        refDocNo: j['refDocNo'] as String?,
      );
}

// Per-promo effectiveness — how many bills/lines triggered the promo and
// the total discount given vs. revenue contributed.
class PromoEffectivenessRow {
  final String promoId;
  final String promoName;
  final String? promoType;
  final bool isActive;
  final int billCount;
  final int lineCount;
  final double totalDiscountKip;
  final double totalKip;

  const PromoEffectivenessRow({
    required this.promoId,
    required this.promoName,
    this.promoType,
    this.isActive = true,
    this.billCount = 0,
    this.lineCount = 0,
    this.totalDiscountKip = 0,
    this.totalKip = 0,
  });

  factory PromoEffectivenessRow.fromJson(Map<String, dynamic> j) =>
      PromoEffectivenessRow(
        promoId: j['promoId']?.toString() ?? '',
        promoName: j['promoName'] as String? ?? '—',
        promoType: j['promoType'] as String?,
        isActive: j['isActive'] as bool? ?? true,
        billCount: (j['billCount'] as num?)?.toInt() ?? 0,
        lineCount: (j['lineCount'] as num?)?.toInt() ?? 0,
        totalDiscountKip: _toDouble(j['totalDiscountKip']),
        totalKip: _toDouble(j['totalKip']),
      );
}

// ── Daily sales report ─────────────────────────────────────────────────
// One bucket of the /api/reports/daily-sales response.

class DailySalesTotals {
  final int docCount;
  final int cakCount;
  final int inkCount;
  final double cakTotal;
  final double inkTotal;
  final double total;
  final double totalBeforeVat;
  final double totalVat;

  const DailySalesTotals({
    this.docCount = 0,
    this.cakCount = 0,
    this.inkCount = 0,
    this.cakTotal = 0,
    this.inkTotal = 0,
    this.total = 0,
    this.totalBeforeVat = 0,
    this.totalVat = 0,
  });

  factory DailySalesTotals.fromJson(Map<String, dynamic> j) => DailySalesTotals(
        docCount: (j['docCount'] as num?)?.toInt() ?? 0,
        cakCount: (j['cakCount'] as num?)?.toInt() ?? 0,
        inkCount: (j['inkCount'] as num?)?.toInt() ?? 0,
        cakTotal: _toDouble(j['cakTotal']),
        inkTotal: _toDouble(j['inkTotal']),
        total: _toDouble(j['total']),
        totalBeforeVat: _toDouble(j['totalBeforeVat']),
        totalVat: _toDouble(j['totalVat']),
      );
}

class DailySalesCurrency {
  final String currencyCode;
  final int docCount;
  final double totalBaht;
  final double totalNative;

  const DailySalesCurrency({
    required this.currencyCode,
    this.docCount = 0,
    this.totalBaht = 0,
    this.totalNative = 0,
  });

  factory DailySalesCurrency.fromJson(Map<String, dynamic> j) =>
      DailySalesCurrency(
        currencyCode: j['currencyCode'] as String? ?? '',
        docCount: (j['docCount'] as num?)?.toInt() ?? 0,
        totalBaht: _toDouble(j['totalBaht']),
        totalNative: _toDouble(j['totalNative']),
      );
}

class DailySalesSalesperson {
  final String saleCode;
  final String? fullnameLo;
  final String? nickname;
  final int docCount;
  final double totalBaht;

  const DailySalesSalesperson({
    required this.saleCode,
    this.fullnameLo,
    this.nickname,
    this.docCount = 0,
    this.totalBaht = 0,
  });

  factory DailySalesSalesperson.fromJson(Map<String, dynamic> j) =>
      DailySalesSalesperson(
        saleCode: j['saleCode'] as String? ?? '',
        fullnameLo: j['fullnameLo'] as String?,
        nickname: j['nickname'] as String?,
        docCount: (j['docCount'] as num?)?.toInt() ?? 0,
        totalBaht: _toDouble(j['totalBaht']),
      );
}

class DailySalesRow {
  final String docNo;
  final String docDate;
  final String? docTime;
  final String? custCode;
  final String? custName;
  final String? saleCode;
  final String? saleFullname;
  final String? saleNickname;
  final String? currencyCode;
  final double totalAmount;
  final double totalAmount2;
  final double totalBeforeVat;
  final double totalVatValue;
  final int? cancelType;

  const DailySalesRow({
    required this.docNo,
    required this.docDate,
    this.docTime,
    this.custCode,
    this.custName,
    this.saleCode,
    this.saleFullname,
    this.saleNickname,
    this.currencyCode,
    this.totalAmount = 0,
    this.totalAmount2 = 0,
    this.totalBeforeVat = 0,
    this.totalVatValue = 0,
    this.cancelType,
  });

  factory DailySalesRow.fromJson(Map<String, dynamic> j) => DailySalesRow(
        docNo: j['docNo'] as String? ?? '',
        docDate: j['docDate'] as String? ?? '',
        docTime: j['docTime'] as String?,
        custCode: j['custCode'] as String?,
        custName: j['custName'] as String?,
        saleCode: j['saleCode'] as String?,
        saleFullname: j['saleFullname'] as String?,
        saleNickname: j['saleNickname'] as String?,
        currencyCode: j['currencyCode'] as String?,
        totalAmount: _toDouble(j['totalAmount']),
        totalAmount2: _toDouble(j['totalAmount2']),
        totalBeforeVat: _toDouble(j['totalBeforeVat']),
        totalVatValue: _toDouble(j['totalVatValue']),
        cancelType: (j['cancelType'] as num?)?.toInt(),
      );
}

// ── Item analytics ─────────────────────────────────────────────────────

class ItemAnalyticsRow {
  final String itemCode;
  final String? itemName;
  final String? unitName;
  final String? brandName;
  final int orderCount;
  final double totalQty;
  final double totalAmount;

  const ItemAnalyticsRow({
    required this.itemCode,
    this.itemName,
    this.unitName,
    this.brandName,
    this.orderCount = 0,
    this.totalQty = 0,
    this.totalAmount = 0,
  });

  factory ItemAnalyticsRow.fromJson(Map<String, dynamic> j) => ItemAnalyticsRow(
        itemCode: j['itemCode'] as String? ?? '',
        itemName: j['itemName'] as String?,
        unitName: j['unitName'] as String?,
        brandName: j['brandName'] as String?,
        orderCount: (j['orderCount'] as num?)?.toInt() ?? 0,
        totalQty: _toDouble(j['totalQty']),
        totalAmount: _toDouble(j['totalAmount']),
      );
}

// ── Daily payment settlement ──────────────────────────────────────────

class DailyPaymentTotals {
  final int receiptsActive;
  final int receiptsCancelled;
  final double kipActive;
  final double kipCancelled;

  const DailyPaymentTotals({
    this.receiptsActive = 0,
    this.receiptsCancelled = 0,
    this.kipActive = 0,
    this.kipCancelled = 0,
  });

  factory DailyPaymentTotals.fromJson(Map<String, dynamic> j) =>
      DailyPaymentTotals(
        receiptsActive: (j['receiptsActive'] as num?)?.toInt() ?? 0,
        receiptsCancelled: (j['receiptsCancelled'] as num?)?.toInt() ?? 0,
        kipActive: _toDouble(j['kipActive']),
        kipCancelled: _toDouble(j['kipCancelled']),
      );
}

class DailyPaymentRow {
  final String docNo;
  final String docDate;
  final String? docTime;
  final String? custCode;
  final String? custName;
  final String? saleCode;
  final String? salespersonName;
  final double totalAmountKip;
  final bool isCancelled;
  // currency:method → kip. Same 4 keys the server returns:
  // "01:cash", "01:transfer", "02:cash", "02:transfer".
  final Map<String, double> breakdown;
  final int slipCount;

  const DailyPaymentRow({
    required this.docNo,
    required this.docDate,
    this.docTime,
    this.custCode,
    this.custName,
    this.saleCode,
    this.salespersonName,
    this.totalAmountKip = 0,
    this.isCancelled = false,
    this.breakdown = const {},
    this.slipCount = 0,
  });

  factory DailyPaymentRow.fromJson(Map<String, dynamic> j) {
    final raw = (j['breakdown'] as Map<String, dynamic>?) ?? const {};
    final breakdown = <String, double>{};
    raw.forEach((k, v) => breakdown[k] = _toDouble(v));
    return DailyPaymentRow(
      docNo: j['docNo'] as String? ?? '',
      docDate: j['docDate'] as String? ?? '',
      docTime: j['docTime'] as String?,
      custCode: j['custCode'] as String?,
      custName: j['custName'] as String?,
      saleCode: j['saleCode'] as String?,
      salespersonName: j['salespersonName'] as String?,
      totalAmountKip: _toDouble(j['totalAmountKip']),
      isCancelled: j['isCancelled'] as bool? ?? false,
      breakdown: breakdown,
      slipCount: (j['slipCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// Member directory row — for the read-only member list screen.
class MemberSummary {
  final String id;
  final String? code;
  final String name;
  final String? phone;
  final String? tier;
  final double totalSpent;
  final double pointsBalance;
  final DateTime? lastVisitAt;

  const MemberSummary({
    required this.id,
    this.code,
    required this.name,
    this.phone,
    this.tier,
    this.totalSpent = 0,
    this.pointsBalance = 0,
    this.lastVisitAt,
  });

  factory MemberSummary.fromJson(Map<String, dynamic> j) => MemberSummary(
        id: j['id']?.toString() ?? '',
        code: j['code'] as String?,
        name: j['name'] as String? ?? '—',
        phone: j['phone'] as String?,
        tier: j['tier'] as String?,
        totalSpent: _toDouble(j['totalSpent']),
        pointsBalance: _toDouble(j['pointsBalance']),
        lastVisitAt: j['lastVisitAt'] != null
            ? DateTime.tryParse(j['lastVisitAt'].toString())
            : null,
      );
}
