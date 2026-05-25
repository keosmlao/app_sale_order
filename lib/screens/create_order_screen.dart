import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/api.dart';
import 'barcode_scanner_screen.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  // Delivery / transport types come from /api/transport-types
  // (legacy public.transport_type table). Loaded once during bootstrap and
  // kept in state so the picker stays in sync with the back-office list.
  List<TransportType> _deliveries = const [];

  final _fmt = NumberFormat('#,###', 'en_US');
  final _moneyFmt = NumberFormat('#,###.##', 'en_US');
  final _searchCtl = TextEditingController();

  List<InventoryItem> _items = const [];
  // Small server-loaded product set. The app no longer caches/preloads the
  // full inventory; the picker performs server-side search. Normal searches
  // limit to 10; the air query returns every set.
  List<InventoryItem> _allItems = const [];
  List<Customer> _customers = const [];
  List<Warehouse> _warehouses = const [];
  List<Employee> _employees = const [];
  LoyaltyConfig _loyaltyConfig = const LoyaltyConfig();
  Map<String, double> _stockByLineKey = const {};
  bool _loading = true;
  bool _stockLoading = false;
  bool _inventorySyncing = false;

  Customer? _selectedCustomer;
  TransportType? _selectedDelivery;
  Employee? _selectedSalesperson;
  final Map<String, int> _qtyByCode = {};
  final Map<String, Warehouse> _warehouseByItemCode = {};
  final Map<String, StockLocation> _locationByItemCode = {};
  bool _submitting = false;
  // Wizard step: 0 = pick customer, 1 = build cart, 2 = finalize (salesperson
  // + delivery + save). Back arrow on the app bar walks the user back one
  // step rather than popping the whole screen, except on step 0.
  int _step = 0;
  // Bill-level extras: applied AFTER the customer's per-line discount. The
  // note is stored in order_cart.remark together with delivery info.
  double _extraDiscount = 0;
  String _note = '';
  // Approved standalone price overrides, keyed by item code. Populated at
  // add-to-cart time by `_fetchApprovedPriceFor`. When present, this price
  // replaces `InventoryItem.salePriceKip` everywhere in the cart math.
  final Map<String, double> _approvedPriceByCode = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (mounted) setState(() => _loading = false);
    await _loadCustomersAndWarehouses();
    if (mounted) await _syncInventory();
  }

  Future<void> _loadCustomersAndWarehouses() async {
    final scope = AppScope.of(context);
    final api = scope.api;
    final me = scope.auth.employee;
    const timeout = Duration(seconds: 10);
    Future<T> safe<T>(Future<T> Function() fn, T fallback) async {
      try {
        return await fn().timeout(timeout);
      } catch (e) {
        debugPrint('CreateOrder: API failed → $e');
        return fallback;
      }
    }

    final results = await Future.wait([
      // Initial load is a small batch (top 200) so the screen opens fast
      // even on slow networks. The full member book (~16k rows, ~2.5 MB) is
      // never preloaded — the picker fetches on demand via server-side
      // search keyed on the search box.
      safe<List<Customer>>(
        () => api.listCustomers(limit: 200),
        const <Customer>[],
      ),
      safe<List<Warehouse>>(api.listWarehouses, const <Warehouse>[]),
      safe<List<Employee>>(api.listEmployees, const <Employee>[]),
      safe<List<TransportType>>(
        api.listTransportTypes,
        const <TransportType>[],
      ),
      safe<LoyaltyConfig>(api.getLoyaltyConfig, const LoyaltyConfig()),
    ]);
    if (!mounted) return;
    final warehouses = results[1] as List<Warehouse>;
    final employees = results[2] as List<Employee>;
    final deliveries = results[3] as List<TransportType>;
    final loyaltyConfig = results[4] as LoyaltyConfig;
    // Default salesperson = the logged-in user, so single-seller shops don't
    // have to touch the picker. Falls back to the matching record from the
    // employees list (which has full names) when possible.
    Employee? defaultSp;
    if (me?.employeeCode != null) {
      for (final e in employees) {
        if (e.employeeCode == me!.employeeCode) {
          defaultSp = e;
          break;
        }
      }
      defaultSp ??= me;
    }
    setState(() {
      _customers = results[0] as List<Customer>;
      _warehouses = warehouses;
      _employees = employees;
      _deliveries = deliveries;
      _loyaltyConfig = loyaltyConfig;
      _selectedSalesperson ??= defaultSp;
    });
  }

  Future<void> _syncInventory({bool showErrorToast = true}) async {
    final api = AppScope.of(context).api;
    if (mounted) setState(() => _inventorySyncing = true);
    try {
      // Sole source of truth for the card stock = ic_inventory.balance_qty
      // (returned as companyBalance by /api/inventory/search). Load only the
      // first 10 rows; typed search also stays server-side. Normal searches
      // limit to 10; the air query returns every set.
      final rows = await api
          .searchInventory('', limit: 10)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _items = rows;
        _allItems = rows;
      });
    } catch (e) {
      debugPrint('CreateOrder: inventory sync failed → $e');
      if (mounted && showErrorToast) {
        _toast('ໂຫຼດສິນຄ້າບໍ່ສຳເລັດ: $e');
      }
    } finally {
      if (mounted) setState(() => _inventorySyncing = false);
    }
  }

  // Approved standalone price (from /api/price-requests/approved-for) wins
  // over the catalog price. Used wherever the cart math touches a unit price.
  double _unitPrice(InventoryItem item) =>
      _approvedPriceByCode[item.code] ?? item.salePriceKip;

  double get _discountPct => _selectedCustomer?.discountPct ?? 0;
  double _lineDiscountAmount(InventoryItem item, int qty) =>
      _unitPrice(item) * qty * (_discountPct / 100);
  double _lineTotal(InventoryItem item, int qty) =>
      (_unitPrice(item) * qty) - _lineDiscountAmount(item, qty);

  double get _discountAmount {
    double t = 0;
    for (final entry in _qtyByCode.entries) {
      final item = _itemByCode(entry.key);
      if (item != null) t += _lineDiscountAmount(item, entry.value);
    }
    return t;
  }

  double get _lineNetTotal {
    double t = 0;
    for (final entry in _qtyByCode.entries) {
      final item = _itemByCode(entry.key);
      if (item != null) t += _lineTotal(item, entry.value);
    }
    return t;
  }

  // Bill discount cannot push the total negative; the backend clamps too but
  // we also clamp in the UI so totals stay coherent while the user edits.
  double get _appliedExtraDiscount {
    if (_extraDiscount <= 0) return 0;
    return _extraDiscount > _lineNetTotal ? _lineNetTotal : _extraDiscount;
  }

  double get _total => _lineNetTotal - _appliedExtraDiscount;

  int get _earnedPoints {
    if (!_loyaltyConfig.isActive ||
        _total <= 0 ||
        _loyaltyConfig.earnKipPerPoint <= 0) {
      return 0;
    }
    return (_total / _loyaltyConfig.earnKipPerPoint).floor();
  }

  int get _totalQty => _qtyByCode.values.fold(0, (a, b) => a + b);
  int get _selectedLineCount => _qtyByCode.length;

  InventoryItem? _itemByCode(String code) {
    for (final i in _items) {
      if (i.code == code) return i;
    }
    return null;
  }

  List<InventoryItem> get _selectedItems =>
      _qtyByCode.keys.map(_itemByCode).whereType<InventoryItem>().toList();

  bool get _canSubmit =>
      _selectedCustomer != null &&
      _selectedDelivery != null &&
      _qtyByCode.isNotEmpty &&
      _qtyByCode.keys.every(
        (code) =>
            _warehouseByItemCode[code] != null &&
            (_locationByItemCode[code]?.location?.trim().isNotEmpty ?? false),
      );

  // Pick a sensible default delivery from the loaded list based on the
  // warehouse code prefix. Falls back to the first option when no prefix
  // match exists (or to the current selection if delivery types haven't
  // loaded yet).
  TransportType? _defaultDeliveryForWarehouse(Warehouse? warehouse) {
    if (_deliveries.isEmpty) return _selectedDelivery;
    final code = warehouse?.code.trim() ?? '';
    if (code.startsWith('11')) {
      final match = _deliveries.firstWhere(
        (d) => d.code.toLowerCase().contains('khualuang'),
        orElse: () => _deliveries.first,
      );
      return match;
    }
    if (code.startsWith('12')) {
      final match = _deliveries.firstWhere(
        (d) => d.code.toLowerCase().contains('dontiew'),
        orElse: () => _deliveries.first,
      );
      return match;
    }
    return _selectedDelivery ?? _deliveries.first;
  }

  String _lineStockKey(
    String itemCode,
    String warehouseCode,
    String locationCode,
  ) => '$warehouseCode\x1f$locationCode\x1f$itemCode';

  // -1 means "warehouse not chosen yet"; the cart line then shows a warehouse
  // picker chip and uses companyBalance as the temporary max quantity.
  double _itemStock(InventoryItem item) {
    final wh = _warehouseByItemCode[item.code];
    final loc = _locationByItemCode[item.code]?.location?.trim();
    if (wh == null) return -1;
    if (loc == null || loc.isEmpty) return -1;
    return _stockByLineKey[_lineStockKey(item.code, wh.code, loc)] ?? -1;
  }

  Future<void> _refreshStockForCodes(
    Iterable<String> codes, {
    bool force = false,
  }) async {
    final byWarehouse = <String, List<String>>{};
    for (final code in codes.where((code) => code.trim().isNotEmpty)) {
      final wh = _warehouseByItemCode[code];
      final loc = _locationByItemCode[code]?.location?.trim();
      if (wh == null) continue;
      if (loc == null || loc.isEmpty) continue;
      final key = _lineStockKey(code, wh.code, loc);
      if (!force && _stockByLineKey[key] != null) continue;
      (byWarehouse[wh.code] ??= <String>[]).add(code);
    }
    if (byWarehouse.isEmpty) return;

    if (mounted) setState(() => _stockLoading = true);
    try {
      final next = Map<String, double>.of(_stockByLineKey);
      for (final entry in byWarehouse.entries) {
        final warehouseCode = entry.key;
        final itemCodes = entry.value.toSet().toList();
        final balances = await AppScope.of(
          context,
        ).api.fetchStockBalance(itemCodes, warehouses: [warehouseCode]);
        if (!mounted) return;
        for (final code in itemCodes) {
          final loc = _locationByItemCode[code]?.location?.trim();
          if (loc != null && loc.isNotEmpty) {
            next[_lineStockKey(code, warehouseCode, loc)] = 0;
          }
        }
        for (final balance in balances) {
          for (final loc in balance.locations) {
            final locationCode = loc.location?.trim();
            if (locationCode == null || locationCode.isEmpty) continue;
            next[_lineStockKey(balance.code, warehouseCode, locationCode)] =
                loc.balanceQty;
          }
        }
      }
      setState(() => _stockByLineKey = next);
    } catch (e) {
      debugPrint('CreateOrder: item stock sync failed → $e');
      if (mounted) _toast('ດຶງ stock ສິນຄ້າບໍ່ສຳເລັດ: $e');
    } finally {
      if (mounted) setState(() => _stockLoading = false);
    }
  }

  Future<bool> _setQty(InventoryItem item, int qty) async {
    // Removing / clearing — no stock check needed.
    if (qty <= 0) {
      setState(() {
        _qtyByCode.remove(item.code);
        _warehouseByItemCode.remove(item.code);
        _locationByItemCode.remove(item.code);
        _approvedPriceByCode.remove(item.code);
      });
      return true;
    }

    // First time this item enters the cart → look up any approved standalone
    // price for (customer, item) and pin it. Subsequent qty edits skip the
    // lookup. Failure is non-fatal — we just fall back to catalog price.
    final isFirstAdd = !_qtyByCode.containsKey(item.code);
    if (isFirstAdd &&
        _selectedCustomer != null &&
        !_approvedPriceByCode.containsKey(item.code)) {
      try {
        final approved = await AppScope.of(context).api.fetchApprovedPriceFor(
          customerCode: _selectedCustomer!.id,
          itemCode: item.code,
        );
        if (!mounted) return false;
        if (approved != null &&
            approved.requestedPrice > 0 &&
            approved.requestedPrice < item.salePriceKip) {
          _approvedPriceByCode[item.code] = approved.requestedPrice;
          _toast(
            'ໃຊ້ລາຄາທີ່ໄດ້ຮັບອະນຸມັດ ${_moneyFmt.format(approved.requestedPrice)} ກີບ ສຳລັບ ${item.nameLo}',
          );
        }
      } catch (e) {
        debugPrint('CreateOrder: approved-price lookup failed → $e');
      }
    }

    if (_warehouseByItemCode[item.code] == null ||
        _locationByItemCode[item.code] == null) {
      final picked = await _promptWarehouseForItem(item);
      if (picked == null || !mounted) return false;
      setState(() {
        _selectedDelivery ??= _defaultDeliveryForWarehouse(picked.warehouse);
        _warehouseByItemCode[item.code] = picked.warehouse;
        _locationByItemCode[item.code] = picked.location;
        final locationCode = picked.location.location?.trim() ?? '';
        _stockByLineKey = {
          ..._stockByLineKey,
          _lineStockKey(item.code, picked.warehouse.code, locationCode):
              picked.stock,
        };
      });
    } else if (_itemStock(item) < 0) {
      await _refreshStockForCodes([item.code]);
      if (!mounted) return false;
    }

    // Backorder is allowed — we no longer reject when stock < qty. The
    // shortfall is shown inline on the cart row and the server writes an
    // app_backorder row when the order is created.
    setState(() {
      if (!_allItems.any((p) => p.code == item.code)) {
        _allItems = [..._allItems, item];
      }
      if (!_items.any((p) => p.code == item.code) && item.companyBalance > 0) {
        _items = [..._items, item];
      }
      _qtyByCode[item.code] = qty < 1 ? 1 : qty;
    });
    return true;
  }

  Future<void> _pickWarehouseForLine(InventoryItem item) async {
    final picked = await _promptWarehouseForItem(item);
    if (picked == null || !mounted) return;
    final currentQty = _qtyByCode[item.code] ?? 1;
    setState(() {
      _selectedDelivery ??= _defaultDeliveryForWarehouse(picked.warehouse);
      _warehouseByItemCode[item.code] = picked.warehouse;
      _locationByItemCode[item.code] = picked.location;
      final locationCode = picked.location.location?.trim() ?? '';
      _stockByLineKey = {
        ..._stockByLineKey,
        _lineStockKey(item.code, picked.warehouse.code, locationCode):
            picked.stock,
      };
      _qtyByCode[item.code] = currentQty < 1 ? 1 : currentQty;
    });
  }

  // Fetches stock for a single item across all warehouses, then lets the user
  // choose the source warehouse from that item's cart line.
  Future<_PickedWarehouseStock?> _promptWarehouseForItem(
    InventoryItem item,
  ) async {
    setState(() => _stockLoading = true);
    List<_WarehouseStockOption> options = const [];
    try {
      options = _isSetItem(item)
          ? await _warehouseOptionsForSetItem(item)
          : await _warehouseOptionsForSingleItem(item);
    } catch (e) {
      if (mounted) _toast('ດຶງ stock ສິນຄ້າບໍ່ສຳເລັດ: $e');
      return null;
    } finally {
      if (mounted) setState(() => _stockLoading = false);
    }
    if (!mounted) return null;

    if (options.isEmpty) {
      _toast('ສິນຄ້າ "${item.nameLo}" ບໍ່ມີ stock ໃນທຸກສາງ');
      return null;
    }
    options.sort((a, b) => b.stock.compareTo(a.stock));

    final picked = await showModalBottomSheet<_WarehouseStockOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _WarehouseStockPickerSheet(item: item, options: options, fmt: _fmt),
    );
    if (picked == null) return null;
    return _PickedWarehouseStock(
      warehouse: picked.warehouse,
      location: picked.location,
      stock: picked.stock,
    );
  }

  bool _isSetItem(InventoryItem item) {
    final unit = item.unitName?.trim();
    return item.hasSet || unit == 'ຊຸດ';
  }

  Future<List<_WarehouseStockOption>> _warehouseOptionsForSingleItem(
    InventoryItem item,
  ) async {
    List<StockLocation> locations = const [];
    final balances = await AppScope.of(
      context,
    ).api.fetchStockBalance([item.code]);
    if (balances.isNotEmpty) {
      locations = balances.first.locations;
    }
    final options = <_WarehouseStockOption>[];
    for (final loc in locations) {
      final code = loc.warehouse?.trim();
      if (code == null || code.isEmpty) continue;
      final locationCode = loc.location?.trim();
      if (locationCode == null || locationCode.isEmpty) continue;
      if (loc.balanceQty <= 0) continue;
      final wh = _warehouseByCode(code);
      if (wh == null) continue;
      options.add(
        _WarehouseStockOption(
          warehouse: wh,
          location: loc,
          stock: loc.balanceQty,
        ),
      );
    }
    return options;
  }

  Future<List<_WarehouseStockOption>> _warehouseOptionsForSetItem(
    InventoryItem item,
  ) async {
    final api = AppScope.of(context).api;
    final details = (await api.fetchProductSetDetails(
      item.code,
    )).where((d) => d.itemCode.trim().isNotEmpty && d.quantity > 0).toList();
    if (details.isEmpty) return const [];

    final componentCodes = details.map((d) => d.itemCode).toSet().toList();
    final balances = await api.fetchStockBalance(componentCodes);
    final byCodeAndLocation = <String, Map<String, StockLocation>>{};
    final allLocationKeys = <String>{};

    for (final balance in balances) {
      final code = balance.code.trim();
      if (code.isEmpty) continue;
      final locationMap = byCodeAndLocation.putIfAbsent(
        code,
        () => <String, StockLocation>{},
      );
      for (final loc in balance.locations) {
        final warehouseCode = loc.warehouse?.trim();
        final locationCode = loc.location?.trim();
        if (warehouseCode == null ||
            warehouseCode.isEmpty ||
            locationCode == null ||
            locationCode.isEmpty ||
            loc.balanceQty <= 0) {
          continue;
        }
        final key = _warehouseLocationKey(warehouseCode, locationCode);
        locationMap[key] = loc;
        allLocationKeys.add(key);
      }
    }

    final options = <_WarehouseStockOption>[];
    for (final key in allLocationKeys) {
      final parts = _splitWarehouseLocationKey(key);
      if (parts == null) continue;
      final warehouse = _warehouseByCode(parts.warehouseCode);
      if (warehouse == null) continue;

      var setStock = double.infinity;
      StockLocation? displayLocation;
      var canBuildSet = true;
      for (final detail in details) {
        final loc = byCodeAndLocation[detail.itemCode]?[key];
        if (loc == null || loc.balanceQty < detail.quantity) {
          canBuildSet = false;
          break;
        }
        final availableSets = loc.balanceQty / detail.quantity;
        if (availableSets < setStock) {
          setStock = availableSets;
          displayLocation = loc;
        }
      }
      if (!canBuildSet || displayLocation == null || setStock < 1) continue;
      final wholeSetStock = setStock.floorToDouble();
      options.add(
        _WarehouseStockOption(
          warehouse: warehouse,
          location: StockLocation(
            warehouse: displayLocation.warehouse,
            warehouseName: displayLocation.warehouseName,
            location: displayLocation.location,
            locationName: displayLocation.locationName,
            balanceQty: wholeSetStock,
            unitCode: 'ຊຸດ',
            averageCost: displayLocation.averageCost,
            averageCostEnd: displayLocation.averageCostEnd,
            balanceAmount: displayLocation.balanceAmount,
          ),
          stock: wholeSetStock,
        ),
      );
    }
    return options;
  }

  String _warehouseLocationKey(String warehouseCode, String locationCode) =>
      '$warehouseCode\u0000$locationCode';

  ({String warehouseCode, String locationCode})? _splitWarehouseLocationKey(
    String key,
  ) {
    final parts = key.split('\u0000');
    if (parts.length != 2) return null;
    return (warehouseCode: parts[0], locationCode: parts[1]);
  }

  Warehouse? _warehouseByCode(String code) {
    for (final w in _warehouses) {
      if (w.code == code) return w;
    }
    return null;
  }

  Future<void> _pickCustomer() async {
    final me = AppScope.of(context).auth.employee;
    final canCreate = me?.canCreateCustomers ?? false;
    final picked = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CustomerPickerSheet(
        customers: _customers,
        // PC and salesperson can pick but not create. Backend also enforces.
        onCreate: canCreate
            ? ({
                required String name,
                String? phone,
                String? email,
                String? address,
              }) async {
                final created = await AppScope.of(context).api.createCustomer(
                  name: name,
                  phone: phone,
                  email: email,
                  address: address,
                );
                if (mounted) {
                  setState(() => _customers = [created, ..._customers]);
                }
                return created;
              }
            : null,
      ),
    );
    if (picked != null) {
      setState(() => _selectedCustomer = picked);
    }
  }

  Future<void> _pickDelivery() async {
    if (_deliveries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ກຳລັງໂຫລດປະເພດການຮັບສິນຄ້າ...')),
      );
      return;
    }
    final picked = await showModalBottomSheet<TransportType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DeliveryPickerSheet(
        options: _deliveries,
        selectedCode: _selectedDelivery?.code,
      ),
    );
    if (picked != null) setState(() => _selectedDelivery = picked);
  }

  Future<void> _pickSalesperson() async {
    final picked = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SalespersonPickerSheet(
        employees: _employees,
        selectedCode: _selectedSalesperson?.employeeCode,
      ),
    );
    if (picked != null) setState(() => _selectedSalesperson = picked);
  }

  Future<void> _openProductPicker() async {
    if (_items.isEmpty) {
      if (_inventorySyncing) {
        _toast('ກຳລັງໂຫຼດສິນຄ້າ, ກະລຸນາລໍຖ້າ...');
        return;
      }
      _toast('ບໍ່ມີສິນຄ້າ — ກຳລັງດຶງຄືນໃໝ່');
      await _syncInventory();
      if (!mounted || _items.isEmpty) return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductPickerSheet(
        items: _items,
        allItems: _allItems,
        qtyByCode: _qtyByCode,
        stockOf: _itemStock,
        stockLoading: _stockLoading,
        fmt: _moneyFmt,
        onChangeQty: _setQty,
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final value = code.trim();
    final lower = value.toLowerCase();
    InventoryItem? found;
    for (final i in _items) {
      if (i.code == value || i.code.toLowerCase() == lower) {
        found = i;
        break;
      }
    }
    if (found == null) {
      _toast('ບໍ່ພົບສິນຄ້າ: $value');
      return;
    }
    final current = _qtyByCode[found.code] ?? 0;
    final added = await _setQty(found, current + 1);
    if (added) _toast('ເພີ່ມ ${found.nameLo} ✓');
  }

  // Save the order directly to the server. There is no local draft/detail layer
  // in this flow; the server-backed Sale Order list is the source of truth.
  Future<void> _submit() async {
    if (_submitting || !_canSubmit) return;
    setState(() => _submitting = true);
    try {
      await _refreshStockForCodes(_qtyByCode.keys, force: true);
      if (!mounted) return;
      // Collect any lines that will become backorders (qty > stock) so the
      // user can confirm before posting. Each entry: (itemName, have, short).
      final backorders = <({String name, int have, int short})>[];
      for (final entry in _qtyByCode.entries) {
        final wh = _warehouseByItemCode[entry.key];
        final loc = _locationByItemCode[entry.key];
        final locationCode = loc?.location?.trim();
        if (wh == null || locationCode == null || locationCode.isEmpty) {
          throw ApiException(400, 'ກະລຸນາເລືອກສາງ ແລະ ທີ່ຈັດເກັບໃຫ້ທຸກລາຍການ');
        }
        final stock =
            _stockByLineKey[_lineStockKey(entry.key, wh.code, locationCode)] ??
            0;
        if (stock < entry.value) {
          final item = _itemByCode(entry.key);
          backorders.add((
            name: item?.nameLo ?? entry.key,
            have: stock.floor(),
            short: entry.value - stock.floor(),
          ));
        }
      }
      if (backorders.isNotEmpty) {
        setState(() => _submitting = false);
        final proceed = await _confirmBackorder(backorders);
        if (!mounted) return;
        if (proceed != true) return;
        setState(() => _submitting = true);
      }

      final customer = _selectedCustomer!;
      final sp = _selectedSalesperson;
      final delivery = _selectedDelivery!;

      final items = _qtyByCode.entries
          .where((entry) => _itemByCode(entry.key) != null)
          .map(
            (entry) => (
              productId: entry.key,
              quantity: entry.value,
              warehouseCode: _warehouseByItemCode[entry.key]?.code,
              locationCode: _locationByItemCode[entry.key]?.location,
            ),
          )
          .toList();
      // Standalone special prices are now requested from the dedicated
      // "Price Request" menu before the cart is even started. The server
      // looks up approved (customer, item) pairs at order-create time and
      // applies them — we don't pass them inline here anymore.
      await AppScope.of(context).api.createOrder(
        customerId: customer.id,
        warehouseCode: items.first.warehouseCode,
        deliveryName: delivery.name,
        discountPct: customer.discountPct,
        extraDiscount: _appliedExtraDiscount,
        note: _note,
        salespersonCode: sp?.employeeCode,
        items: items,
        priceRequests: const [],
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast('ຜິດພາດ: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItems;
    const titles = ['ເລືອກລູກຄ້າ', 'ກະຕ່າສິນຄ້າ', 'ສະຫຼຸບ & ບັນທຶກ'];
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) setState(() => _step -= 1);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.gold),
            onPressed: () {
              if (_step > 0) {
                setState(() => _step -= 1);
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          title: Text(
            titles[_step],
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: 0.2,
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tabletConstrain(
                Column(
                  children: [
                    _buildStepIndicator(),
                    Expanded(child: _buildStep(selected)),
                  ],
                ),
              ),
        bottomNavigationBar: _loading
            ? null
            : _tabletConstrain(_buildStepBar()),
      ),
    );
  }

  // Cap working area at ~720dp on tablets so the wizard stays readable
  // instead of stretching across the full landscape width.
  Widget _tabletConstrain(Widget child) {
    if (!isTablet(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['ລູກຄ້າ', 'ກະຕ່າ', 'ບັນທຶກ'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: List.generate(3, (i) {
          final done = i < _step;
          final isCurrent = i == _step;
          final active = i <= _step;
          final color = active ? AppColors.gold : AppColors.textMuted;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bar — glow on the current step so the eye lands here.
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: active ? AppColors.gold : AppColors.cardElev,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Done = ✓, current = filled circle, future = ring.
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: done
                              ? AppColors.gold
                              : (isCurrent
                                    ? AppColors.gold.withValues(alpha: 0.2)
                                    : Colors.transparent),
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 1.4),
                        ),
                        child: done
                            ? const Icon(
                                Icons.check,
                                color: Color(0xFFFFFFFF),
                                size: 12,
                              )
                            : Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight: isCurrent
                                ? FontWeight.w900
                                : FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // Dispatcher — each step renders its own column. State (customer/cart/
  // salesperson/delivery) persists across steps so going back keeps work.
  Widget _buildStep(List<InventoryItem> selected) {
    switch (_step) {
      case 0:
        return _buildStepCustomer();
      case 1:
        return _buildStepCart(selected);
      case 2:
        return _buildStepFinalize(selected);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 0: pick customer ─────────────────────────────────────────────
  Widget _buildStepCustomer() {
    final c = _selectedCustomer;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        FadeInSlide(
          duration: const Duration(milliseconds: 500),
          child: GlassCard(
            padding: const EdgeInsets.all(18),
            radius: kRadiusLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Icon(Icons.person_pin, color: AppColors.gold, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'ລູກຄ້າ',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (c == null)
                Text(
                  'ເລີ່ມ Sale Order ໂດຍເລືອກລູກຄ້າກ່ອນ',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                )
              else
                _customerCard(c),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: kTouchTargetMin,
                child: FilledButton.icon(
                  onPressed: _pickCustomer,
                  icon: Icon(
                    c == null ? Icons.search : Icons.swap_horiz,
                    size: 20,
                  ),
                  label: Text(
                    c == null ? 'ເລືອກລູກຄ້າ' : 'ປ່ຽນລູກຄ້າ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }

  Widget _customerCard(Customer c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardElev,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.goldBright, AppColors.gold],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                if ((c.phone ?? '').isNotEmpty)
                  Text(
                    c.phone!,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _miniBadge(
                      '${_fmt.format(c.pointBalance)} ແຕ້ມ',
                      AppColors.teal,
                    ),
                  ],
                ),
                if ((c.groupName ?? '').isNotEmpty || c.discountPct > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if ((c.groupName ?? '').isNotEmpty)
                        _miniBadge(c.groupName!, AppColors.gold),
                      if (c.discountPct > 0) ...[
                        const SizedBox(width: 6),
                        _miniBadge(
                          '−${c.discountPct == c.discountPct.toInt() ? c.discountPct.toInt() : c.discountPct.toStringAsFixed(1)}%',
                          AppColors.success,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  // ── Step 1: cart ──────────────────────────────────────────────────────
  Widget _buildStepCart(List<InventoryItem> selected) {
    return Column(
      children: [
        // Compact customer header so user always remembers who they're billing.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: _contextChip(
            icon: Icons.person_outline,
            label: _selectedCustomer?.name ?? 'ບໍ່ມີລູກຄ້າ',
            badge: _discountPct > 0
                ? '−${_discountPct == _discountPct.toInt() ? _discountPct.toInt() : _discountPct.toStringAsFixed(1)}%'
                : (_selectedCustomer?.groupName?.isNotEmpty ?? false)
                ? _selectedCustomer!.groupName!
                : null,
            active: _selectedCustomer != null,
            onTap: () => setState(() => _step = 0),
          ),
        ),
        // Big "Add product" + scan button row.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: kTouchTargetMin,
                  child: DecoratedBox(
                    decoration: posActionDecoration(radius: kRadiusMd),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(kRadiusMd),
                        onTap: _inventorySyncing ? null : _openProductPicker,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_inventorySyncing)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.add,
                                  color: Color(0xFFFFFFFF),
                                  size: 22,
                                ),
                              const SizedBox(width: 10),
                              Text(
                                _inventorySyncing
                                    ? 'ກຳລັງໂຫຼດສິນຄ້າ...'
                                    : 'ເພີ່ມສິນຄ້າ',
                                style: const TextStyle(
                                  color: Color(0xFFFFFFFF),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: kTouchTargetMin,
                height: kTouchTargetMin,
                child: Material(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(kRadiusMd),
                    onTap: _scanBarcode,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.6),
                        ),
                        borderRadius: BorderRadius.circular(kRadiusMd),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.gold,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(
          child: selected.isEmpty
              ? _emptyCartMessage()
              : _buildCartList(selected),
        ),
      ],
    );
  }

  Widget _emptyCartMessage() {
    // Loading state takes priority over the empty-cart guidance — the user
    // can't act on "tap Add Product" until the inventory list is ready.
    if (_inventorySyncing && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.4),
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ກຳລັງໂຫຼດສິນຄ້າ…',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ກະລຸນາລໍຖ້າສັກໜຶ່ງ\nແລ້ວຈິ່ງເລີ່ມເພີ່ມສິນຄ້າເຂົ້າກະຕ່າ',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.cardElev,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ກະຕ່າຍັງວ່າງ',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ກົດ "ເພີ່ມສິນຄ້າ" ດ້ານເທິງ ຫຼື ສະແກນ QR\nເລືອກສິນຄ້າ → ເລືອກສາງ → ເລືອກພື້ນທີ່ຈັດເກັບ',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: finalize ──────────────────────────────────────────────────
  Widget _buildStepFinalize(List<InventoryItem> selected) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        // Customer (compact, read-only here — tap to jump back).
        _contextChip(
          icon: Icons.person_outline,
          label: _selectedCustomer?.name ?? '—',
          badge: _discountPct > 0
              ? '−${_discountPct == _discountPct.toInt() ? _discountPct.toInt() : _discountPct.toStringAsFixed(1)}%'
              : null,
          active: _selectedCustomer != null,
          onTap: () => setState(() => _step = 0),
        ),
        const SizedBox(height: 10),
        // Cart summary card — non-interactive recap.
        FadeInSlide(
          duration: const Duration(milliseconds: 500),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            radius: kRadiusMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Icon(
                    Icons.shopping_cart_checkout,
                    color: AppColors.gold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${selected.length} ລາຍການ · ${_fmt.format(_totalQty)} ຊິ້ນ',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: const Text('ແກ້ໄຂ'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final p in selected)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${p.nameLo}  ×${_qtyByCode[p.code]}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        _moneyFmt.format(
                          _lineTotal(p, _qtyByCode[p.code] ?? 0),
                        ),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        // Salesperson chip (required pick).
        _bigPickerRow(
          icon: Icons.badge_outlined,
          label: 'ພະນັກງານຂາຍ',
          value: _selectedSalesperson?.displayName,
          active: _selectedSalesperson != null,
          onTap: _pickSalesperson,
        ),
        const SizedBox(height: 10),
        // Delivery type (required pick).
        _bigPickerRow(
          icon: Icons.local_shipping_outlined,
          label: 'ປະເພດການຮັບສິນຄ້າ',
          value: _selectedDelivery?.name,
          active: _selectedDelivery != null,
          onTap: _pickDelivery,
        ),
        const SizedBox(height: 12),
        // Totals strip — reuse what we already render mid-cart.
        _buildTotalsStrip(),
      ],
    );
  }

  // Single tappable row for a finalize-step picker: icon + label + current
  // value + chevron. Bigger touch target than the inline chips.
  Widget _bigPickerRow({
    required IconData icon,
    required String label,
    required String? value,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border.all(
              color: active
                  ? AppColors.gold.withValues(alpha: 0.6)
                  : AppColors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.gold.withValues(alpha: 0.16)
                      : AppColors.cardElev,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: active ? AppColors.gold : AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? 'ກົດເພື່ອເລືອກ',
                      style: TextStyle(
                        color: active
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom CTA — step-aware ───────────────────────────────────────────
  Widget _buildStepBar() {
    String label;
    bool enabled;
    VoidCallback? onTap;
    IconData icon;
    bool isPrimary = true;

    if (_step == 0) {
      enabled = _selectedCustomer != null;
      label = enabled ? 'ຕໍ່ໄປ' : 'ເລືອກລູກຄ້າກ່ອນ';
      icon = Icons.arrow_forward_rounded;
      onTap = enabled ? () => setState(() => _step = 1) : null;
    } else if (_step == 1) {
      final hasItems = _qtyByCode.isNotEmpty;
      final allHaveLoc = _qtyByCode.keys.every(
        (c) =>
            _warehouseByItemCode[c] != null &&
            (_locationByItemCode[c]?.location?.trim().isNotEmpty ?? false),
      );
      enabled = hasItems && allHaveLoc;
      label = !hasItems
          ? 'ເພີ່ມສິນຄ້າຢ່າງໜ້ອຍ 1 ລາຍການ'
          : !allHaveLoc
          ? 'ເລືອກສາງ+ພື້ນທີ່ໃຫ້ທຸກລາຍການ'
          : 'ຕໍ່ໄປ';
      icon = Icons.arrow_forward_rounded;
      onTap = enabled ? () => setState(() => _step = 2) : null;
    } else {
      enabled = _canSubmit && !_submitting;
      label = _submitting
          ? 'ກຳລັງບັນທຶກ…'
          : (_selectedSalesperson == null
                ? 'ເລືອກພະນັກງານຂາຍ'
                : _selectedDelivery == null
                ? 'ເລືອກປະເພດການຮັບສິນຄ້າ'
                : 'ບັນທຶກ ${_moneyFmt.format(_total)} ກີບ');
      icon = Icons.check_circle;
      onTap = enabled ? _submit : null;
      isPrimary = true;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: kTouchTargetLg,
        child: DecoratedBox(
          decoration: enabled && isPrimary
              ? posActionDecoration(radius: kRadiusLg)
              : BoxDecoration(
                  color: AppColors.cardElev,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  border: Border.all(color: AppColors.border),
                ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(kRadiusLg),
              onTap: onTap,
              child: Center(
                child: _submitting && _step == 2
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFFFFFFFF),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            color: enabled
                                ? const Color(0xFFFFFFFF)
                                : AppColors.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: TextStyle(
                              color: enabled
                                  ? const Color(0xFFFFFFFF)
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contextChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: active ? AppColors.cardBg : AppColors.slate100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: active
                  ? AppColors.teal.withValues(alpha: 0.6)
                  : AppColors.border,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.teal : AppColors.slate500,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppColors.slate900 : AppColors.slate500,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartList(List<InventoryItem> selected) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: selected.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = selected[i];
        final qty = _qtyByCode[p.code] ?? 0;
        final stock = _itemStock(p);
        final subtotal = _unitPrice(p) * qty;
        final discountAmount = _lineDiscountAmount(p, qty);
        final lineTotal = subtotal - discountAmount;
        return FadeInSlide(
          duration: Duration(milliseconds: 300 + (i < 6 ? i * 80 : 480)),
          delay: Duration(milliseconds: i < 6 ? i * 50 : 300),
          child: GlassCard(
            radius: kRadiusMd,
            padding: EdgeInsets.zero,
            child: _SelectedRow(
            item: p,
            qty: qty,
            stock: stock,
            warehouse: _warehouseByItemCode[p.code],
            location: _locationByItemCode[p.code],
            subtotal: subtotal,
            discountPct: _discountPct,
            discountAmount: discountAmount,
            lineTotal: lineTotal,
            approvedPrice: _approvedPriceByCode[p.code],
            fmt: _moneyFmt,
            // Backorder allowed — no upper cap on qty. Server writes the
            // shortfall to app_backorder when the order is created.
            onDec: () => _setQty(p, qty - 1),
            onInc: () => _setQty(p, qty + 1),
            onRemove: () => _setQty(p, 0),
            onPickWarehouse: () => _pickWarehouseForLine(p),
            onRequestPrice: () => _requestPriceForLine(p),
          ),
        ),
        );
      },
    );
  }

  // Compact totals strip shown just above the pay bar. Keeps the cart-feel:
  // user always sees "what I'm about to buy" without scrolling.
  Widget _buildTotalsStrip() {
    final hasNote = _note.trim().isNotEmpty;
    final hasExtra = _appliedExtraDiscount > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _extrasChip(
                  icon: hasExtra
                      ? Icons.local_offer
                      : Icons.local_offer_outlined,
                  label: hasExtra
                      ? 'ຫຼຸດ −${_moneyFmt.format(_appliedExtraDiscount)}'
                      : 'ສ່ວນຫຼຸດທ້າຍບິນ',
                  active: hasExtra,
                  onTap: _editExtraDiscount,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _extrasChip(
                  icon: hasNote
                      ? Icons.sticky_note_2
                      : Icons.sticky_note_2_outlined,
                  label: hasNote ? _note : 'ໝາຍເຫດ',
                  active: hasNote,
                  onTap: _editNote,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Subtotal = sum of per-line nets so it equals what the user
          // sees added up on each cart card (each card already prints the
          // line discount inline, so re-itemising it here doubles the
          // signal and looks like a mismatch).
          _summaryRow('Subtotal', '${_moneyFmt.format(_lineNetTotal)} ກີບ'),
          if (_discountPct > 0) ...[
            const SizedBox(height: 4),
            _summaryRow(
              'ສ່ວນຫຼຸດສະມາຊິກ ${_discountPct == _discountPct.toInt() ? _discountPct.toInt() : _discountPct.toStringAsFixed(1)}% (ໄດ້ປະຍຸກໃຊ້ແລ້ວ)',
              '−${_moneyFmt.format(_discountAmount)} ກີບ',
            ),
          ],
          if (hasExtra) ...[
            const SizedBox(height: 4),
            _summaryRow(
              'ສ່ວນຫຼຸດທ້າຍບິນ',
              '−${_moneyFmt.format(_appliedExtraDiscount)} ກີບ',
            ),
          ],
          const SizedBox(height: 4),
          _summaryRow(
            _loyaltyConfig.isActive
                ? 'ໄດ້${_loyaltyConfig.pointName} ຫຼັງຫັກສ່ວນຫຼຸດ'
                : 'ສະສົມແຕ້ມ',
            _loyaltyConfig.isActive
                ? '${_fmt.format(_earnedPoints)} ແຕ້ມ'
                : 'ປິດໃຊ້',
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_fmt.format(_selectedLineCount)} ລາຍການ · ${_fmt.format(_totalQty)} ຊິ້ນ',
                style: TextStyle(
                  color: AppColors.slate500,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _moneyFmt.format(_total),
                style: TextStyle(
                  color: AppColors.slate900,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'ກີບ',
                style: TextStyle(
                  color: AppColors.slate500,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _extrasChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active
          ? AppColors.teal.withValues(alpha: 0.10)
          : AppColors.slate100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: active
                  ? AppColors.teal.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? AppColors.teal : AppColors.slate500,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppColors.slate900 : AppColors.slate500,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Icon(Icons.edit, size: 12, color: AppColors.slate500),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editExtraDiscount() async {
    final ctl = TextEditingController(
      text: _extraDiscount > 0
          ? (_extraDiscount == _extraDiscount.toInt()
                ? _extraDiscount.toInt().toString()
                : _extraDiscount.toString())
          : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ສ່ວນຫຼຸດທ້າຍບິນ (ກີບ)'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '0',
            prefixIcon: Icon(Icons.local_offer_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0.0),
            child: const Text('ລ້າງ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ຍົກເລີກ'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctl.text.trim()) ?? 0;
              Navigator.pop(ctx, v < 0 ? 0 : v);
            },
            child: const Text('ບັນທຶກ'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _extraDiscount = result);
  }

  Future<void> _editNote() async {
    final ctl = TextEditingController(text: _note);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ໝາຍເຫດ'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'ເຊັ່ນ: ສົ່ງຫຼັງ 17:00, ໂທກ່ອນສົ່ງ...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('ລ້າງ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ຍົກເລີກ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('ບັນທຶກ'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _note = result);
  }

  // Confirmation dialog shown before submit when one or more cart lines
  // exceed available stock. The order still goes in with the full ordered
  // qty; the shortfall is tracked in app_backorder for warehouse staff.
  Future<bool?> _confirmBackorder(
    List<({String name, int have, int short})> backorders,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.timer_outlined,
                color: AppColors.danger,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('Backorder')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ສິນຄ້າ ${backorders.length} ລາຍການ stock ບໍ່ພໍ. ສ້າງ Order ໄດ້ — ສ່ວນທີ່ຂາດຈະຖືກບັນທຶກໄວ້ໃຫ້ສາງສ່ົງສຳເລັດໃນພາຍຫຼັງ.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final b in backorders)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'ມີ ${b.have} · ຂາດ ${b.short}',
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ກັບໄປແກ້ໄຂ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ສ້າງ Order'),
          ),
        ],
      ),
    );
  }

  // Inline request for a special price on a specific cart line. Submits as a
  // standalone request to /api/price-requests (cart_number = NULL) so the
  // manager can approve it independently. Once approved, the user can add
  // the item to a fresh order and the price applies automatically.
  Future<void> _requestPriceForLine(InventoryItem item) async {
    final customer = _selectedCustomer;
    if (customer == null) {
      _toast('ເລືອກລູກຄ້າກ່ອນ');
      return;
    }
    final originalPrice = item.salePriceKip;
    final reasonCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.discount,
                color: AppColors.warning,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('ຂໍລາຄາພິເສດ')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nameLo,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ລາຄາເດີມ: ${_moneyFmt.format(originalPrice)} ກີບ',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtl,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ເຫດຜົນ *',
                  hintText: 'ເຊັ່ນ: ລູກຄ້າ VIP, ໂປຣ',
                  helperText: 'ຜູ້ຈັດການຈະເປັນຜູ້ກຳນົດລາຄາໃໝ່',
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ບິນນີ້ໃຊ້ລາຄາເດີມໄປກ່ອນ. ເມື່ອອະນຸມັດ ລາຄາໃໝ່ຈະຖືກໃຊ້ໃນບິນຕໍ່ໄປຂອງລູກຄ້ານີ້.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ຍົກເລີກ'),
          ),
          FilledButton(
            onPressed: () {
              final reason = reasonCtl.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('ກະລຸນາໃສ່ເຫດຜົນ'),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(12),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('ສົ່ງຄຳຂໍ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final reason = reasonCtl.text.trim();
    try {
      await AppScope.of(context).api.createPriceRequest(
        customerCode: customer.id,
        itemCode: item.code,
        originalPrice: originalPrice,
        reason: reason,
      );
      if (mounted) _toast('ສົ່ງຄຳຂໍແລ້ວ ✓ ລໍຖ້າຜູ້ຈັດການອະນຸມັດລາຄາ');
    } catch (e) {
      if (mounted) _toast('ສົ່ງບໍ່ສຳເລັດ: $e');
    }
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.slate500,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.slate900,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SelectedRow extends StatelessWidget {
  const _SelectedRow({
    required this.item,
    required this.qty,
    required this.stock,
    required this.warehouse,
    required this.location,
    required this.subtotal,
    required this.discountPct,
    required this.discountAmount,
    required this.lineTotal,
    required this.fmt,
    required this.onDec,
    required this.onInc,
    required this.onRemove,
    required this.onPickWarehouse,
    required this.onRequestPrice,
    required this.approvedPrice,
  });

  final InventoryItem item;
  final int qty;
  final double stock;
  final Warehouse? warehouse;
  final StockLocation? location;
  final double subtotal;
  final double discountPct;
  final double discountAmount;
  final double lineTotal;
  final NumberFormat fmt;
  final VoidCallback onDec;
  final VoidCallback? onInc;
  final VoidCallback onRemove;
  final VoidCallback onPickWarehouse;
  final VoidCallback onRequestPrice;
  // Approved-and-applied standalone price override (from the dedicated
  // "Price Request" menu). Null = catalog price is in effect.
  final double? approvedPrice;

  @override
  Widget build(BuildContext context) {
    final hasWarehouse = warehouse != null && location != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: name + line total + close ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nameLo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fmt.format(item.salePriceKip)} × $qty',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(lineTotal),
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'ກີບ',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 32,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                  tooltip: 'ລົບ',
                ),
              ),
            ],
          ),
          if (discountPct > 0) ...[
            const SizedBox(height: 4),
            Text(
              'ສ່ວນຫຼຸດ ${discountPct == discountPct.toInt() ? discountPct.toInt() : discountPct.toStringAsFixed(1)}% · −${fmt.format(discountAmount)} ກີບ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // ── Row 2: stepper + warehouse chip (both bigger / easier to tap) ──
          Row(
            children: [
              _MiniStepper(qty: qty, onDec: onDec, onInc: onInc),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: hasWarehouse
                      ? AppColors.gold.withValues(alpha: 0.10)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onPickWarehouse,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: hasWarehouse
                              ? AppColors.gold.withValues(alpha: 0.5)
                              : AppColors.warning.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warehouse_outlined,
                            size: 16,
                            color: hasWarehouse
                                ? AppColors.gold
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasWarehouse
                                      ? (warehouse!.name.trim().isNotEmpty
                                            ? warehouse!.name
                                            : 'ສາງ ${warehouse!.code}')
                                      : 'ເລືອກສາງ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: hasWarehouse
                                        ? AppColors.gold
                                        : AppColors.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                                if (hasWarehouse)
                                  Text(
                                    '${(location!.locationName?.trim().isNotEmpty ?? false) ? location!.locationName! : location!.location ?? "—"} · stock ${stock == stock.toInt() ? stock.toInt() : stock.toStringAsFixed(2)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.textMuted,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Backorder warning — qty exceeds known stock at the picked
          // warehouse+location. The order will still post; the shortfall
          // is tracked server-side in app_backorder.
          if (hasWarehouse && stock >= 0 && qty > stock) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Backorder · ມີ ${stock == stock.toInt() ? stock.toInt() : stock.toStringAsFixed(2)} · ຂາດ ${qty - stock.toInt() > 0 ? qty - stock.toInt() : (qty - stock).toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (approvedPrice != null)
            // Approved special-price chip — already signed off by a manager.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ລາຄາພິເສດອະນຸມັດແລ້ວ · ${fmt.format(approvedPrice!)} ກີບ (ປົກກະຕິ ${fmt.format(item.salePriceKip)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Inline price-request — opens a dialog that POSTs a standalone
            // request to /api/price-requests (cart_number = NULL). The bill
            // is created with the original price; the override kicks in on
            // the NEXT order for the same (customer, item) once approved.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRequestPrice,
                icon: const Icon(Icons.discount_outlined, size: 14),
                label: const Text(
                  'ຂໍລາຄາພິເສດ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  backgroundColor: AppColors.warning.withValues(alpha: 0.10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.qty,
    required this.onDec,
    required this.onInc,
  });
  final int qty;
  final VoidCallback? onDec;
  final VoidCallback? onInc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardElev,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, onDec, isLeft: true),
          Container(
            width: 44,
            height: 40,
            alignment: Alignment.center,
            child: Text(
              '$qty',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          _btn(Icons.add, onInc, isLeft: false),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap, {required bool isLeft}) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? AppColors.gold.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.horizontal(
        left: isLeft ? const Radius.circular(11) : Radius.zero,
        right: isLeft ? Radius.zero : const Radius.circular(11),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(11) : Radius.zero,
          right: isLeft ? Radius.zero : const Radius.circular(11),
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.gold : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({
    required this.items,
    required this.allItems,
    required this.qtyByCode,
    required this.stockOf,
    required this.stockLoading,
    required this.fmt,
    required this.onChangeQty,
  });

  // `items` = in-stock subset shown when the search box is empty.
  // `allItems` = full inventory including out-of-stock — searched against
  // when the user types anything, so a known SKU is always findable.
  final List<InventoryItem> items;
  final List<InventoryItem> allItems;
  final Map<String, int> qtyByCode;
  final double Function(InventoryItem) stockOf;
  final bool stockLoading;
  final NumberFormat fmt;
  final Future<bool> Function(InventoryItem, int) onChangeQty;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _q = '';
  Timer? _debounce;
  int _searchSeq = 0;
  bool _serverSearching = false;
  List<InventoryItem> _serverResults = const [];
  // Pre-lowercased haystack per item. Built once when items load (or when
  // the parent passes a different list reference) — avoids re-lowercasing
  // every product on every keystroke, which was the dominant cost on the
  // bottom sheet build with large inventories.
  Map<String, String> _searchIndex = const {};

  @override
  void initState() {
    super.initState();
    _rebuildSearchIndex();
  }

  @override
  void didUpdateWidget(covariant _ProductPickerSheet old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items) ||
        !identical(old.allItems, widget.allItems)) {
      _rebuildSearchIndex();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _rebuildSearchIndex() {
    // Index the FULL catalog (`allItems`) so a typed query can surface items
    // that aren't in the in-stock view. Empty-query browsing still uses
    // `items` (in-stock only) so the default list isn't cluttered with
    // zero-balance rows.
    final source = widget.allItems.isNotEmpty ? widget.allItems : widget.items;
    _searchIndex = {
      for (final p in source)
        p.code: [
          p.nameLo,
          p.nameEng,
          p.code,
          p.brand,
          p.brandName,
          p.unitName,
          p.category,
          p.categoryName,
          p.groupMain,
          p.groupMainName,
          if ('${p.nameLo} ${p.nameEng ?? ''}'.toLowerCase().contains('air'))
            'ແອ ແອເຢັນ',
        ].whereType<String>().join(' ').toLowerCase(),
    };
  }

  void _onSearchChanged(String v) {
    // 120ms debounce — long enough to swallow rapid keystrokes, short enough
    // that the list still feels responsive once typing stops.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _q = v);
      unawaited(_runServerSearch(v.trim()));
    });
  }

  Future<void> _runServerSearch(String value) async {
    final seq = ++_searchSeq;
    if (value.isEmpty) {
      if (mounted) {
        setState(() {
          _serverSearching = false;
          _serverResults = const [];
        });
      }
      return;
    }
    setState(() => _serverSearching = true);
    try {
      final normalized = value.trim().toLowerCase();
      final isAirQuery = normalized == 'ແອ' || normalized == 'air';
      final rows = await AppScope.of(
        context,
      ).api.searchInventory(value, limit: isAirQuery ? 1000 : 10);
      if (!mounted || seq != _searchSeq) return;
      setState(() => _serverResults = rows);
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() => _serverResults = const []);
    } finally {
      if (mounted && seq == _searchSeq) {
        setState(() => _serverSearching = false);
      }
    }
  }

  String _fmtQty(double value) => value == value.toInt()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final rawQuery = _q.trim().toLowerCase();
    final isAirQuery = rawQuery == 'ແອ' || rawQuery == 'air';
    final q = isAirQuery ? 'air' : rawQuery;
    // Browse mode (empty query) = the curated in-stock list, with the
    // existing zero-balance filter applied so the default view stays clean.
    // Search mode (non-empty query) = the full catalog, so the cashier can
    // find an item by code/name even when its balance is zero.
    final source = q.isEmpty || widget.allItems.isEmpty
        ? widget.items
        : widget.allItems;
    final localFiltered = source.where((p) {
      final qty = widget.qtyByCode[p.code] ?? 0;
      if (q.isEmpty) {
        final stock = widget.stockOf(p);
        if (qty <= 0 && p.companyBalance <= 0) return false;
        if (stock >= 0 && stock <= 0 && qty <= 0) return false;
        return true;
      }
      return _searchIndex[p.code]?.contains(q) ?? false;
    }).toList();
    final mergedFiltered = [
      ...{
        for (final p in [..._serverResults, ...localFiltered]) p.code: p,
      }.values,
    ];
    final filtered = q.isEmpty
        ? localFiltered
        : isAirQuery
        ? mergedFiltered
        : mergedFiltered.take(10).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: AppColors.slate900),
                SizedBox(width: 8),
                Text(
                  'Add items',
                  style: TextStyle(
                    color: AppColors.slate900,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search by name, code or brand',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: widget.stockLoading
                ? const Center(child: CircularProgressIndicator())
                : _serverSearching && filtered.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      'No items found',
                      style: TextStyle(color: AppColors.slate500),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.slate100),
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final qty = widget.qtyByCode[p.code] ?? 0;
                      final stock = widget.stockOf(p);
                      final stockText = stock < 0
                          ? 'Stock: ${_fmtQty(p.companyBalance)}'
                          : 'Stock: ${stock == stock.toInt() ? stock.toInt() : stock.toStringAsFixed(2)}';
                      // First-time add: tapping anywhere on the row pops the
                      // warehouse+location sheet, then closes the product
                      // picker so the user can keep scanning. After it's in
                      // the cart, the row turns into a stepper for qty
                      // adjustments and the row tap is disabled so the user
                      // doesn't accidentally double-add.
                      Future<void> handleFirstAdd() async {
                        final navigator = Navigator.of(context);
                        final ok = await widget.onChangeQty(p, 1);
                        if (!mounted) return;
                        if (ok) {
                          navigator.pop();
                        } else {
                          setState(() {});
                        }
                      }

                      return ListTile(
                        onTap: qty > 0 ? null : handleFirstAdd,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: qty > 0
                                ? AppColors.teal
                                : AppColors.slate100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            qty > 0 ? Icons.check : Icons.inventory_2_outlined,
                            color: qty > 0
                                ? AppColors.bg
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          p.nameLo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${p.code} · $stockText',
                          style: TextStyle(
                            color: AppColors.slate500,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        trailing: qty > 0
                            ? _MiniStepper(
                                qty: qty,
                                onDec: () async {
                                  await widget.onChangeQty(p, qty - 1);
                                  if (mounted) setState(() {});
                                },
                                onInc: stock >= 0 && qty >= stock
                                    ? null
                                    : () async {
                                        await widget.onChangeQty(p, qty + 1);
                                        if (mounted) setState(() {});
                                      },
                              )
                            : null,
                      );
                    },
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.goldBright, AppColors.gold],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppColors.bg,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _CreateCustomerFn =
    Future<Customer> Function({
      required String name,
      String? phone,
      String? email,
      String? address,
    });

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({required this.customers, this.onCreate});
  final List<Customer> customers;
  // Null when the current user lacks the head/manager role — the picker then
  // hides the "+ ສ້າງ" button entirely instead of showing it disabled.
  final _CreateCustomerFn? onCreate;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _q = '';
  // Debounced server-side search. Preloading the full member book (16k rows,
  // ~2.5 MB) blew past the 10s mobile timeout, so the picker now fetches on
  // demand: empty query shows the parent's initial batch, typed queries hit
  // /api/customers?q=... after a short debounce.
  Timer? _debounce;
  List<Customer> _results = const [];
  bool _loading = false;
  int _requestSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    setState(() => _q = v);
    _debounce?.cancel();
    final trimmed = v.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetch(trimmed);
    });
  }

  Future<void> _fetch(String q) async {
    final seq = ++_requestSeq;
    setState(() => _loading = true);
    try {
      final api = AppScope.of(context).api;
      final found = await api
          .listCustomers(q: q, limit: 200)
          .timeout(const Duration(seconds: 15));
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = found;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final fn = widget.onCreate;
    if (fn == null) return;
    // Customer creation is its own screen rather than a modal — the form
    // had too many fields for an AlertDialog, and the gold-tier notice
    // reads better with full-width room.
    final created = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _NewCustomerScreen(onCreate: fn),
      ),
    );
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _q.trim().isNotEmpty;
    final filtered = hasQuery ? _results : widget.customers;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: AppColors.slate900),
                const SizedBox(width: 8),
                Text(
                  'Select member',
                  style: TextStyle(
                    color: AppColors.slate900,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),
                if (widget.onCreate != null) ...[
                  FilledButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('ສ້າງ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search member',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                isDense: true,
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      hasQuery && !_loading
                          ? 'No member found'
                          : hasQuery
                          ? 'Searching…'
                          : 'Type to search members',
                      style: TextStyle(color: AppColors.slate500),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.teal.withValues(
                            alpha: 0.14,
                          ),
                          child: Text(
                            c.name.isNotEmpty
                                ? c.name.trim()[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if (c.phone != null) c.phone!,
                            '${NumberFormat('#,###', 'en_US').format(c.pointBalance)} ແຕ້ມສະສົມ',
                            if (c.groupName?.isNotEmpty == true) c.groupName!,
                            '${c.discountPct.toStringAsFixed(c.discountPct == c.discountPct.toInt() ? 0 : 1)}% ສ່ວນຫຼຸດຕາມລາຍການ',
                          ].join(' · '),
                        ),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NewCustomerScreen extends StatefulWidget {
  const _NewCustomerScreen({required this.onCreate});
  final _CreateCustomerFn onCreate;

  @override
  State<_NewCustomerScreen> createState() => _NewCustomerScreenState();
}

class _NewCustomerScreenState extends State<_NewCustomerScreen> {
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    super.dispose();
  }

  // Phone is the customer code on the server, so we strip all non-digits
  // before sending and validate the prefix/length client-side too. Mirrors
  // the server check at POST /api/customers.
  String? _validatePhone(String phone) {
    if (phone.isEmpty) return 'ກະລຸນາໃສ່ເບີໂທ';
    if (RegExp(r'^20\d{8}$').hasMatch(phone)) return null; // 10 digits
    if (RegExp(r'^30\d{7}$').hasMatch(phone)) return null; // 9 digits
    return 'ເບີໂທຕ້ອງຂຶ້ນຕົ້ນດ້ວຍ 20 (10 ຕົວ) ຫຼື 30 (9 ຕົວ)';
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    final phone = _phoneCtl.text.replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty) {
      setState(() => _error = 'ກະລຸນາໃສ່ຊື່ລູກຄ້າ');
      return;
    }
    final phoneError = _validatePhone(phone);
    if (phoneError != null) {
      setState(() => _error = phoneError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await widget.onCreate(
        name: name,
        phone: phone,
        address: _addressCtl.text.trim().isEmpty
            ? null
            : _addressCtl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      // ApiException toString returns the server message — surface it
      // directly so duplicate-phone / bad-format errors show what the
      // server saw.
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'ສ້າງລູກຄ້າໃໝ່',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: TabletConstrain(
          maxWidth: 720,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Server auto-assigns the "gold" tier + 3% discount. Banner at
              // the top so the salesperson sees the perk before they fill
              // anything else in.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.gold.withValues(alpha: 0.18),
                      AppColors.goldBright.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.goldBright, AppColors.gold],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ສະຖານະເລີ່ມຕົ້ນ: Gold',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ສ່ວນຫຼຸດ 3% ຕໍ່ບິນ ໂດຍອັດຕະໂນມັດ',
                            style: TextStyle(
                              color: AppColors.gold.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameCtl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'ຊື່ *',
                  prefixIcon: Icon(Icons.badge_outlined),
                  filled: true,
                  fillColor: AppColors.cardBg,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'ເບີໂທ *',
                  helperText: 'ຂຶ້ນຕົ້ນ 20 (10 ຕົວ) ຫຼື 30 (9 ຕົວ)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  filled: true,
                  fillColor: AppColors.cardBg,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'ທີ່ຢູ່',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  filled: true,
                  fillColor: AppColors.cardBg,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(kRadiusMd),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: kTouchTargetMin,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _saving ? 'ກຳລັງບັນທຶກ…' : 'ບັນທຶກ',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarehousePickerSheet extends StatefulWidget {
  const _WarehousePickerSheet({
    required this.warehouses,
    required this.selectedCode,
  });
  final List<Warehouse> warehouses;
  final String? selectedCode;

  @override
  State<_WarehousePickerSheet> createState() => _WarehousePickerSheetState();
}

class _WarehousePickerSheetState extends State<_WarehousePickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.warehouses
        : widget.warehouses
              .where(
                (w) =>
                    w.code.toLowerCase().contains(q) ||
                    w.name.toLowerCase().contains(q),
              )
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Icon(Icons.warehouse_outlined, color: AppColors.slate900),
                SizedBox(width: 8),
                Text(
                  'Select warehouse',
                  style: TextStyle(
                    color: AppColors.slate900,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search warehouse',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No warehouse found',
                      style: TextStyle(color: AppColors.slate500),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final w = filtered[i];
                      final isSelected = widget.selectedCode == w.code;
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.teal
                                : AppColors.teal.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            isSelected ? Icons.check : Icons.warehouse,
                            color: isSelected ? AppColors.bg : AppColors.gold,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          w.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Code · ${w.code}',
                          style: TextStyle(
                            color: AppColors.slate500,
                            fontFamily: 'monospace',
                          ),
                        ),
                        onTap: () => Navigator.pop(context, w),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SalespersonPickerSheet extends StatefulWidget {
  const _SalespersonPickerSheet({
    required this.employees,
    required this.selectedCode,
  });
  final List<Employee> employees;
  final String? selectedCode;

  @override
  State<_SalespersonPickerSheet> createState() =>
      _SalespersonPickerSheetState();
}

class _SalespersonPickerSheetState extends State<_SalespersonPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.employees
        : widget.employees
              .where(
                (e) =>
                    e.displayName.toLowerCase().contains(q) ||
                    (e.employeeCode ?? '').toLowerCase().contains(q) ||
                    (e.nickname ?? '').toLowerCase().contains(q),
              )
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Icon(Icons.badge_outlined, color: AppColors.slate900),
                SizedBox(width: 8),
                Text(
                  'ເລືອກພະນັກງານຂາຍ',
                  style: TextStyle(
                    color: AppColors.slate900,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'ຄົ້ນຫາຊື່ / ລະຫັດ / ຊື່ຫຼິ້ນ',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'ບໍ່ພົບພະນັກງານ',
                      style: TextStyle(color: AppColors.slate500),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      final isSelected = widget.selectedCode == e.employeeCode;
                      final initial = e.displayName.trim().isEmpty
                          ? '?'
                          : e.displayName.trim()[0].toUpperCase();
                      final subParts = <String>[
                        if (e.employeeCode != null) e.employeeCode!,
                        if (e.nickname != null &&
                            e.nickname!.trim().isNotEmpty &&
                            e.nickname != '0')
                          '"${e.nickname}"',
                        if (e.positionCode != null &&
                            e.positionCode!.trim().isNotEmpty)
                          e.positionCode!,
                      ];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppColors.teal
                              : AppColors.teal.withValues(alpha: 0.14),
                          child: isSelected
                              ? Icon(Icons.check, color: AppColors.bg)
                              : Text(
                                  initial,
                                  style: TextStyle(
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                        title: Text(
                          e.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: subParts.isEmpty
                            ? null
                            : Text(
                                subParts.join(' · '),
                                style: TextStyle(
                                  color: AppColors.slate500,
                                  fontSize: 12,
                                ),
                              ),
                        onTap: () => Navigator.pop(context, e),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryPickerSheet extends StatelessWidget {
  const _DeliveryPickerSheet({
    required this.options,
    required this.selectedCode,
  });

  final List<TransportType> options;
  final String? selectedCode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    color: AppColors.slate900,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'ເລືອກຂົນສົ່ງ',
                    style: TextStyle(
                      color: AppColors.slate900,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
            ...options.map((option) {
              final isSelected = selectedCode == option.code;
              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.teal
                        : AppColors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isSelected ? Icons.check : Icons.local_shipping_outlined,
                    color: isSelected ? AppColors.bg : AppColors.gold,
                    size: 22,
                  ),
                ),
                title: Text(
                  option.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(context, option),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// Returned to the caller of _promptWarehouseForItem.
class _PickedWarehouseStock {
  const _PickedWarehouseStock({
    required this.warehouse,
    required this.location,
    required this.stock,
  });
  final Warehouse warehouse;
  final StockLocation location;
  final double stock;
}

// One row in the warehouse-picker bottom sheet.
class _WarehouseStockOption {
  const _WarehouseStockOption({
    required this.warehouse,
    required this.location,
    required this.stock,
  });
  final Warehouse warehouse;
  final StockLocation location;
  final double stock;
}

// Bottom sheet opened from a cart line to pick which warehouse sources that
// item. Lists only warehouses that have positive stock.
class _WarehouseStockPickerSheet extends StatelessWidget {
  const _WarehouseStockPickerSheet({
    required this.item,
    required this.options,
    required this.fmt,
  });

  final InventoryItem item;
  final List<_WarehouseStockOption> options;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.warehouse_outlined, color: AppColors.gold),
                SizedBox(width: 8),
                Text(
                  'ເລືອກສາງ / ບ່ອນຈັດເກັບ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.nameLo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final opt = options[i];
                  final locationText = [
                    opt.location.location,
                    opt.location.locationName,
                  ].where((v) => v != null && v.trim().isNotEmpty).join(' · ');
                  final stockText = opt.stock == opt.stock.toInt()
                      ? fmt.format(opt.stock.toInt())
                      : opt.stock.toStringAsFixed(2);
                  return Material(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(kRadiusMd),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(opt),
                      borderRadius: BorderRadius.circular(kRadiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(kRadiusMd),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(kRadiusSm),
                              ),
                              child: Icon(
                                Icons.warehouse_outlined,
                                color: AppColors.gold,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ສາງ ${opt.warehouse.code}',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (opt.warehouse.name.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        opt.warehouse.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (locationText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        locationText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.teal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  stockText,
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ໃນສາງ',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}