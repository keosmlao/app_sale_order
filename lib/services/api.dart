import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

// Wall-clock budget for any single HTTP call. Anything longer is treated as
// "server unreachable" — better than spinning forever when wifi is flaky.
const Duration _kRequestTimeout = Duration(seconds: 15);

// Translate low-level network errors into ApiException with statusCode 0 so
// callers don't need to know about SocketException / TimeoutException etc.
// Returning statusCode 0 is the convention for "never reached server".
ApiException _translateNetworkError(Object error) {
  if (error is ApiException) return error;
  if (error is SocketException) {
    return ApiException(0, 'ບໍ່ສາມາດເຊື່ອມຕໍ່ກັບ server. ກວດເບິ່ງ URL API ຫຼື ເຄືອຂ່າຍ');
  }
  if (error is TimeoutException) {
    return ApiException(0, 'ການເຊື່ອມຕໍ່ໝົດເວລາ. ກວດເບິ່ງເຄືອຂ່າຍ');
  }
  if (error is HandshakeException) {
    return ApiException(0, 'ບໍ່ສາມາດເຊື່ອມຕໍ່ SSL. ກວດເບິ່ງ URL API');
  }
  if (error is HttpException) {
    return ApiException(0, 'ການເຊື່ອມຕໍ່ບໍ່ສຳເລັດ: ${error.message}');
  }
  if (error is http.ClientException) {
    return ApiException(0, 'ການເຊື່ອມຕໍ່ບໍ່ສຳເລັດ: ${error.message}');
  }
  if (error is FormatException) {
    return ApiException(0, 'ຂໍ້ມູນຈາກ server ບໍ່ຖືກຮູບແບບ');
  }
  return ApiException(0, 'ການເຊື່ອມຕໍ່ມີຂໍ້ຜິດພາດ: $error');
}

class ApiClient {
  ApiClient({this.token, String? baseUrl})
    : baseUrl = baseUrl ?? AppConfig.defaultApiBaseUrl;

  String? token;
  String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: {...base.queryParameters, ...query});
  }

  Map<String, String> _headers({bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── HTTP wrappers ─────────────────────────────────────────────
  // Every endpoint method calls one of these instead of http.X directly.
  // They (1) enforce a timeout and (2) translate connection failures into
  // ApiException with a Lao message that UI can show as-is.

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) async {
    try {
      return await http.get(url, headers: headers).timeout(_kRequestTimeout);
    } catch (e) {
      throw _translateNetworkError(e);
    }
  }

  Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await http
          .post(url, headers: headers, body: body)
          .timeout(_kRequestTimeout);
    } catch (e) {
      throw _translateNetworkError(e);
    }
  }

  Future<http.Response> _patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await http
          .patch(url, headers: headers, body: body)
          .timeout(_kRequestTimeout);
    } catch (e) {
      throw _translateNetworkError(e);
    }
  }

  Future<http.Response> _delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await http
          .delete(url, headers: headers, body: body)
          .timeout(_kRequestTimeout);
    } catch (e) {
      throw _translateNetworkError(e);
    }
  }

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    final msg = body is Map && body['error'] is String
        ? body['error'] as String
        : 'HTTP ${res.statusCode}';
    throw ApiException(res.statusCode, msg);
  }

  Future<({String token, Employee employee})> login(
    String code,
    String password,
  ) async {
    final res = await _post(
      _uri('/api/auth/login'),
      headers: _headers(json: true),
      body: jsonEncode({'code': code, 'password': password}),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      employee: Employee.fromJson(data['employee'] as Map<String, dynamic>),
    );
  }

  Future<Employee> me() async {
    final res = await _get(_uri('/api/auth/me'), headers: _headers());
    return Employee.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<List<Employee>> listEmployees() async {
    final res = await _get(_uri('/api/employees'), headers: _headers());
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => Employee.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MyStats> fetchMyStats() async {
    final res = await _get(_uri('/api/me/stats'), headers: _headers());
    return MyStats.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<List<Product>> listProducts() async {
    final res = await _get(_uri('/api/products'), headers: _headers());
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Warehouse>> listWarehouses() async {
    final res = await _get(
      _uri('/api/warehouses', {'salesOnly': '1'}),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => Warehouse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransportType>> listTransportTypes() async {
    final res = await _get(
      _uri('/api/transport-types'),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => TransportType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Customer>> listCustomers({String? q, int? limit}) async {
    final params = <String, String>{};
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (limit != null) params['limit'] = limit.toString();
    final res = await _get(
      _uri('/api/customers', params),
      headers: _headers(),
    );
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LoyaltyConfig> getLoyaltyConfig() async {
    final res = await _get(
      _uri('/api/loyalty/config'),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    final config = data['config'];
    if (config is Map<String, dynamic>) {
      return LoyaltyConfig.fromJson(config);
    }
    return const LoyaltyConfig();
  }

  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final res = await _post(
      _uri('/api/customers'),
      headers: _headers(json: true),
      body: jsonEncode({
        'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
      }),
    );
    return Customer.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<List<SaleOrder>> listOrders() async {
    final res = await _get(_uri('/api/orders'), headers: _headers());
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => SaleOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SaleOrder> createOrder({
    required String customerId,
    String? warehouseCode,
    required String deliveryName,
    double discountPct = 0,
    double extraDiscount = 0,
    String? note,
    String? salespersonCode,
    required List<
      ({
        String productId,
        int quantity,
        String? warehouseCode,
        String? locationCode,
        String? salespersonCode,
      })
    >
    items,
    // Inline cart-bound price requests now only carry product + reason;
    // the manager fills in the approved price when they decide.
    List<({String productId, String? reason})> priceRequests = const [],
    // Per-item promotion choice: itemCode → promoId, or null to opt out.
    // Absent entries fall back to the server's default promo application.
    Map<String, String?> promoSelections = const {},
  }) async {
    final res = await _post(
      _uri('/api/orders'),
      headers: _headers(json: true),
      body: jsonEncode({
        'customerId': customerId,
        if (warehouseCode != null && warehouseCode.trim().isNotEmpty)
          'warehouseCode': warehouseCode.trim(),
        'deliveryName': deliveryName,
        'discountPct': discountPct,
        if (extraDiscount > 0) 'extraDiscount': extraDiscount,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (salespersonCode != null && salespersonCode.trim().isNotEmpty)
          'salespersonCode': salespersonCode.trim(),
        'items': items
            .map(
              (i) => {
                'productId': i.productId,
                'quantity': i.quantity,
                if (i.warehouseCode != null &&
                    i.warehouseCode!.trim().isNotEmpty)
                  'warehouseCode': i.warehouseCode!.trim(),
                if (i.locationCode != null && i.locationCode!.trim().isNotEmpty)
                  'locationCode': i.locationCode!.trim(),
                if (i.salespersonCode != null &&
                    i.salespersonCode!.trim().isNotEmpty)
                  'salespersonCode': i.salespersonCode!.trim(),
              },
            )
            .toList(),
        if (priceRequests.isNotEmpty)
          'priceRequests': priceRequests
              .map(
                (r) => {
                  'productId': r.productId,
                  if (r.reason != null && r.reason!.trim().isNotEmpty)
                    'reason': r.reason!.trim(),
                },
              )
              .toList(),
        if (promoSelections.isNotEmpty) 'promoSelections': promoSelections,
      }),
    );
    return SaleOrder.fromJson(_decode(res) as Map<String, dynamic>);
  }

  // Register / refresh this device's FCM token. Called on login and on
  // FCM's token-refresh callback. Backend upserts by token so re-calls from
  // the same device just bump last_seen.
  Future<void> registerFcmToken({
    required String token,
    required String platform, // 'android' | 'ios' | 'web'
  }) async {
    final res = await _post(
      _uri('/api/me/fcm-token'),
      headers: _headers(json: true),
      body: jsonEncode({'token': token, 'platform': platform}),
    );
    _decode(res);
  }

  // Best-effort token cleanup on logout — caller should not block UI on it.
  Future<void> unregisterFcmToken({required String token}) async {
    final res = await _delete(
      _uri('/api/me/fcm-token'),
      headers: _headers(json: true),
      body: jsonEncode({'token': token}),
    );
    _decode(res);
  }

  // Lightweight count for the home-screen badge. Non-managers receive 0
  // (server-side gate), so this is safe to call for any logged-in user.
  Future<int> fetchPriceRequestPendingCount() async {
    final res = await _get(
      _uri('/api/price-requests/count'),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return (data['pending'] as num?)?.toInt() ?? 0;
  }

  // Manager-only — fetch price approval queue.
  Future<List<PriceRequest>> listPriceRequests({
    String status = 'pending',
  }) async {
    final res = await _get(
      _uri('/api/price-requests?status=$status'),
      headers: _headers(),
    );
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => PriceRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Standalone create — used by the dedicated "Price Request" menu BEFORE
  // a sale order exists. The row sits cart-less until either approved (the
  // manager enters the approved price at decision time, then the next
  // matching sale order auto-applies it) or rejected. Requestors only send
  // originalPrice + reason; they never name a target price.
  Future<void> createPriceRequest({
    required String customerCode,
    required String itemCode,
    required double originalPrice,
    required String reason,
  }) async {
    final res = await _post(
      _uri('/api/price-requests'),
      headers: _headers(json: true),
      body: jsonEncode({
        'customerCode': customerCode,
        'itemCode': itemCode,
        'originalPrice': originalPrice,
        'reason': reason.trim(),
      }),
    );
    _decode(res);
  }

  // Look up an already-approved standalone price for (customer, item).
  // Returns null if no approved request exists. Used by the cart flow to
  // auto-apply pre-approved special prices without manager re-approval.
  Future<({double requestedPrice, double originalPrice, String? reason})?>
  fetchApprovedPriceFor({
    required String customerCode,
    required String itemCode,
  }) async {
    final res = await _get(
      _uri(
        '/api/price-requests/approved-for'
        '?customerCode=${Uri.encodeQueryComponent(customerCode)}'
        '&itemCode=${Uri.encodeQueryComponent(itemCode)}',
      ),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    final approved = data['approved'];
    if (approved is! Map<String, dynamic>) return null;
    final requested = (approved['requestedPrice'] as num?)?.toDouble();
    final original = (approved['originalPrice'] as num?)?.toDouble();
    if (requested == null || original == null) return null;
    return (
      requestedPrice: requested,
      originalPrice: original,
      reason: approved['reason'] as String?,
    );
  }

  // Manager-only — approve/reject. `note` is required when rejecting.
  // `approvedPrice` is required when action='approve' and must be > 0 and
  // strictly below the request's originalPrice (the server re-validates).
  Future<void> decidePriceRequest({
    required String id,
    required String action, // 'approve' | 'reject'
    String? note,
    double? approvedPrice,
  }) async {
    final res = await _patch(
      _uri('/api/price-requests/$id'),
      headers: _headers(json: true),
      body: jsonEncode({
        'action': action,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (action == 'approve' && approvedPrice != null)
          'approvedPrice': approvedPrice,
      }),
    );
    _decode(res);
  }

  // List backorders — pending shortfalls written when a cart was confirmed
  // with stock < ordered qty. Filter by status: open | fulfilled | cancelled.
  Future<List<Backorder>> listBackorders({String status = 'open'}) async {
    final res = await _get(
      _uri('/api/backorders?status=$status'),
      headers: _headers(),
    );
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => Backorder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Flip an open backorder to fulfilled/cancelled. MVP: no stock movement
  // happens server-side — this is purely status tracking.
  Future<void> decideBackorder({
    required String id,
    required String action, // 'fulfill' | 'cancel'
  }) async {
    final res = await _patch(
      _uri('/api/backorders/$id'),
      headers: _headers(json: true),
      body: jsonEncode({'action': action}),
    );
    _decode(res);
  }

  // Drives the workflow: PENDING → COMPLETED (via cashier) → PICKING →
  // DELIVERING → DELIVERED, plus cancel/reopen branches for PENDING ↔
  // CANCELLED. `reason` is required server-side for cancel; optional
  // everywhere else.
  // Hard-deletes a PENDING (or unsettled) order. Removes both the
  // ic_trans header and ic_trans_detail lines server-side — used by the
  // "ລົບ Order" button and by the edit-by-replacement flow once the
  // replacement bill has posted successfully.
  Future<void> deleteOrder(String orderId) async {
    final res = await _delete(
      _uri('/api/cashier/orders/$orderId'),
      headers: _headers(),
    );
    _decode(res);
  }

  Future<SaleOrder> updateOrderStatus({
    required String orderId,
    required String
    action, // 'cancel' | 'reopen' | 'pick' | 'deliver' | 'mark-delivered'
    String? reason,
  }) async {
    final res = await _patch(
      _uri('/api/orders/$orderId'),
      headers: _headers(json: true),
      body: jsonEncode({
        'action': action,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }),
    );
    final data = _decode(res) as Map<String, dynamic>;
    // PATCH returns { id, status } — fetch the full order back so callers get
    // a fresh SaleOrder with all fields (items, total, etc.).
    final list = await listOrders();
    final id = data['id'] as String;
    for (final o in list) {
      if (o.id == id) return o;
    }
    throw ApiException(500, 'Updated order not found after status change');
  }

  Future<
    ({
      DateTime syncedAt,
      List<InventoryItem> items,
      List<String> salesWarehouses,
    })
  >
  fetchInventory() async {
    final res = await _get(_uri('/api/inventory'), headers: _headers());
    final data = _decode(res) as Map<String, dynamic>;
    final syncedAt =
        DateTime.tryParse(data['syncedAt']?.toString() ?? '') ?? DateTime.now();
    final items = (data['items'] as List<dynamic>)
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final salesWarehouses =
        (data['salesWarehouses'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    return (syncedAt: syncedAt, items: items, salesWarehouses: salesWarehouses);
  }

  Future<Map<String, double>> fetchCompanyBalances() async {
    final res = await _get(
      _uri('/api/inventory/company-balances'),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>);
    final map = <String, double>{};
    for (final raw in items) {
      final j = raw as Map<String, dynamic>;
      final code = j['code'] as String?;
      if (code == null) continue;
      final bal = j['companyBalance'];
      map[code] = bal is num
          ? bal.toDouble()
          : double.tryParse(bal?.toString() ?? '') ?? 0;
    }
    return map;
  }

  Future<
    ({
      Map<String, double> balanceByCode,
      Map<String, double> minimumByCode,
      List<String> warehouses,
    })
  >
  fetchSalesBalances({List<String>? warehouseFilter}) async {
    final base = _uri('/api/inventory/sales-balances');
    final uri = (warehouseFilter != null && warehouseFilter.isNotEmpty)
        ? base.replace(
            queryParameters: {'warehouses': warehouseFilter.join(',')},
          )
        : base;
    final res = await _get(uri, headers: _headers());
    final data = _decode(res) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>);
    final map = <String, double>{};
    final minimumMap = <String, double>{};
    for (final raw in items) {
      final j = raw as Map<String, dynamic>;
      final code = j['code'] as String?;
      if (code == null) continue;
      final bal = j['salesBalance'];
      map[code] = bal is num
          ? bal.toDouble()
          : double.tryParse(bal?.toString() ?? '') ?? 0;
      final min = j['minimumStock'];
      minimumMap[code] = min is num
          ? min.toDouble()
          : double.tryParse(min?.toString() ?? '') ?? 0;
    }
    final warehouses =
        (data['warehouses'] as List<dynamic>?)?.whereType<String>().toList() ??
        const <String>[];
    return (
      balanceByCode: map,
      minimumByCode: minimumMap,
      warehouses: warehouses,
    );
  }

  Future<List<StockBalance>> fetchStockBalance(
    List<String> codes, {
    List<String>? warehouses,
  }) async {
    if (codes.isEmpty) return const [];
    final res = await _post(
      _uri('/api/inventory/stock-balance'),
      headers: _headers(json: true),
      body: jsonEncode({
        'codes': codes,
        if (warehouses != null && warehouses.isNotEmpty)
          'warehouses': warehouses,
      }),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => StockBalance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductSetDetailItem>> fetchProductSetDetails(
    String productCode,
  ) async {
    final res = await _get(
      _uri('/api/products/${Uri.encodeComponent(productCode)}/set'),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return ((data['items'] as List<dynamic>?) ?? const [])
        .map((e) => ProductSetDetailItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Per-warehouse buildability for a set product (mirrors the web POS
  // set-build modal). Stock is checked component-by-component at the
  // warehouse level since the cashier doesn't pick a shelf location for a
  // set — the server explodes it into components at settle time.
  Future<SetAvailability> fetchSetAvailability(String productCode) async {
    final res = await _get(
      _uri(
        '/api/products/${Uri.encodeComponent(productCode)}/set/availability',
      ),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return SetAvailability.fromJson(data);
  }

  Future<List<Promotion>> fetchActivePromotions() async {
    final uri = _uri('/api/promotions/active');
    final hdrs = _headers();
    debugPrint('[Promo] API Request: GET $uri headers=$hdrs');
    try {
      final res = await _get(uri, headers: hdrs);
      debugPrint('[Promo] API Response status=${res.statusCode} body=${res.body}');
      final data = _decode(res) as List<dynamic>;
      return data
          .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Promo] API Exception: $e');
      rethrow;
    }
  }

  // Fetch a single product by exact code — backs the BOGO bonus auto-add
  // path. Unlike `searchInventory`, this endpoint does NOT filter on
  // balance_qty > 0, so a promo bonus that's temporarily out of stock
  // still resolves and the cashier sees the linked bonus line. Returns
  // null when the SKU genuinely doesn't exist (404).
  Future<InventoryItem?> fetchProductByCode(String code) async {
    final res = await _get(
      _uri('/api/products/${Uri.encodeComponent(code)}'),
      headers: _headers(),
    );
    if (res.statusCode == 404) return null;
    final raw = _decode(res) as Map<String, dynamic>;
    // The /api/products/[id] route returns the web-shaped Product
    // (name/description/price/stock) rather than the InventoryItem
    // contract used elsewhere in the app. Re-key so InventoryItem
    // .fromJson finds what it expects.
    final mapped = <String, dynamic>{
      'code': raw['code'] ?? code,
      'nameLo': raw['name'],
      'nameEng': raw['description'],
      'unitName': raw['unitName'],
      'brand': raw['brand'],
      'brandName': raw['brandName'],
      'category': raw['category'],
      'categoryName': raw['categoryName'],
      'groupMain': raw['groupMain'],
      'groupMainName': raw['groupMainName'],
      'hasSet': raw['hasSet'] == true,
      'status': raw['status'],
      'itemStatus': raw['itemStatus'],
      'companyBalance': raw['stock'] ?? 0,
      'salesBalance': raw['stock'] ?? 0,
      'salePriceKip': raw['price'] ?? 0,
    };
    return InventoryItem.fromJson(mapped);
  }

  // Lean warehouse+location breakdown for a single item. Fires after the
  // user picks a product so the warehouse picker has fresh stock data —
  // smaller payload + faster query than `fetchStockBalance`.
  Future<List<StockLocationRow>> fetchStockLocations(String code) async {
    final res = await _get(
      _uri('/api/inventory/stock-locations', {'code': code}),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return ((data['locations'] as List<dynamic>?) ?? const [])
        .map((e) => StockLocationRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<InventoryItem>> searchInventory(
    String q, {
    int limit = 10,
    bool includeSets = false,
  }) async {
    final res = await _get(
      _uri('/api/inventory/search', {
        'q': q,
        'limit': limit.toString(),
        if (includeSets) 'sets': '1',
      }),
      headers: _headers(),
    );
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Manager features ──────────────────────────────────────────────────
  // Endpoints that back the Manager Hub. All read-only except where noted.

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Team sales rankings — per-employee totals for the date range.
  Future<({List<SalespersonStats> rows, double grandTotal, int grandOrders})>
      fetchSalespeopleReport({
    required DateTime from,
    required DateTime to,
    String status = 'ACTIVE',
  }) async {
    final res = await _get(
      _uri('/api/reports/salespeople', {
        'from': _ymd(from),
        'to': _ymd(to),
        'status': status,
      }),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    final rows = ((data['rows'] as List<dynamic>?) ?? const [])
        .map((e) => SalespersonStats.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      rows: rows,
      grandTotal: _toDoubleOrZero(data['grandTotal']),
      grandOrders: (data['grandOrders'] as num?)?.toInt() ?? 0,
    );
  }

  // Cashier per-shift activity. Pass `cashier` to scope down to one person.
  Future<List<CashierShiftRow>> fetchCashierShifts({
    required DateTime from,
    required DateTime to,
    String? cashier,
  }) async {
    final query = {
      'from': _ymd(from),
      'to': _ymd(to),
      if (cashier != null && cashier.isNotEmpty) 'cashier': cashier,
    };
    final res = await _get(
      _uri('/api/reports/shift-summary', query),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return ((data['rows'] as List<dynamic>?) ?? const [])
        .map((e) => CashierShiftRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Promotion CRUD ──
  // List/create/update/delete promotions. `fetchActivePromotions()` above
  // is a thin wrapper that the cart uses; this is the manager-facing surface.
  Future<List<Promotion>> listPromotions({
    String? type,
    bool activeOnly = false,
  }) async {
    final query = <String, String>{
      if (type != null && type.isNotEmpty) 'type': type,
      if (activeOnly) 'active': '1',
    };
    final res = await _get(
      _uri('/api/promotions', query.isEmpty ? null : query),
      headers: _headers(),
    );
    final data = _decode(res);
    final list = data is List<dynamic>
        ? data
        : ((data as Map<String, dynamic>)['items'] as List<dynamic>? ?? const []);
    return list
        .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Promotion> getPromotion(String id) async {
    final res = await _get(
      _uri('/api/promotions/${Uri.encodeComponent(id)}'),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return Promotion.fromJson(data);
  }

  Future<Promotion> createPromotion(Map<String, dynamic> body) async {
    final res = await _post(
      _uri('/api/promotions'),
      headers: _headers(json: true),
      body: jsonEncode(body),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return Promotion.fromJson(data);
  }

  Future<Promotion> updatePromotion(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _patch(
      _uri('/api/promotions/${Uri.encodeComponent(id)}'),
      headers: _headers(json: true),
      body: jsonEncode(body),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return Promotion.fromJson(data);
  }

  Future<void> deletePromotion(String id) async {
    final res = await _delete(
      _uri('/api/promotions/${Uri.encodeComponent(id)}'),
      headers: _headers(),
    );
    _decode(res);
  }

  // ── Loyalty config (manager view) ──
  // Wider variant of getLoyaltyConfig() — returns the full record so the
  // manager screen can show redemption settings + audit timestamps.
  Future<LoyaltyConfigManager> fetchLoyaltyConfigManager() async {
    final res = await _get(
      _uri('/api/loyalty/config'),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    final config = data['config'] as Map<String, dynamic>? ?? data;
    return LoyaltyConfigManager.fromJson(config);
  }

  Future<LoyaltyConfigManager> updateLoyaltyConfig({
    double? earnKipPerPoint,
    double? redeemPointsPerKip,
    int? minRedeemPoints,
    String? pointName,
    String? note,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (earnKipPerPoint != null) 'earnKipPerPoint': earnKipPerPoint,
      if (redeemPointsPerKip != null) 'redeemPointsPerKip': redeemPointsPerKip,
      if (minRedeemPoints != null) 'minRedeemPoints': minRedeemPoints,
      if (pointName != null) 'pointName': pointName,
      if (note != null) 'note': note,
      if (isActive != null) 'isActive': isActive,
    };
    final res = await _patch(
      _uri('/api/loyalty/config'),
      headers: _headers(json: true),
      body: jsonEncode(body),
    );
    final data = _decode(res) as Map<String, dynamic>;
    final config = data['config'] as Map<String, dynamic>? ?? data;
    return LoyaltyConfigManager.fromJson(config);
  }

  // ── Stock refill ──
  Future<({
    bool canApprove,
    bool canCreate,
    List<StockRefillItem> items,
    List<StockRefillRequest> requests,
  })> fetchStockRefill({String? warehouse, String? status}) async {
    final query = <String, String>{
      if (warehouse != null && warehouse.isNotEmpty) 'warehouse': warehouse,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final res = await _get(
      _uri('/api/reports/stock-refill', query.isEmpty ? null : query),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return (
      canApprove: data['canApprove'] as bool? ?? false,
      canCreate: data['canCreate'] as bool? ?? false,
      items: ((data['items'] as List<dynamic>?) ?? const [])
          .map((e) => StockRefillItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      requests: ((data['requests'] as List<dynamic>?) ?? const [])
          .map((e) => StockRefillRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<StockRefillRequest> createStockRefill({
    required String warehouseCode,
    required String itemCode,
    required double requestedQty,
    String? reason,
  }) async {
    final res = await _post(
      _uri('/api/reports/stock-refill'),
      headers: _headers(json: true),
      body: jsonEncode({
        'warehouseCode': warehouseCode,
        'itemCode': itemCode,
        'requestedQty': requestedQty,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return StockRefillRequest.fromJson(data);
  }

  Future<StockRefillRequest> actOnStockRefill(
    String id,
    String action, {
    String? note,
    String? refDocNo,
  }) async {
    final res = await _patch(
      _uri('/api/reports/stock-refill/${Uri.encodeComponent(id)}'),
      headers: _headers(json: true),
      body: jsonEncode({
        'action': action,
        if (note != null) 'note': note,
        if (refDocNo != null) 'refDocNo': refDocNo,
      }),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return StockRefillRequest.fromJson(data);
  }

  // ── Promo effectiveness ──
  Future<List<PromoEffectivenessRow>> fetchPromoEffectiveness({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{
      if (from != null) 'from': _ymd(from),
      if (to != null) 'to': _ymd(to),
    };
    final res = await _get(
      _uri('/api/reports/promo-effectiveness', query.isEmpty ? null : query),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return ((data['rows'] as List<dynamic>?) ?? const [])
        .map((e) => PromoEffectivenessRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Members ──
  Future<List<MemberSummary>> searchMembers({
    String? q,
    int limit = 50,
  }) async {
    final query = <String, String>{
      if (q != null && q.isNotEmpty) 'q': q,
      'limit': limit.toString(),
    };
    final res = await _get(
      _uri('/api/members', query),
      headers: _headers(),
    );
    final data = _decode(res);
    final list = data is List<dynamic>
        ? data
        : ((data as Map<String, dynamic>)['items'] as List<dynamic>? ?? const []);
    return list
        .map((e) => MemberSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Daily sales report ──
  // Returns the 4 buckets the report card needs: totals, per-currency,
  // per-salesperson, and the detail rows. Wrapped in a record so callers
  // can destructure cleanly.
  Future<({
    String date,
    DailySalesTotals totals,
    List<DailySalesCurrency> currencies,
    List<DailySalesSalesperson> salespeople,
    List<DailySalesRow> rows,
  })> fetchDailySales({DateTime? date}) async {
    final query = <String, String>{
      if (date != null) 'date': _ymd(date),
    };
    final res = await _get(
      _uri('/api/reports/daily-sales', query.isEmpty ? null : query),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return (
      date: data['date'] as String? ?? '',
      totals: DailySalesTotals.fromJson(
          (data['totals'] as Map<String, dynamic>?) ?? const {}),
      currencies: ((data['currencies'] as List<dynamic>?) ?? const [])
          .map((e) => DailySalesCurrency.fromJson(e as Map<String, dynamic>))
          .toList(),
      salespeople: ((data['salespeople'] as List<dynamic>?) ?? const [])
          .map((e) => DailySalesSalesperson.fromJson(e as Map<String, dynamic>))
          .toList(),
      rows: ((data['rows'] as List<dynamic>?) ?? const [])
          .map((e) => DailySalesRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Item analytics — top-selling items in a date range.
  Future<({
    List<ItemAnalyticsRow> rows,
    double grandTotal,
    double grandQty,
  })> fetchItemAnalytics({
    DateTime? from,
    DateTime? to,
    String status = 'ACTIVE',
    int limit = 50,
    String? q,
  }) async {
    final query = <String, String>{
      if (from != null) 'from': _ymd(from),
      if (to != null) 'to': _ymd(to),
      'status': status,
      'limit': limit.toString(),
      if (q != null && q.isNotEmpty) 'q': q,
    };
    final res = await _get(
      _uri('/api/reports/items', query),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    return (
      rows: ((data['rows'] as List<dynamic>?) ?? const [])
          .map((e) => ItemAnalyticsRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      grandTotal: _toDoubleOrZero(data['grandTotal']),
      grandQty: _toDoubleOrZero(data['grandQty']),
    );
  }

  // Daily payment settlement — per-receipt breakdown for one day.
  Future<({
    String date,
    DailyPaymentTotals totals,
    Map<String, double> breakdown,
    List<DailyPaymentRow> rows,
  })> fetchDailyPayments({DateTime? date}) async {
    final query = <String, String>{
      if (date != null) 'date': _ymd(date),
    };
    final res = await _get(
      _uri('/api/reports/daily-payments', query.isEmpty ? null : query),
      headers: _headers(),
    );
    final data = _decode(res) as Map<String, dynamic>;
    final rawBreakdown = (data['breakdown'] as Map<String, dynamic>?) ?? const {};
    final breakdown = <String, double>{};
    rawBreakdown.forEach((k, v) => breakdown[k] = _toDoubleOrZero(v));
    return (
      date: data['date'] as String? ?? '',
      totals: DailyPaymentTotals.fromJson(
          (data['totals'] as Map<String, dynamic>?) ?? const {}),
      breakdown: breakdown,
      rows: ((data['rows'] as List<dynamic>?) ?? const [])
          .map((e) => DailyPaymentRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Local helper — model files don't share their _toDouble; this avoids
  // pulling json values into doubles inline at every endpoint above.
  static double _toDoubleOrZero(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
