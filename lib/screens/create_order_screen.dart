import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/promotions_engine.dart';
import 'barcode_scanner_screen.dart';
import '../components/ui_components.dart';


class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key, this.editOrder});

  // When set, the screen opens in "edit" mode — customer + items are
  // pre-filled from the existing order. On successful submit the new bill
  // is created and the original order is then cancelled with a reason
  // pointing at the new doc number ("edit by replacement", since SOK
  // headers can't be mutated in place).
  final SaleOrder? editOrder;

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
  bool _loading = false;
  bool _inventorySyncing = false;

  Customer? _selectedCustomer;
  TransportType? _selectedDelivery;
  Employee? _selectedSalesperson;
  final Map<String, int> _qtyByCode = {};
  final Map<String, Warehouse> _warehouseByItemCode = {};
  final Map<String, StockLocation> _locationByItemCode = {};
  // Per-line salesperson override — mirrors web POS where each cart line
  // gets its own picker. Empty entry → use the bill-level fallback
  // (_selectedSalesperson).
  final Map<String, Employee> _salespersonByItemCode = {};
  // Set (ຊຸດ) lines — eg. air-con kits. A set holds no pre-built balance of
  // its own; it's assembled from components at sale time. `_buildableSetsByCode`
  // is the cap on how many whole sets the picked warehouse can build (from
  // /api/products/{id}/set/availability, warehouse-level). `_setDetailsByCode`
  // is the component breakdown shown on the cart line, mirroring the web POS.
  final Map<String, double> _buildableSetsByCode = {};
  final Map<String, List<ProductSetDetailItem>> _setDetailsByCode = {};
  bool _submitting = false;
  // Bill-level extras: applied AFTER the customer's per-line discount. The
  // note is stored in order_cart.remark together with delivery info.
  double _extraDiscount = 0;
  String _note = '';
  // Approved standalone price overrides, keyed by item code. Populated at
  // add-to-cart time by `_fetchApprovedPriceFor`. When present, this price
  // replaces `InventoryItem.salePriceKip` everywhere in the cart math.
  final Map<String, double> _approvedPriceByCode = {};

  // Promotions — fetched once at bootstrap, evaluated client-side on every
  // cart change so the user sees discounts before submit. Server re-evaluates
  // on POST /api/orders, so these are preview-only (engine logic mirrors
  // /lib/promotions-engine on the web).
  List<Promotion> _activePromos = const [];
  Map<String, double> _promoDiscountByCode = const {};
  Map<String, String> _promoLabelByCode = const {};
  Map<String, double> _customerDiscountByCode = const {};
  Map<String, bool> _awardsPointsByCode = const {};
  double _totalPromoDiscount = 0;
  // Bonus line → trigger code. When set, the cart row renders with a
  // "ແຖມ" pill, "ຟຣີ" price, locked qty stepper, and cascades on
  // remove/decrement of the parent trigger.
  final Map<String, String> _bonusOfByCode = {};
  // Per-trigger-item promotion choice. key = trigger item code.
  //   absent      → default (engine auto-applies as before)
  //   value null  → cashier opted OUT (no promo on this item)
  //   value id    → cashier picked this specific promo id
  final Map<String, String?> _promoChoiceByCode = {};

  // ── Inline product search state (web POS parity) ────────────────────
  // Mirrors what the old _ProductPickerSheet did, but lifted into the
  // main page so the product grid is the primary surface.
  String _query = '';
  Timer? _searchDebounce;
  int _searchSeq = 0;
  bool _serverSearching = false;
  List<InventoryItem> _serverResults = const [];
  Map<String, String> _searchIndex = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bootstrap();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-fill the bill-level salesperson with the logged-in user as soon
    // as we have access to AppScope. The employee list refines this entry
    // when it loads (richer fields like fullnameLo/En) but the chip never
    // appears empty in the meantime.
    if (_selectedSalesperson == null) {
      final me = AppScope.of(context).auth.employee;
      if (me != null) {
        _selectedSalesperson = me;
      }
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Pre-fill from an existing order when in edit mode. The first
    // pass picks up everything that doesn't need a lookup list yet
    // (customer, qty, extras); the second pass — _hydrateEditPicks —
    // runs after _loadCustomersAndWarehouses finishes and matches the
    // remembered codes against the freshly-loaded warehouses, deliveries,
    // and employees so the cashier reopens the cart fully populated.
    final src = widget.editOrder;
    if (src != null) {
      _selectedCustomer = src.customer;
      _extraDiscount = src.extraDiscount;
      _note = src.note ?? '';
      // Synthesize InventoryItem records from the order lines so the cart
      // can render them before /api/inventory/search returns. They get
      // overwritten by the live record once the catalog loads (same code
      // → same key in _allItems).
      final synthetic = <InventoryItem>[];
      for (final ln in src.items) {
        final code = ln.productId.trim();
        if (code.isEmpty) continue;
        synthetic.add(
          InventoryItem(
            code: code,
            nameLo: ln.product?.name ?? code,
            salePriceKip: ln.unitPrice,
          ),
        );
        _qtyByCode[code] = ln.quantity;
      }
      _allItems = synthetic;
    }

    // Clear loading immediately so the search bar + grid render right
    // away. Customers/warehouses + inventory load in the background; the
    // warehouse picker has a fallback path that re-fetches if `_warehouses`
    // is still empty when the user taps, so blocking the UI here would be
    // a worse trade.
    if (mounted) setState(() => _loading = false);
    // Chain the prefill after the lookups finish so we can resolve codes
    // (delivery name, warehouse code, salesperson code) to model objects.
    unawaited(_loadCustomersAndWarehouses().then((_) => _hydrateEditPicks()));
    unawaited(_syncInventory());
  }

  // Match the SaleOrder's remembered codes against the freshly-loaded
  // lookup lists so the picker chips render with the same selections as
  // the original bill. No-op outside edit mode.
  void _hydrateEditPicks() {
    final src = widget.editOrder;
    if (src == null || !mounted) return;

    // Customer: prefer the richer record from _customers (carries
    // discount %, group, point balance) over the stub on src.customer.
    final richer = _customers.firstWhere(
      (c) => c.id == src.customerId,
      orElse: () => src.customer ?? _customers.first,
    );

    // Delivery: original was packed as a name string, so match by name.
    TransportType? delivery = _selectedDelivery;
    if (delivery == null && (src.deliveryName ?? '').trim().isNotEmpty) {
      final wanted = src.deliveryName!.trim();
      for (final d in _deliveries) {
        if (d.name.trim() == wanted) {
          delivery = d;
          break;
        }
      }
    }

    // Per-line warehouse + location + salesperson. The location is a
    // stub StockLocation carrying just the code — that's enough for the
    // cart row to render and for the submit payload, since the server
    // only persists the code anyway. Stock balance for the row will get
    // refreshed lazily when the user opens the warehouse picker or the
    // submit-time stock check fires.
    final Map<String, Warehouse> warehouseByCode = {
      for (final w in _warehouses) w.code: w,
    };
    final Map<String, Employee> employeeByCode = {
      for (final e in _employees)
        if (e.employeeCode != null && e.employeeCode!.isNotEmpty)
          e.employeeCode!: e,
    };
    // Bill-level warehouse acts as a fallback for legacy rows that don't
    // carry per-line wh_code — without this the cart would render with
    // "ເລືອກສາງ" warnings on every line even when the bill clearly used
    // one warehouse end-to-end.
    final billLevelWhCode = src.warehouseCode?.trim();
    final Warehouse? billLevelWh =
        (billLevelWhCode != null && billLevelWhCode.isNotEmpty)
        ? warehouseByCode[billLevelWhCode]
        : null;

    for (final ln in src.items) {
      final code = ln.productId.trim();
      if (code.isEmpty) continue;
      final lnWhCode = ln.warehouseCode?.trim();
      final locCode = ln.locationCode?.trim();
      final spCode = ln.salespersonCode?.trim();

      Warehouse? wh;
      if (lnWhCode != null && lnWhCode.isNotEmpty) {
        wh = warehouseByCode[lnWhCode];
      }
      wh ??= billLevelWh;

      if (wh != null) {
        _warehouseByItemCode[code] = wh;
        _locationByItemCode[code] = StockLocation(
          warehouse: wh.code,
          warehouseName: wh.name,
          location: locCode == null || locCode.isEmpty ? null : locCode,
          balanceQty: 0,
          averageCost: 0,
          averageCostEnd: 0,
          balanceAmount: 0,
        );
      }

      if (spCode != null && spCode.isNotEmpty) {
        final emp = employeeByCode[spCode];
        if (emp != null) {
          _salespersonByItemCode[code] = emp;
        }
      }
    }

    debugPrint(
      '[EditPrefill] bill wh=$billLevelWhCode '
      '| lines=${src.items.length} '
      '| matched ${_warehouseByItemCode.length} warehouses, '
      '${_salespersonByItemCode.length} salespeople, '
      'delivery=${delivery?.name ?? "—"}',
    );

    setState(() {
      _selectedCustomer = richer;
      _selectedDelivery = delivery;
    });
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
      safe<List<Promotion>>(() async {
        try {
          return await api.fetchActivePromotions();
        } catch (e) {
          _toast('API Error fetchActivePromotions: $e');
          rethrow;
        }
      }, const <Promotion>[]),
    ]);
    if (!mounted) return;
    final warehouses = results[1] as List<Warehouse>;
    final employees = results[2] as List<Employee>;
    final deliveries = results[3] as List<TransportType>;
    final loyaltyConfig = results[4] as LoyaltyConfig;
    final promos = results[5] as List<Promotion>;
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
    debugPrint(
      '[CreateOrder] loaded ${promos.length} active promo(s): '
      '${promos.map((p) => "${p.id}/${p.promoType}/${p.name}").join(", ")}',
    );
    setState(() {
      _customers = results[0] as List<Customer>;
      _warehouses = warehouses;
      _employees = employees;
      _deliveries = deliveries;
      _loyaltyConfig = loyaltyConfig;
      _activePromos = promos;
      _selectedSalesperson ??= defaultSp;
      // Cart may already have items if we're in edit mode — recompute now
      // that promotions have arrived.
      _recomputePromotions();
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
          .searchInventory('', limit: 10, includeSets: true)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _items = rows;
        _allItems = rows;
      });
      _rebuildSearchIndex();
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

  Promotion? _activePromoForProduct(String code) {
    if (_activePromos.isEmpty) return null;
    final now = DateTime.now();
    final trimmed = code.trim();
    for (final p in _activePromos) {
      if (!isPromoActiveNow(p, now)) continue;
      if (p.triggerItemCode?.trim() == trimmed) {
        return p;
      }
    }
    return null;
  }

  // All active promos whose trigger is this product — drives the per-line
  // "choose promotion" control. Empty = no promo offered for this item.
  List<Promotion> _applicablePromosForProduct(String code) {
    if (_activePromos.isEmpty) return const [];
    final now = DateTime.now();
    final t = code.trim();
    return _activePromos
        .where((p) => isPromoActiveNow(p, now) && p.triggerItemCode?.trim() == t)
        .toList();
  }

  // Active promos after applying the cashier's per-item choices: an opted-out
  // trigger drops all its promos; a chosen trigger keeps only that promo id;
  // untouched triggers keep their defaults. Feeds the engine so preview and
  // (via the submit payload) the server agree on what applies.
  List<Promotion> _effectivePromos() {
    return _activePromos.where((p) {
      final trig = p.triggerItemCode?.trim() ?? '';
      if (trig.isEmpty) return true;
      if (!_promoChoiceByCode.containsKey(trig)) return true;
      final chosen = _promoChoiceByCode[trig];
      if (chosen == null || chosen.isEmpty) return false;
      return p.id == chosen;
    }).toList();
  }

  // Human-readable terms + value of a promotion, shown in the chooser sheet.
  String _promoDetail(Promotion p) {
    if (p.promoType.toLowerCase() == 'bogo') {
      final bonusName =
          _itemByCode(p.bonusItemCode?.trim() ?? '')?.nameLo ??
          (p.bonusItemCode ?? '');
      final tq = (p.triggerQty ?? 1).toInt();
      final bq = (p.bonusQty ?? 1).toInt();
      final bp = p.bonusPriceKip ?? 0;
      final priceTxt = bp > 0 ? 'ລາຄາແຖມ ${_moneyFmt.format(bp)} ກີບ' : 'ຟຣີ';
      return 'ຊື້ $tq ແຖມ $bq · $bonusName · $priceTxt';
    }
    final fp = p.fixedPriceKip ?? 0;
    if (fp > 0) return 'ລາຄາພິເສດ ${_moneyFmt.format(fp)} ກີບ/ໜ່ວຍ';
    return (p.note?.trim().isNotEmpty ?? false) ? p.note!.trim() : 'ໂປຣໂມຊັ່ນ';
  }

  // Short, type-aware headline for a promotion (mirrors the web's
  // promoTypeLabel) — shown under the promo name in the list sheet.
  String _promoTypeLabel(Promotion p) {
    final tq = (p.triggerQty ?? 0).toInt();
    final bq = (p.bonusQty ?? 0).toInt();
    switch (p.promoType.toLowerCase()) {
      case 'bogo':
        return (tq > 0 && bq > 0) ? 'ຊື້ $tq ແຖມ $bq' : 'ຊື້ ແຖມ';
      case 'item_pair_price':
        return 'ຊື້ຄູ່ ໄດ້ລາຄາພິເສດ';
      case 'fixed_price_period':
        return 'ລາຄາພິເສດ ໃນຊ່ວງເວລາ';
      default:
        return p.promoType;
    }
  }

  // Promotions that are active right now (date + time-of-day window).
  List<Promotion> get _activeNowPromos {
    final now = DateTime.now();
    return _activePromos.where((p) => isPromoActiveNow(p, now)).toList();
  }

  // AppBar button → opens the active-promotions list. Carries a small count
  // badge so the cashier sees at a glance how many promos are live.
  Widget _buildPromoAppBarButton() {
    final count = _activeNowPromos.length;
    return Padding(
      padding: const EdgeInsets.only(right: kSpace2),
      child: IconButton(
        tooltip: 'ໂປຣໂມຊັ່ນ',
        onPressed: _openPromotionList,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.local_offer_rounded,
              size: 22,
              color: Colors.white,
            ),
            if (count > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(kRadiusPill),
                    border: Border.all(color: AppColors.primary, width: 1.2),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPromotionList() async {
    final picked = await showModalBottomSheet<Promotion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
      builder: (_) => _PromotionListSheet(
        promotions: _activeNowPromos,
        nameForCode: (code) => _itemByCode(code.trim())?.nameLo,
        typeLabel: _promoTypeLabel,
        fmt: _moneyFmt,
      ),
    );
    if (picked != null && mounted) {
      await _pickPromotion(picked);
    }
  }

  // Add a promotion's trigger product to the cart — one tap lands the line
  // (and any auto BOGO bonus via _setQty). Fetches the product first if it's
  // not in the loaded catalog. Mirrors the web's "ເລືອກ → ກະຕ່າ".
  Future<void> _pickPromotion(Promotion p) async {
    if (_selectedCustomer == null) {
      _promptCustomerFirst();
      return;
    }
    final triggerCode = p.triggerItemCode?.trim() ?? '';
    if (triggerCode.isEmpty) {
      _toast('ໂປຣ "${p.name}": ບໍ່ມີສິນຄ້າຂາຍ');
      return;
    }
    InventoryItem? item = _itemByCode(triggerCode);
    if (item == null) {
      final api = AppScope.of(context).api;
      try {
        final rows = await api.searchInventory(
          triggerCode,
          limit: 5,
          includeSets: true,
        );
        if (!mounted) return;
        for (final r in rows) {
          if (r.code == triggerCode) {
            item = r;
            break;
          }
        }
        item ??= await api.fetchProductByCode(triggerCode);
        if (!mounted) return;
      } catch (e) {
        _toast('ໂປຣ "${p.name}": ໂຫລດສິນຄ້າ $triggerCode ບໍ່ສຳເລັດ');
        return;
      }
    }
    if (item == null) {
      _toast('ໂປຣ "${p.name}": ບໍ່ພົບສິນຄ້າ $triggerCode');
      return;
    }
    final current = _qtyByCode[item.code] ?? 0;
    final ok = await _setQty(item, current + 1);
    if (ok && mounted) {
      HapticFeedback.lightImpact();
      _toast('ເພີ່ມ ${item.nameLo} ✓');
    }
  }

  // Bottom sheet to pick which promotion applies to a line — or opt out.
  Future<void> _choosePromoForLine(InventoryItem p) async {
    final promos = _applicablePromosForProduct(p.code);
    if (promos.isEmpty) return;
    final currentChoice = _promoChoiceByCode.containsKey(p.code)
        ? (_promoChoiceByCode[p.code] ?? '')
        : null;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kSpace5,
                kSpace4,
                kSpace5,
                kSpace2,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ເລືອກໂປຣໂມຊັ່ນ — ${p.nameLo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final promo in promos)
              ListTile(
                leading: Icon(
                  currentChoice == promo.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                ),
                title: Text(
                  promo.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _promoDetail(promo),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, promo.id),
              ),
            Divider(height: 1, color: AppColors.divider),
            ListTile(
              leading: Icon(
                currentChoice == ''
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: AppColors.danger,
              ),
              title: Text(
                'ບໍ່ໃຊ້ໂປຣ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            const SizedBox(height: kSpace2),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _promoChoiceByCode[p.code] = picked.isEmpty ? null : picked;
      _recomputePromotions();
    });
  }

  // Re-run the promotion engine against the current cart. Called whenever
  // the cart shape changes (qty/items) or when promos are first loaded.
  // Output (promoDiscountByCode / promoLabelByCode / totalPromoDiscount) is
  // a snapshot — totals/widgets read from these maps directly.
  void _recomputePromotions() {
    if (_activePromos.isEmpty || _qtyByCode.isEmpty) {
      debugPrint(
        '[Promo] _recomputePromotions: skip (promos=${_activePromos.length} cart=${_qtyByCode.length})',
      );
      _promoDiscountByCode = const {};
      _promoLabelByCode = const {};
      _customerDiscountByCode = const {};
      _awardsPointsByCode = const {};
      _totalPromoDiscount = 0;
      return;
    }
    final lines = <EngineLine>[];
    final skippedNoItem = <String>[];
    for (final entry in _qtyByCode.entries) {
      final item = _itemByCode(entry.key);
      if (item == null) {
        skippedNoItem.add(entry.key);
        continue;
      }
      lines.add(
        EngineLine(
          productId: entry.key,
          quantity: entry.value,
          price: _unitPrice(item),
          customerDiscount: _lineDiscountAmount(item, entry.value),
        ),
      );
    }
    debugPrint(
      '[Promo] _recomputePromotions: ${lines.length} line(s) → '
      '${lines.map((l) => "[${l.productId}]x${l.quantity}@${l.price}").join(",")}'
      '${skippedNoItem.isEmpty ? "" : " (skipped no-item: ${skippedNoItem.join(",")})"}',
    );
    applyPromotions(lines, _effectivePromos(), DateTime.now());

    final disc = <String, double>{};
    final labels = <String, String>{};
    final custDisc = <String, double>{};
    final pts = <String, bool>{};
    double total = 0;
    for (final line in lines) {
      if (!line.awardsMemberDiscount) {
        line.customerDiscount = 0.0;
        final netAmount = line.gross - line.promoDiscount;
        line.amount = netAmount < 0.0 ? 0.0 : netAmount;
      }
      custDisc[line.productId] = line.customerDiscount;
      pts[line.productId] = line.awardsPoints;

      if (line.promoLabel.isNotEmpty) {
        disc[line.productId] = line.promoDiscount;
        labels[line.productId] = line.promoLabel;
        total += line.promoDiscount;
      }
    }
    debugPrint(
      '[Promo] _recomputePromotions: result → '
      'discount=${disc.entries.map((e) => "[${e.key}]=${e.value}").join(",")} '
      'labels=${labels.entries.map((e) => "[${e.key}]=${e.value}").join(",")}',
    );
    _promoDiscountByCode = disc;
    _promoLabelByCode = labels;
    _customerDiscountByCode = custDisc;
    _awardsPointsByCode = pts;
    _totalPromoDiscount = total;
  }

  // Auto-add (or top up) bonus items when a BOGO promo's trigger qty is
  // met. Reuses the trigger's warehouse so the user doesn't get prompted
  // mid-add. If the bonus SKU isn't in the loaded catalog, fetches it via
  // /api/inventory/search before adding. Silent if the bonus item can't
  // be resolved.
  Future<void> _maybeAutoAddBogoBonus() async {
    debugPrint(
      '[Promo] _maybeAutoAddBogoBonus: ${_activePromos.length} promo(s) loaded · '
      'cart keys=${_qtyByCode.entries.map((e) => "[${e.key}]=${e.value}").join(",")}',
    );
    if (_activePromos.isEmpty) return;
    final now = DateTime.now();
    final added = <(String name, int qty, String promoName)>[];
    for (final p in _activePromos) {
      final active = isPromoActiveNow(p, now);
      debugPrint(
        '[Promo] check ${p.id}/${p.promoType}/${p.name} active=$active '
        'trigger=${p.triggerItemCode}x${p.triggerQty} '
        'bonus=${p.bonusItemCode}x${p.bonusQty}',
      );
      if (p.promoType != 'bogo' || !active) continue;
      final tCode = p.triggerItemCode?.trim() ?? '';
      final bCode = p.bonusItemCode?.trim() ?? '';
      final tQty = (p.triggerQty ?? 0).toInt();
      final bQty = (p.bonusQty ?? 0).toInt();
      if (tCode.isEmpty || bCode.isEmpty || tQty <= 0 || bQty <= 0) continue;
      final inCartTrigger = _qtyByCode[tCode] ?? 0;
      final sets = inCartTrigger ~/ tQty;
      final required = sets * bQty;
      final currentBonus = _qtyByCode[bCode] ?? 0;
      debugPrint(
        '[Promo]   inCartTrigger=$inCartTrigger sets=$sets '
        'currentBonus=$currentBonus required=$required',
      );
      if (currentBonus == required) continue;

      if (currentBonus > required) {
        setState(() {
          if (required <= 0) {
            _qtyByCode.remove(bCode);
            _warehouseByItemCode.remove(bCode);
            _locationByItemCode.remove(bCode);
            _approvedPriceByCode.remove(bCode);
            _salespersonByItemCode.remove(bCode);
            _bonusOfByCode.remove(bCode);
          } else {
            _qtyByCode[bCode] = required;
          }
          _recomputePromotions();
        });
        continue;
      }

      InventoryItem? bonusItem = _itemByCode(bCode);
      if (bonusItem == null) {
        debugPrint('[Promo]   bonus $bCode not in catalog, fetching...');
        final api = AppScope.of(context).api;
        try {
          // Search first — fast/cheap when the SKU has stock. Falls back
          // to /api/products/[id] (no stock filter) so a temporarily
          // out-of-stock bonus still resolves; otherwise the cashier
          // adds the trigger and sees no promo at all.
          final rows = await api.searchInventory(
            bCode,
            limit: 5,
            includeSets: true,
          );
          if (!mounted) return;
          for (final r in rows) {
            if (r.code == bCode) {
              bonusItem = r;
              break;
            }
          }
          if (bonusItem == null) {
            debugPrint(
              '[Promo]   search miss ($bCode), falling back to /api/products/$bCode',
            );
            bonusItem = await api.fetchProductByCode(bCode);
            if (!mounted) return;
          }
          debugPrint(
            '[Promo]   search returned ${rows.length} row(s), '
            'matched=${bonusItem != null}',
          );
        } catch (e) {
          debugPrint('[Promo]   fetch failed: $e');
          _toast('ໂປຣ "${p.name}": ໂຫລດສິນຄ້າແຖມ $bCode ບໍ່ສຳເລັດ');
          continue;
        }
        if (bonusItem == null) {
          _toast('ໂປຣ "${p.name}": ບໍ່ພົບສິນຄ້າແຖມ $bCode');
          continue;
        }
      }

      if (!mounted) return;
      final triggerWh = _warehouseByItemCode[tCode];
      final triggerLoc = _locationByItemCode[tCode];
      final delta = required - currentBonus;
      setState(() {
        if (!_allItems.any((i) => i.code == bonusItem!.code)) {
          _allItems = [..._allItems, bonusItem!];
        }
        // Inherit the trigger's warehouse/location when the bonus has none
        // yet — keeps the auto-add silent. Don't override a user-picked
        // warehouse if one was already set on the bonus line.
        if (triggerWh != null && _warehouseByItemCode[bCode] == null) {
          _warehouseByItemCode[bCode] = triggerWh;
        }
        if (triggerLoc != null && _locationByItemCode[bCode] == null) {
          _locationByItemCode[bCode] = triggerLoc;
        }
        _qtyByCode[bCode] = required;
        // Mark this line as a linked bonus so the UI locks its stepper
        // and cascades trigger removal. Idempotent — re-runs of the
        // engine just re-affirm the link.
        _bonusOfByCode[bCode] = tCode;
        _recomputePromotions();
      });
      added.add((bonusItem.nameLo, delta, p.name));
    }
    if (added.isNotEmpty && mounted) {
      final first = added.first;
      _toast(
        added.length == 1
            ? 'ໄດ້ແຖມ ${first.$1} x${first.$2} ຈາກໂປຣ "${first.$3}"'
            : 'ໄດ້ແຖມ ${added.length} ລາຍການຈາກໂປຣໂມຊັ່ນ',
      );
    }
  }

  double get _discountAmount {
    double t = 0;
    for (final entry in _qtyByCode.entries) {
      final item = _itemByCode(entry.key);
      if (item != null) {
        t +=
            _customerDiscountByCode[entry.key] ??
            _lineDiscountAmount(item, entry.value);
      }
    }
    return t;
  }

  double get _lineNetTotal {
    double t = 0;
    for (final entry in _qtyByCode.entries) {
      final item = _itemByCode(entry.key);
      if (item != null) {
        final gross = _unitPrice(item) * entry.value;
        final custDisc =
            _customerDiscountByCode[entry.key] ??
            _lineDiscountAmount(item, entry.value);
        t += gross - custDisc;
      }
    }
    return t;
  }

  // Bill discount cannot push the total negative; the backend clamps too but
  // we also clamp in the UI so totals stay coherent while the user edits.
  // Promo discount is applied before the extra discount cap so a generous
  // promo doesn't leave headroom for a 100k flat-off that would otherwise
  // be silently ignored on the server.
  double get _appliedExtraDiscount {
    if (_extraDiscount <= 0) return 0;
    final remaining = _lineNetTotal - _totalPromoDiscount;
    final cap = remaining < 0 ? 0.0 : remaining;
    return _extraDiscount > cap ? cap : _extraDiscount;
  }

  double _roundUpKipUnit(double value) {
    if (value <= 0) return 0;
    const unit = 1000.0;
    return (value / unit).ceilToDouble() * unit;
  }

  double get _rawTotal {
    final t = _lineNetTotal - _totalPromoDiscount - _appliedExtraDiscount;
    return t < 0 ? 0 : t;
  }

  double get _total => _roundUpKipUnit(_rawTotal);

  double get _roundingAdjustment {
    final diff = _total - _rawTotal;
    return diff > 0.0001 ? diff : 0;
  }

  double get _pointEligibleTotal {
    double t = 0;
    for (final entry in _qtyByCode.entries) {
      final item = _itemByCode(entry.key);
      if (item != null) {
        final awards = _awardsPointsByCode[entry.key] ?? true;
        if (awards) {
          final gross = _unitPrice(item) * entry.value;
          final custDisc =
              _customerDiscountByCode[entry.key] ??
              _lineDiscountAmount(item, entry.value);
          final promo = _promoDiscountByCode[entry.key] ?? 0.0;
          final netLine = gross - custDisc - promo;
          t += netLine < 0.0 ? 0.0 : netLine;
        }
      }
    }
    final eligible = t - _appliedExtraDiscount;
    return eligible < 0.0 ? 0.0 : eligible;
  }

  int get _earnedPoints {
    if (_selectedCustomer == null ||
        !_loyaltyConfig.isActive ||
        _loyaltyConfig.earnKipPerPoint <= 0) {
      return 0;
    }
    return (_pointEligibleTotal / _loyaltyConfig.earnKipPerPoint).floor();
  }

  InventoryItem? _itemByCode(String code) {
    // Check the in-stock browse list first (smaller / hotter), then fall
    // back to the wider server-loaded catalog. Edit-mode pre-fill writes
    // synthetic InventoryItem records into `_allItems` so the cart line
    // can render before /api/inventory/search returns; without this
    // fallback those lines would silently disappear from `_selectedItems`.
    for (final i in _items) {
      if (i.code == code) return i;
    }
    for (final i in _allItems) {
      if (i.code == code) return i;
    }
    return null;
  }

  List<InventoryItem> get _selectedItems =>
      _qtyByCode.keys.map(_itemByCode).whereType<InventoryItem>().toList();

  // A cart line is "ready" to submit when its source is fully chosen.
  // Normal items need a warehouse + a shelf location; set (ຊຸດ) items are
  // warehouse-level only (the server explodes them into components), so a
  // picked warehouse is enough.
  bool _lineReady(String code) {
    if (_warehouseByItemCode[code] == null) return false;
    final item = _itemByCode(code);
    if (item != null && _isSetItem(item)) return true;
    return _locationByItemCode[code]?.location?.trim().isNotEmpty ?? false;
  }

  bool get _canSubmit =>
      _selectedCustomer != null &&
      _selectedDelivery != null &&
      _qtyByCode.isNotEmpty &&
      _qtyByCode.keys.every(_lineReady);

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
    if (wh == null) return -1;
    // Set lines have no shelf location — their "stock" is how many whole
    // sets the picked warehouse can build (component-limited).
    if (_isSetItem(item)) {
      return _buildableSetsByCode[item.code] ?? -1;
    }
    final loc = _locationByItemCode[item.code]?.location?.trim();
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

    if (mounted) setState(() => _inventorySyncing = true);
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
      if (mounted) setState(() => _inventorySyncing = false);
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
        _salespersonByItemCode.remove(item.code);
        _bonusOfByCode.remove(item.code);
        _buildableSetsByCode.remove(item.code);
        _setDetailsByCode.remove(item.code);
        // Cascade: if this item is the trigger of any linked bonus,
        // remove those bonuses too. Web POS does the same — bonus is
        // tied to the trigger's lifetime.
        final cascaded = <String>[];
        _bonusOfByCode.removeWhere((bCode, tCode) {
          if (tCode == item.code) {
            cascaded.add(bCode);
            return true;
          }
          return false;
        });
        for (final bCode in cascaded) {
          _qtyByCode.remove(bCode);
          _warehouseByItemCode.remove(bCode);
          _locationByItemCode.remove(bCode);
          _approvedPriceByCode.remove(bCode);
          _salespersonByItemCode.remove(bCode);
          _buildableSetsByCode.remove(bCode);
          _setDetailsByCode.remove(bCode);
        }
        _recomputePromotions();
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

    final isSet = _isSetItem(item);
    if (_warehouseByItemCode[item.code] == null ||
        _locationByItemCode[item.code] == null) {
      final picked = await _promptWarehouseForItem(item);
      if (picked == null || !mounted) return false;
      // Don't commit a set's warehouse if it can't build a single whole set —
      // otherwise the line gets stuck (the picker only re-opens while no
      // warehouse is chosen). Let the cashier pick a different warehouse.
      if (isSet && picked.stock.floor() < 1) {
        _toast('ສ້າງຊຸດບໍ່ໄດ້ໃນສາງນີ້ — stock ສ່ວນປະກອບບໍ່ພໍ');
        return false;
      }
      setState(() {
        _selectedDelivery ??= _defaultDeliveryForWarehouse(picked.warehouse);
        _warehouseByItemCode[item.code] = picked.warehouse;
        _locationByItemCode[item.code] = picked.location;
        if (isSet) {
          // Warehouse-level buildability — no shelf location / stock key.
          _buildableSetsByCode[item.code] = picked.stock;
        } else {
          final locationCode = picked.location.location?.trim() ?? '';
          _stockByLineKey = {
            ..._stockByLineKey,
            _lineStockKey(item.code, picked.warehouse.code, locationCode):
                picked.stock,
          };
        }
      });
    } else if (!isSet && _itemStock(item) < 0) {
      await _refreshStockForCodes([item.code]);
      if (!mounted) return false;
    }

    // Sets are hard-capped at how many whole sets the chosen warehouse can
    // build — the server rejects (no backorder) when a component runs short,
    // so we clamp here and tell the cashier, mirroring the web set-build flow.
    if (isSet) {
      final buildable = (_buildableSetsByCode[item.code] ?? 0).floor();
      if (buildable < 1) {
        _toast('ສ້າງຊຸດບໍ່ໄດ້ໃນສາງນີ້ — stock ສ່ວນປະກອບບໍ່ພໍ');
        return false;
      }
      if (qty > buildable) {
        qty = buildable;
        _toast('ສ້າງໄດ້ສູງສຸດ $buildable ຊຸດໃນສາງນີ້');
      }
    }

    // Backorder is allowed for normal items — we no longer reject when
    // stock < qty. The shortfall is shown inline on the cart row and the
    // server writes an app_backorder row when the order is created.
    setState(() {
      if (!_allItems.any((p) => p.code == item.code)) {
        _allItems = [..._allItems, item];
      }
      if (!_items.any((p) => p.code == item.code) && item.companyBalance > 0) {
        _items = [..._items, item];
      }
      _qtyByCode[item.code] = qty < 1 ? 1 : qty;
      _recomputePromotions();
    });
    // Check BOGO promos after the qty change so any newly-met trigger
    // thresholds top up the bonus line for the user.
    await _maybeAutoAddBogoBonus();
    return true;
  }

  Future<void> _pickWarehouseForLine(InventoryItem item) async {
    final picked = await _promptWarehouseForItem(item);
    if (picked == null || !mounted) return;
    final isSet = _isSetItem(item);
    final currentQty = _qtyByCode[item.code] ?? 1;
    setState(() {
      _selectedDelivery ??= _defaultDeliveryForWarehouse(picked.warehouse);
      _warehouseByItemCode[item.code] = picked.warehouse;
      _locationByItemCode[item.code] = picked.location;
      if (isSet) {
        _buildableSetsByCode[item.code] = picked.stock;
        // Re-cap the line against the newly-picked warehouse's buildability.
        final buildable = picked.stock.floor();
        final next = currentQty < 1 ? 1 : currentQty;
        _qtyByCode[item.code] = buildable >= 1 && next > buildable
            ? buildable
            : next;
      } else {
        final locationCode = picked.location.location?.trim() ?? '';
        _stockByLineKey = {
          ..._stockByLineKey,
          _lineStockKey(item.code, picked.warehouse.code, locationCode):
              picked.stock,
        };
        _qtyByCode[item.code] = currentQty < 1 ? 1 : currentQty;
      }
    });
    if (isSet && (_buildableSetsByCode[item.code] ?? 0).floor() < 1 && mounted) {
      _toast('ສ້າງຊຸດບໍ່ໄດ້ໃນສາງນີ້ — stock ສ່ວນປະກອບບໍ່ພໍ');
    }
  }

  // Fetches stock for a single item across all warehouses, then lets the user
  // choose the source warehouse from that item's cart line.
  Future<_PickedWarehouseStock?> _promptWarehouseForItem(
    InventoryItem item,
  ) async {
    setState(() => _inventorySyncing = true);
    List<_WarehouseStockOption> options = const [];
    String? loadError;
    try {
      options = _isSetItem(item)
          ? await _warehouseOptionsForSetItem(item)
          : await _warehouseOptionsForSingleItem(item);
    } catch (e) {
      debugPrint('CreateOrder: stock fetch failed → $e');
      loadError = e.toString();
    } finally {
      if (mounted) setState(() => _inventorySyncing = false);
    }
    if (!mounted) return null;

    // Even if stock fetching fails, fall back to listing every known
    // warehouse with synthetic zero-stock options. The user can still
    // create the order — the backend records a backorder entry. Never
    // dead-end the user with a closed toast.
    if (options.isEmpty) {
      options = [
        for (final wh in _warehouses)
          _WarehouseStockOption(
            warehouse: wh,
            location: StockLocation(
              warehouse: wh.code,
              warehouseName: wh.name,
              location: wh.code,
              locationName: wh.name,
              balanceQty: 0,
              averageCost: 0,
              averageCostEnd: 0,
              balanceAmount: 0,
            ),
            stock: 0,
          ),
      ];
    }

    if (options.isEmpty) {
      _toast(
        loadError != null
            ? 'ດຶງ stock ບໍ່ສຳເລັດ ແລະ ບໍ່ມີສາງ — ກວດການເຊື່ອມຕໍ່ກັບ server'
            : 'ບໍ່ມີສາງໃຫ້ເລືອກ — ກະລຸນາລ໋ອກອິນໃໝ່',
      );
      return null;
    }

    // If we hit an error but still surfaced fallback warehouses, give the
    // user a non-blocking heads-up so they know they're picking a backorder.
    if (loadError != null && mounted) {
      _toast('ດຶງ stock ບໍ່ສຳເລັດ — ສະແດງສາງທັງໝົດ (backorder)');
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
    // Lean call — the new /api/inventory/stock-locations endpoint runs the
    // warehouse-location stock function with WHERE balance_qty > 0 and
    // returns only the three columns we need.
    final rows = await AppScope.of(context).api.fetchStockLocations(item.code);

    final options = <_WarehouseStockOption>[];
    for (final row in rows) {
      final code = row.warehouse?.trim();
      if (code == null || code.isEmpty) continue;
      final locationCode = row.location?.trim();
      if (locationCode == null || locationCode.isEmpty) continue;
      // Prefer the warehouse name returned by the API (live from
      // ic_warehouse). Fall back to the cached list, then to the code
      // itself so an unfamiliar warehouse still renders.
      final apiName = row.warehouseName?.trim();
      final cached = _warehouseByCode(code);
      final wh = Warehouse(
        code: code,
        name: (apiName != null && apiName.isNotEmpty)
            ? apiName
            : (cached?.name ?? code),
      );
      final stock = row.balanceQty.toDouble();
      options.add(
        _WarehouseStockOption(
          warehouse: wh,
          location: StockLocation(
            warehouse: code,
            warehouseName: wh.name,
            location: locationCode,
            locationName: row.locationName?.trim().isNotEmpty == true
                ? row.locationName
                : locationCode,
            balanceQty: stock,
            averageCost: 0,
            averageCostEnd: 0,
            balanceAmount: 0,
          ),
          stock: stock,
        ),
      );
    }
    return options;
  }

  Future<List<_WarehouseStockOption>> _warehouseOptionsForSetItem(
    InventoryItem item,
  ) async {
    final api = AppScope.of(context).api;
    // Mirror the web set-build modal: ask the server how many whole sets
    // each warehouse can build (component stock summed across shelf
    // locations, filtered to the configured sales warehouses). In parallel
    // pull the set's component list so the cart line can render
    // "ຊຸດ: N ລາຍການ" like the web POS.
    final results = await Future.wait([
      api.fetchSetAvailability(item.code),
      api.fetchProductSetDetails(item.code),
    ]);
    final availability = results[0] as SetAvailability;
    final details = (results[1] as List<ProductSetDetailItem>)
        .where((d) => d.itemCode.trim().isNotEmpty)
        .toList();
    if (mounted && details.isNotEmpty) {
      _setDetailsByCode[item.code] = details;
    }

    final options = <_WarehouseStockOption>[];
    for (final wh in availability.warehouses) {
      final code = wh.warehouseCode.trim();
      if (code.isEmpty) continue;
      final stock = wh.buildableSets;
      final name = wh.warehouseName.trim().isNotEmpty
          ? wh.warehouseName
          : (_warehouseByCode(code)?.name ?? code);
      options.add(
        _WarehouseStockOption(
          warehouse: Warehouse(code: code, name: name),
          // Set lines are warehouse-level — no shelf location. The server
          // explodes the set into components at settle time and writes the
          // default shelf itself, so we deliberately leave `location` null.
          location: StockLocation(
            warehouse: code,
            warehouseName: name,
            location: null,
            balanceQty: stock,
            unitCode: 'ຊຸດ',
            averageCost: 0,
            averageCostEnd: 0,
            balanceAmount: 0,
          ),
          stock: stock,
        ),
      );
    }
    return options;
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

  void _promptCustomerFirst() {
    _toast('ກະລຸນາເລືອກລູກຄ້າກ່ອນ');
    unawaited(_pickCustomer());
  }

  Future<void> _pickDelivery() async {
    // If the background bootstrap hasn't returned yet (or its fetch
    // failed/timed out), retry on-demand — block the tap with a brief
    // spinner and surface the actual error if it still comes back empty.
    if (_deliveries.isEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ກຳລັງໂຫລດປະເພດການຮັບສິນຄ້າ…'),
          duration: Duration(seconds: 2),
        ),
      );
      try {
        final rows = await AppScope.of(
          context,
        ).api.listTransportTypes().timeout(const Duration(seconds: 10));
        if (!mounted) return;
        setState(() => _deliveries = rows);
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('ໂຫລດປະເພດການຮັບສິນຄ້າບໍ່ສຳເລັດ: $e')),
        );
        return;
      }
      if (_deliveries.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('ບໍ່ມີປະເພດການຮັບສິນຄ້າ — ກະລຸນາຕິດຕໍ່ admin'),
          ),
        );
        return;
      }
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

  // Per-line salesperson picker (web POS parity) — writes into
  // `_salespersonByItemCode` so the override applies to a single cart line.
  Future<void> _pickSalespersonForLine(InventoryItem item) async {
    final current = _salespersonByItemCode[item.code] ?? _selectedSalesperson;
    final picked = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SalespersonPickerSheet(
        employees: _employees,
        selectedCode: current?.employeeCode,
      ),
    );
    if (picked != null) {
      setState(() => _salespersonByItemCode[item.code] = picked);
    }
  }

  Future<void> _scanBarcode() async {
    if (_selectedCustomer == null) {
      _promptCustomerFirst();
      return;
    }
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
      HapticFeedback.heavyImpact();
      _toast('ບໍ່ພົບສິນຄ້າ: $value');
      return;
    }
    final current = _qtyByCode[found.code] ?? 0;
    final added = await _setQty(found, current + 1);
    if (added) {
      HapticFeedback.lightImpact();
      _toast('ເພີ່ມ ${found.nameLo} ✓');
    }
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
        if (wh == null) {
          throw ApiException(400, 'ກະລຸນາເລືອກສາງ ແລະ ທີ່ຈັດເກັບໃຫ້ທຸກລາຍການ');
        }
        final item = _itemByCode(entry.key);
        // Set (ຊຸດ) lines are warehouse-level and were already hard-capped at
        // their buildable count when added — there's no backorder path for
        // them (the server rejects component shortfalls outright), so skip
        // the shelf-location requirement and the backorder check.
        if (item != null && _isSetItem(item)) continue;
        final loc = _locationByItemCode[entry.key];
        final locationCode = loc?.location?.trim();
        if (locationCode == null || locationCode.isEmpty) {
          throw ApiException(400, 'ກະລຸນາເລືອກສາງ ແລະ ທີ່ຈັດເກັບໃຫ້ທຸກລາຍການ');
        }
        final stock =
            _stockByLineKey[_lineStockKey(entry.key, wh.code, locationCode)] ??
            0;
        if (stock < entry.value) {
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
              // Per-line override → backend prefers this over the cart-
              // level salespersonCode for that one line.
              salespersonCode: _salespersonByItemCode[entry.key]?.employeeCode,
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
        promoSelections: _promoChoiceByCode,
      );
      // Edit-by-replacement: after the new bill posts, hard-delete the
      // source order — matches the web's `/api/cashier/orders/[cartNumber]`
      // DELETE behaviour so an edit feels in-place (the old cart_number
      // disappears, the new one takes its place). If the delete fails the
      // new order still stands; we surface the issue and let the user
      // clean up the orphan via the Cancel/Delete buttons.
      final src = widget.editOrder;
      if (src != null && mounted) {
        try {
          await AppScope.of(context).api.deleteOrder(src.id);
        } catch (e) {
          if (mounted) {
            _toast('ບັນທຶກໃໝ່ສຳເລັດ ແຕ່ລົບບິນເກົ່າບໍ່ສຳເລັດ: $e');
          }
        }
      }
      if (!mounted) return;
      // Two soft pulses → success cue without the harsh "error buzz".
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
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
    final isEdit = widget.editOrder != null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: kSpace2),
          child: IconButton(
            tooltip: 'ປິດ',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.close_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
        leadingWidth: 56,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? 'ແກ້ໄຂບິນ' : 'ສ້າງບິນໃໝ່',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
                height: 1.1,
              ),
            ),
            if (isEdit)
              Text(
                widget.editOrder!.docNo ??
                    '#${widget.editOrder!.id.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
          ],
        ),
        actions: [_buildPromoAppBarButton()],
      ),
      body: _loading
          ? const BrandedSpinner(label: 'ກຳລັງເຕັມບິນ…')
          : _tabletConstrain(_orderEntryBody()),
      bottomNavigationBar: _loading
          ? null
          : _tabletConstrain(_buildMainSubmitBar()),
    );
  }

  // Single-page order entry. Customer stays above products so the cashier
  // sees the required first step without switching tabs.
  Widget _orderEntryBody() {
    final selected = _selectedItems;
    return Column(
      children: [
        // POS terminal top bar — customer + running total stay pinned and
        // always visible while the cashier scrolls the cart.
        _posHeaderBar(),
        Expanded(
          child: ListView(
            key: const PageStorageKey('create-order-entry'),
            padding: const EdgeInsets.fromLTRB(
              kSpace4,
              kSpace3,
              kSpace4,
              kSpace5,
            ),
            children: [
              _miniLabel(
                'ສິນຄ້າ',
                trailing: selected.isEmpty
                    ? null
                    : '${selected.length} ລາຍການ',
              ),
              _posCard(_itemsSectionBody(selected)),
              const SizedBox(height: kSpace3),
              _miniLabel('ການຮັບສິນຄ້າ'),
              _posCard(_deliveryPickerRow()),
              const SizedBox(height: kSpace3),
              _miniLabel('ສ່ວນຫຼຸດ ແລະ ໝາຍເຫດ'),
              _posCard(_compactSettingsRow()),
              const SizedBox(height: kSpace3),
              _miniLabel('ສະຫຼຸບ'),
              _posCard(_summarySection()),
            ],
          ),
        ),
      ],
    );
  }

  // Pinned POS header: customer selector on the left, live bill total on the
  // right — the two things a cashier needs in view at all times.
  Widget _posHeaderBar() {
    final c = _selectedCustomer;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _pickCustomer,
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ລູກຄ້າ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c?.name ?? 'ເລືອກລູກຄ້າ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.expand_more_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (c != null) ...[
            const SizedBox(width: kSpace2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.discountPct > 0)
                  _headerChip(
                    'ສ່ວນຫຼຸດ',
                    '−${c.discountPct == c.discountPct.toInt() ? c.discountPct.toInt() : c.discountPct.toStringAsFixed(1)}%',
                  ),
                if (c.discountPct > 0 && _loyaltyConfig.isActive)
                  const SizedBox(height: 5),
                if (_loyaltyConfig.isActive)
                  _headerChip(
                    'ແຕ້ມສະສົມ',
                    '${_fmt.format(c.pointBalance)} ${_loyaltyConfig.pointName}',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Small white pill used on the purple header to show the picked customer's
  // member discount and loyalty balance.
  Widget _headerChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // Lightweight section label (replaces the boxy PageSection header for the
  // dense POS look).
  Widget _miniLabel(String text, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 7),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Flat surface for section content — lighter than PageSection.
  Widget _posCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(
          color: AppColors.border.withValues(
            alpha: ThemeService.isDark ? 0.3 : 0.6,
          ),
          width: 0.8,
        ),
      ),
      child: child,
    );
  }

  // The "Items" card content — empty state with a prominent CTA, or
  // cart lines stacked with an inline add button at the bottom.
  Widget _itemsSectionBody(List<InventoryItem> selected) {
    if (selected.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 40,
                  color: AppColors.textMuted.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 10),
                Text(
                  'ຍັງບໍ່ມີລາຍການ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ກົດເພີ່ມສິນຄ້າ ຫຼື ສະແກນ barcode',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          _addProductRow(),
        ],
      );
    }
    return Column(
      children: [
        ..._buildCartLines(selected, () {
          if (mounted) setState(() {});
        }),
        const SizedBox(height: 10),
        Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 10),
        _addProductRow(),
      ],
    );
  }



  // Primary CTA + scan button — used both inside the empty state and
  // beneath the cart list so the user can always add more items.
  Widget _addProductRow() {
    final hasCustomer = _selectedCustomer != null;
    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: InkWell(
              onTap: hasCustomer
                  ? _openProductPickerSheet
                  : _promptCustomerFirst,
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'ເພີ່ມສິນຄ້າ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.accent.withValues(
            alpha: ThemeService.isDark ? 0.18 : 0.10,
          ),
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: InkWell(
            onTap: hasCustomer ? _scanBarcode : _promptCustomerFirst,
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: Container(
              width: 42,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: Icon(
                Icons.qr_code_scanner,
                size: 18,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Delivery type + discount + note collapsed into a single chip row.
  // Delivery type lives next to the submit button now — only discount
  // and note live up here in the hero panel.
  Widget _compactSettingsRow() {
    final hasNote = _note.trim().isNotEmpty;
    final hasExtra = _appliedExtraDiscount > 0;
    return Row(
      children: [
        Expanded(
          child: _compactChip(
            icon: hasExtra ? Icons.local_offer : Icons.local_offer_outlined,
            label: hasExtra
                ? '−${_moneyFmt.format(_appliedExtraDiscount)}'
                : 'ສ່ວນຫຼຸດ',
            active: hasExtra,
            onTap: () async {
              await _editExtraDiscount();
              if (mounted) setState(() {});
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _compactChip(
            icon: hasNote ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
            label: hasNote ? _note : 'ໝາຍເຫດ',
            active: hasNote,
            onTap: () async {
              await _editNote();
              if (mounted) setState(() {});
            },
          ),
        ),
      ],
    );
  }

  // Delivery picker that sits right above the submit button. Slim,
  // full-width row showing the picked option (or an empty-state prompt
  // when nothing is selected yet).
  Widget _deliveryPickerRow() {
    final dlv = _selectedDelivery;
    final active = dlv != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickDelivery,
        borderRadius: BorderRadius.circular(kRadiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 18,
                color: active ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Text(
                'ປະເພດການຮັບ:',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dlv?.name ?? 'ກົດເພື່ອເລືອກ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: active ? AppColors.textPrimary : AppColors.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? AppColors.gold.withValues(alpha: 0.10) : AppColors.cardBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(
              color: active
                  ? AppColors.gold.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? AppColors.gold : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sticky submit bar at the bottom of the cart-first body. Single
  // primary action — label doubles as a hint when something is missing
  // (customer / items / warehouse / salesperson…) so the user always
  // knows what still needs to be filled in.
  Widget _buildMainSubmitBar() {
    String? blocker;
    VoidCallback? blockerAction;
    if (_selectedCustomer == null) {
      blocker = 'ເລືອກລູກຄ້າກ່ອນ';
      blockerAction = _pickCustomer;
    } else if (_qtyByCode.isEmpty) {
      blocker = 'ເພີ່ມສິນຄ້າຢ່າງໜ້ອຍ 1 ລາຍການ';
      blockerAction = _openProductPickerSheet;
    } else if (!_qtyByCode.keys.every(_lineReady)) {
      blocker = 'ເລືອກສາງ+ພື້ນທີ່ໃຫ້ທຸກລາຍການ';
      blockerAction = () => _toast('ກົດລາຍການສິນຄ້າເພື່ອເລືອກສາງ');
    } else if (_selectedDelivery == null) {
      blocker = 'ເລືອກປະເພດການຮັບສິນຄ້າ';
      blockerAction = _pickDelivery;
    }
    // Salesperson is per-line and defaults to the logged-in user via
    // didChangeDependencies, so a missing salesperson is no longer a
    // user-facing blocker — submit only gates on customer / items /
    // warehouse / delivery now.

    final enabled = blocker == null && !_submitting;
    final label = _submitting
        ? 'ກຳລັງບັນທຶກ…'
        : (widget.editOrder != null ? 'ບັນທຶກການແກ້ໄຂ' : 'ສ້າງບິນ');
    // Tap-through for blockers opens the missing picker directly.
    final onTap = enabled ? _submit : (!_submitting ? blockerAction : null);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        kSpace4,
        kSpace3,
        kSpace4,
        kSpace3 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent grand-total readout — promoted out of the hero
          // card so the cashier always sees the bill amount without
          // switching to the ສະຫຼຸບ tab.
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ຍອດບິນ',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedItems.length} ລາຍການ',
                    style: TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                _moneyFmt.format(_total),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'ກີບ',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace2),
          SizedBox(
            width: double.infinity,
            height: kTouchTargetLg,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      enabled ? Icons.check_circle_outline : Icons.info_outline,
                      size: 22,
                    ),
              label: Text(
                blocker ?? label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusLg),
                ),
                // Blocked states still need to be tappable so the missing
                // picker can open directly.
                backgroundColor: enabled
                    ? AppColors.primary
                    : AppColors.warning,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.warning,
                disabledForegroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Product picker sheet — opened by the "ເພີ່ມສິນຄ້າ" button. Sheet
  // auto-closes after each successful add so the cashier returns to the
  // cart immediately; re-opening and tapping the same row again bumps
  // its quantity (in-cart items stay visible in the picker).
  Future<void> _openProductPickerSheet() async {
    if (_selectedCustomer == null) {
      _promptCustomerFirst();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => StatefulBuilder(
          builder: (sbCtx, setSheetState) {
            void refresh() {
              if (mounted) setState(() {});
              setSheetState(() {});
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Row(
                    children: [
                      Text(
                        'ເລືອກສິນຄ້າ',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                ),
                _buildSearchRow(refresh: refresh),
                Expanded(
                  child: _buildProductListForPicker(
                    controller,
                    refresh,
                    onAddDone: () {
                      if (Navigator.of(sheetCtx).canPop()) {
                        Navigator.of(sheetCtx).pop();
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductListForPicker(
    ScrollController controller,
    VoidCallback refresh, {
    required VoidCallback onAddDone,
  }) {
    final filtered = _filteredProducts();
    if (_inventorySyncing && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filtered.isEmpty) {
      return EmptyStateView(
        icon: _query.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
        title: _query.isEmpty
            ? 'ຍັງບໍ່ມີສິນຄ້າ'
            : 'ບໍ່ພົບສິນຄ້າທີ່ກົງກັບ "${_query.trim()}"',
        subtitle: _query.isEmpty
            ? 'ດຶງ refresh ເພື່ອໂຫຼດໃໝ່'
            : 'ລອງປ່ຽນຄຳຄົ້ນ ຫຼື ສະແກນ barcode',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _syncInventory(),
      child: ListView.separated(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final p = filtered[i];
          final qty = _qtyByCode[p.code] ?? 0;
          final stock = _itemStock(p);
          final promo = _activePromoForProduct(p.code);
          return _ProductTile(
            item: p,
            qty: qty,
            stock: stock,
            companyBalance: p.companyBalance,
            unitPrice: _unitPrice(p),
            fmt: _moneyFmt,
            promoName: promo?.name,
            onTap: () async {
              // Promo first: a product with promo(s) the cashier hasn't decided
              // on yet opens the chooser (details + value) before the warehouse
              // picker fires and the line is added.
              final ap = _applicablePromosForProduct(p.code);
              if (ap.isNotEmpty && !_promoChoiceByCode.containsKey(p.code)) {
                await _choosePromoForLine(p);
                if (!mounted) return;
              }
              // Re-tapping an in-cart row bumps qty by 1 — backorders are
              // allowed (the cart line shows the shortfall inline) so we
              // don't block past stock.
              // First-add fires the warehouse picker inside _setQty; only
              // close the picker if a warehouse was actually chosen.
              // Subsequent increments always return true.
              final ok = await _setQty(p, qty + 1);
              refresh();
              if (ok && mounted) onAddDone();
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchRow({VoidCallback? refresh}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) => _handleSearchChanged(v, refresh: refresh),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'ຄົ້ນຫາ ຫຼື ສະແກນ barcode',
                isDense: true,
                prefixIcon: _serverSearching
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtl.clear();
                          _handleSearchChanged('', refresh: refresh);
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: OutlinedButton(
              onPressed: _scanBarcode,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
              ),
              child: const Icon(Icons.qr_code_scanner, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCartLines(
    List<InventoryItem> selected,
    VoidCallback refresh,
  ) {
    final rows = <Widget>[];
    for (var i = 0; i < selected.length; i++) {
      final p = selected[i];
      final qty = _qtyByCode[p.code] ?? 0;
      final stock = _itemStock(p);
      final unitPrice = _unitPrice(p);
      final gross = unitPrice * qty;
      final discountAmount =
          _customerDiscountByCode[p.code] ?? _lineDiscountAmount(p, qty);
      final promo = _promoDiscountByCode[p.code] ?? 0;
      // Net = gross − customer discount − promo, clamped at 0 so a
      // free-bonus line renders as "0" not negative.
      final lineTotal = (gross - discountAmount - promo).clamp(
        0.0,
        double.infinity,
      );
      // Free bonus: engine zeroed out the whole line (promo == gross or net <= 0).
      // Promo sold: engine applied savings but line still has value.
      // Both flags drive the badge + price color in `_SelectedRow`.
      final promoLabel = _promoLabelByCode[p.code] ?? '';
      final hasPromo = promoLabel.isNotEmpty;
      final isFreeBonus = hasPromo && gross > 0 && lineTotal <= 0;
      final isPromoSold = hasPromo && !isFreeBonus;
      // After-promo per-unit price → drives the line's price text.
      // Free bonus shows "ຟຣີ" so this is only meaningful for promo-sold.
      final effectiveUnitPrice = qty > 0 ? lineTotal / qty : unitPrice;
      final isLinkedBonus = _bonusOfByCode.containsKey(p.code);
      if (i > 0) {
        rows.add(Divider(height: 1, color: AppColors.divider));
      }
      rows.add(
        _SelectedRow(
          item: p,
          qty: qty,
          stock: stock,
          warehouse: _warehouseByItemCode[p.code],
          location: _locationByItemCode[p.code],
          subtotal: gross,
          discountPct: _discountPct,
          discountAmount: discountAmount,
          lineTotal: lineTotal,
          unitPrice: unitPrice,
          effectiveUnitPrice: effectiveUnitPrice,
          approvedPrice: _approvedPriceByCode[p.code],
          lineSalesperson:
              _salespersonByItemCode[p.code] ?? _selectedSalesperson,
          promoDiscount: promo,
          promoLabel: _promoLabelByCode[p.code] ?? '',
          isFreeBonus: isFreeBonus,
          isPromoSold: isPromoSold,
          isLinkedBonus: isLinkedBonus,
          isSet: _isSetItem(p),
          setDetails: _setDetailsByCode[p.code] ?? const [],
          fmt: _moneyFmt,
          onDec: () async {
            await _setQty(p, qty - 1);
            refresh();
          },
          onInc: () async {
            await _setQty(p, qty + 1);
            refresh();
          },
          onRemove: () async {
            await _setQty(p, 0);
            refresh();
          },
          onPickWarehouse: () async {
            await _pickWarehouseForLine(p);
            refresh();
          },
          onPickSalesperson: () async {
            await _pickSalespersonForLine(p);
            refresh();
          },
          onRequestPrice: () async {
            await _requestPriceForLine(p);
            refresh();
          },
        ),
      );
    }
    return rows;
  }

  Widget _tabletConstrain(Widget child) {
    if (!isTablet(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
  }

  // ── Inline product search ─────────────────────────────────────────────
  // Lifted from _ProductPickerSheet so the product grid can live on the
  // main page. Source list is `allItems` when populated (server cache),
  // otherwise `items` (small in-stock browse list).
  void _rebuildSearchIndex() {
    final source = _allItems.isNotEmpty ? _allItems : _items;
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

  // Optional `refresh` callback is invoked after each state mutation so a
  // host (e.g. the product picker's StatefulBuilder) can rebuild — parent
  // setState alone wouldn't reach a sibling scope.
  void _handleSearchChanged(String value, {VoidCallback? refresh}) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _query = value);
      refresh?.call();
      unawaited(_runServerSearch(value.trim(), refresh: refresh));
    });
  }

  Future<void> _runServerSearch(String value, {VoidCallback? refresh}) async {
    final seq = ++_searchSeq;
    if (value.isEmpty) {
      if (mounted) {
        setState(() {
          _serverSearching = false;
          _serverResults = const [];
        });
        refresh?.call();
      }
      return;
    }
    setState(() => _serverSearching = true);
    refresh?.call();
    try {
      final normalized = value.toLowerCase();
      final isAirQuery = normalized == 'ແອ' || normalized == 'air';
      final rows = await AppScope.of(context).api.searchInventory(
        value,
        limit: isAirQuery ? 1000 : 20,
        includeSets: true,
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() => _serverResults = rows);
      _rebuildSearchIndex();
      refresh?.call();
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() => _serverResults = const []);
      refresh?.call();
    } finally {
      if (mounted && seq == _searchSeq) {
        setState(() => _serverSearching = false);
        refresh?.call();
      }
    }
  }

  // Returns the products that should appear in the main grid given the
  // current query. Empty query → curated in-stock browse list. Non-empty
  // query → matches against the searchable index, merged with server hits.
  List<InventoryItem> _filteredProducts() {
    final rawQuery = _query.trim().toLowerCase();
    final isAirQuery = rawQuery == 'ແອ' || rawQuery == 'air';
    final q = isAirQuery ? 'air' : rawQuery;

    final source = q.isEmpty || _allItems.isEmpty ? _items : _allItems;
    final local = source.where((p) {
      final qty = _qtyByCode[p.code] ?? 0;
      if (q.isEmpty) {
        final stock = _itemStock(p);
        if (qty <= 0 && p.companyBalance <= 0) return false;
        if (stock >= 0 && stock <= 0 && qty <= 0) return false;
        return true;
      }
      if (!(_searchIndex[p.code]?.contains(q) ?? false)) return false;
      // Hide zero-stock items from the search results — the user asked to
      // only see sellable items when actively searching. Items already in
      // the cart stay visible so they can edit qty.
      if (qty > 0) return true;
      return p.companyBalance > 0;
    }).toList();

    final byCode = {for (final p in local) p.code: p};
    for (final p in _serverResults) {
      final qty = _qtyByCode[p.code] ?? 0;
      // Same stock-only rule for server-side hits.
      if (qty <= 0 && p.companyBalance <= 0) continue;
      byCode.putIfAbsent(p.code, () => p);
    }
    final merged = byCode.values.toList();
    if (q.isEmpty) return merged.take(60).toList();
    if (isAirQuery) return merged;
    return merged.take(60).toList();
  }

  Widget _summarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow('Subtotal', '${_moneyFmt.format(_lineNetTotal)} ກີບ'),
        if (_discountPct > 0) ...[
          const SizedBox(height: 6),
          _summaryRow(
            'ສ່ວນຫຼຸດສະມາຊິກ ${_discountPct == _discountPct.toInt() ? _discountPct.toInt() : _discountPct.toStringAsFixed(1)}%',
            '−${_moneyFmt.format(_discountAmount)} ກີບ',
          ),
        ],
        if (_totalPromoDiscount > 0) ...[
          const SizedBox(height: 6),
          _summaryRow(
            'ສ່ວນຫຼຸດໂປຣໂມຊັ່ນ',
            '−${_moneyFmt.format(_totalPromoDiscount)} ກີບ',
          ),
        ],
        if (_appliedExtraDiscount > 0) ...[
          const SizedBox(height: 6),
          _summaryRow(
            'ສ່ວນຫຼຸດທ້າຍບິນ',
            '−${_moneyFmt.format(_appliedExtraDiscount)} ກີບ',
          ),
        ],
        if (_roundingAdjustment > 0) ...[
          const SizedBox(height: 6),
          _summaryRow(
            'ປັດຂຶ້ນເປັນ 1,000',
            '+${_moneyFmt.format(_roundingAdjustment)} ກີບ',
          ),
        ],
        const SizedBox(height: 6),
        _summaryRow(
          _loyaltyConfig.isActive
              ? 'ໄດ້${_loyaltyConfig.pointName}'
              : 'ສະສົມແຕ້ມ',
          _loyaltyConfig.isActive
              ? '${_fmt.format(_earnedPoints)} ແຕ້ມ'
              : 'ປິດໃຊ້',
        ),
        const SizedBox(height: kSpace3),
        Divider(height: 1, color: AppColors.border),
        const SizedBox(height: kSpace3),
        Row(
          children: [
            Text(
              'ລວມທັງໝົດ',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Text(
              _moneyFmt.format(_total),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'ກີບ',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
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
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
    required this.unitPrice,
    required this.effectiveUnitPrice,
    required this.fmt,
    required this.onDec,
    required this.onInc,
    required this.onRemove,
    required this.onPickWarehouse,
    required this.onRequestPrice,
    required this.onPickSalesperson,
    required this.approvedPrice,
    required this.lineSalesperson,
    required this.promoDiscount,
    required this.promoLabel,
    required this.isFreeBonus,
    required this.isPromoSold,
    required this.isLinkedBonus,
    required this.isSet,
    required this.setDetails,
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
  // Catalog/approved unit price BEFORE any promo (the engine's input).
  final double unitPrice;
  // Per-unit price AFTER the promo. For free bonus it's 0; for promo-sold
  // it's the engine's reduced rate; otherwise it equals `unitPrice`.
  final double effectiveUnitPrice;
  final NumberFormat fmt;
  final VoidCallback onDec;
  final VoidCallback? onInc;
  final VoidCallback onRemove;
  final VoidCallback onPickWarehouse;
  final VoidCallback onRequestPrice;
  final VoidCallback onPickSalesperson;
  // Per-line salesperson override (web POS parity). Null = bill-level
  // salesperson applies.
  final Employee? lineSalesperson;
  // Approved-and-applied standalone price override (from the dedicated
  // "Price Request" menu). Null = catalog price is in effect.
  final double? approvedPrice;
  // Promo savings applied to this line by the engine (0 = no promo).
  // `promoLabel` carries the promo name(s); empty when promoDiscount is 0.
  final double promoDiscount;
  final String promoLabel;
  // Engine output classification — drive the pill + price color.
  // isFreeBonus: line went to 0 because of a BOGO bonus.
  // isPromoSold: trigger sold at the promo price (still > 0).
  final bool isFreeBonus;
  final bool isPromoSold;
  // True when this line was auto-added as a BOGO bonus. Locks the +/-/×
  // controls so the cashier can't desync from the parent trigger.
  final bool isLinkedBonus;
  // Set (ຊຸດ) line — eg. an air-con kit assembled from components. Drives the
  // "ຊຸດ" treatment + the component breakdown row below the line.
  final bool isSet;
  // Component breakdown of the set (from /api/products/{id}/set). Empty until
  // the warehouse picker has fetched it.
  final List<ProductSetDetailItem> setDetails;

  @override
  Widget build(BuildContext context) {
    final hasWarehouse = warehouse != null && location != null;
    final hasDiscount = discountPct > 0 && discountAmount > 0;
    final hasBackorder = hasWarehouse && stock >= 0 && qty > stock;
    final hasPromo = promoLabel.isNotEmpty;
    final discountPctLabel = discountPct == discountPct.toInt()
        ? discountPct.toInt().toString()
        : discountPct.toStringAsFixed(1);
    // Pill colors mirror the web (ແຖມ = emerald, ໂປຣ = indigo, ຂາຍ = muted).
    final Color pillBg;
    final Color pillFg;
    final String pillLabel;
    if (isFreeBonus) {
      pillBg = AppColors.success.withValues(alpha: 0.16);
      pillFg = AppColors.success;
      pillLabel = 'ແຖມ';
    } else if (isPromoSold) {
      pillBg = AppColors.primary.withValues(alpha: 0.14);
      pillFg = AppColors.primary;
      pillLabel = 'ໂປຣ';
    } else {
      pillBg = AppColors.cardElev;
      pillFg = AppColors.textMuted;
      pillLabel = 'ຂາຍ';
    }
    // Price line: free bonus → "ຟຣີ"; promo sold → effective price in
    // indigo (highlighting); normal → effective price in primary color
    // (matches the original look).
    final Widget priceText;
    if (isFreeBonus) {
      priceText = Text(
        'ຟຣີ',
        style: TextStyle(
          color: AppColors.success,
          fontWeight: FontWeight.w900,
          fontSize: 15,
          letterSpacing: -0.2,
          height: 1,
        ),
      );
    } else {
      final showStrike = isPromoSold && effectiveUnitPrice < unitPrice;
      priceText = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (showStrike) ...[
            Text(
              fmt.format(unitPrice * qty),
              style: TextStyle(
                color: AppColors.textSoft,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.lineThrough,
                height: 1,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            fmt.format(lineTotal),
            style: TextStyle(
              color: isPromoSold ? AppColors.primary : AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: -0.2,
              height: 1,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            'ກີບ',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }

    final warehouseTitle = hasWarehouse
        ? (warehouse!.name.trim().isNotEmpty &&
                  warehouse!.name != warehouse!.code
              ? warehouse!.name
              : 'ສາງ')
        : 'ເລືອກສາງ';
    final salespersonTitle = lineSalesperson?.displayName ?? 'ເລືອກຜູ້ຂາຍ';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(kRadiusPill),
                          ),
                          child: Text(
                            pillLabel,
                            style: TextStyle(
                              color: pillFg,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.nameLo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        height: 1.16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 34,
                height: 34,
                child: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isLinkedBonus
                        ? AppColors.textSoft
                        : AppColors.textMuted,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: isLinkedBonus ? null : onRemove,
                  tooltip: isLinkedBonus
                      ? 'ສິນຄ້າແຖມ — ລົບສິນຄ້າຫຼັກເພື່ອລົບແຖມ'
                      : 'ລົບ',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardElev.withValues(
                alpha: ThemeService.isDark ? 0.55 : 0.75,
              ),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFreeBonus
                            ? 'ສິນຄ້າແຖມ'
                            : '${fmt.format(unitPrice)} x $qty',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          priceText,
                          if (hasDiscount && !isFreeBonus) ...[
                            const SizedBox(width: 6),
                            Text(
                              '-$discountPctLabel%',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _MiniStepper(
                  qty: qty,
                  onDec: isLinkedBonus ? null : onDec,
                  onInc: isLinkedBonus ? null : onInc,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _CartMiniActionChip(
                  icon: Icons.warehouse_outlined,
                  label: warehouseTitle,
                  active: hasWarehouse,
                  color: hasWarehouse ? AppColors.gold : AppColors.warning,
                  onTap: onPickWarehouse,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CartMiniActionChip(
                  icon: Icons.badge_outlined,
                  label: salespersonTitle,
                  active: lineSalesperson != null,
                  color: lineSalesperson != null
                      ? AppColors.primary
                      : AppColors.warning,
                  onTap: onPickSalesperson,
                ),
              ),
            ],
          ),
          // Set (ຊຸດ) component breakdown — mirrors the web POS, which lists
          // "ຊຸດ: N ລາຍການ" and the underlying items the cashier is selling.
          if (isSet) ...[
            const SizedBox(height: 6),
            _SetComponentsBox(setDetails: setDetails, setQty: qty, fmt: fmt),
          ],
          const SizedBox(height: 8),
          _CartActionChip(
            icon: approvedPrice != null ? Icons.verified : Icons.discount,
            title: approvedPrice != null ? 'ລາຄາພິເສດ' : 'ຂໍລາຄາພິເສດ',
            value: approvedPrice != null
                ? '${fmt.format(approvedPrice!)} ກີບ'
                : 'ສົ່ງຄຳຂໍໃຫ້ຜູ້ຈັດການ',
            meta: approvedPrice != null ? 'ອະນຸມັດແລ້ວ' : null,
            active: approvedPrice != null,
            color: approvedPrice != null
                ? AppColors.success
                : AppColors.warning,
            onTap: approvedPrice == null ? onRequestPrice : null,
          ),

          // Promo label line — slim inline text in the engine's accent
          // colour (green for free bonus, indigo for promo-sold). Matches
          // the web POS row, which doesn't use a heavy box for this.
          if (hasPromo && !isFreeBonus) ...[
            const SizedBox(height: 3),
            Text(
              promoLabel.isEmpty ? 'Promotion' : promoLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isFreeBonus ? AppColors.success : AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],

          // Optional row 4 — backorder warning when stock is short.
          if (hasBackorder) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 12, color: AppColors.danger),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Backorder · ມີ ${stock == stock.toInt() ? stock.toInt() : stock.toStringAsFixed(2)} · ຂາດ ${qty - stock.toInt() > 0 ? qty - stock.toInt() : (qty - stock).toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Component breakdown shown under a set (ຊຸດ) cart line — the items the
// cashier is actually drawing from stock when selling one set. Mirrors the
// web POS, which lists "ຊຸດ: N ລາຍການ" followed by each component × qty.
class _SetComponentsBox extends StatelessWidget {
  const _SetComponentsBox({
    required this.setDetails,
    required this.setQty,
    required this.fmt,
  });

  final List<ProductSetDetailItem> setDetails;
  // How many whole sets are on the line — component totals scale with this
  // (one set's component qty × setQty), mirroring the web POS.
  final int setQty;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(
          alpha: ThemeService.isDark ? 0.10 : 0.06,
        ),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.widgets_outlined, size: 13, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(
                setDetails.isEmpty
                    ? 'ສິນຄ້າຊຸດ'
                    : 'ສິນຄ້າຊຸດ · ${setDetails.length} ລາຍການ',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          if (setDetails.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'ກຳລັງໂຫຼດລາຍລະອຽດຊຸດ…',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            for (final d in setDetails)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        d.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Builder(
                      builder: (_) {
                        // Total drawn from stock = per-set qty × number of
                        // sets on the line. Scales up as the cashier bumps qty.
                        final total = d.quantity * setQty;
                        final totalLabel = total == total.toInt()
                            ? total.toInt().toString()
                            : total.toString();
                        final unit = (d.unitCode?.trim().isNotEmpty ?? false)
                            ? ' ${d.unitCode!.trim()}'
                            : '';
                        return Text(
                          '× $totalLabel$unit',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _CartActionChip extends StatelessWidget {
  const _CartActionChip({
    required this.icon,
    required this.title,
    required this.value,
    required this.active,
    required this.color,
    this.meta,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? meta;
  final bool active;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? color.withValues(alpha: ThemeService.isDark ? 0.18 : 0.10)
        : AppColors.cardBg;
    final border = active
        ? color.withValues(alpha: 0.42)
        : AppColors.warning.withValues(alpha: 0.42);
    final valueColor = active ? AppColors.textPrimary : AppColors.warning;
    final metaText = meta?.trim();

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(kRadiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    if (metaText != null && metaText.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 3),
                Icon(Icons.edit_outlined, size: 13, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CartMiniActionChip extends StatelessWidget {
  const _CartMiniActionChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.textPrimary : AppColors.warning;
    return Material(
      color: active
          ? color.withValues(alpha: ThemeService.isDark ? 0.16 : 0.08)
          : AppColors.cardBg,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.36)
                  : AppColors.warning.withValues(alpha: 0.36),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.edit_outlined, size: 12, color: color),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, onDec, isLeft: true),
          Container(
            width: 34,
            height: 32,
            alignment: Alignment.center,
            child: Text(
              '$qty',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
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
        left: isLeft ? const Radius.circular(9) : Radius.zero,
        right: isLeft ? Radius.zero : const Radius.circular(9),
      ),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(9) : Radius.zero,
          right: isLeft ? Radius.zero : const Radius.circular(9),
        ),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? AppColors.gold : AppColors.textMuted,
          ),
        ),
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
    final pointsFmt = NumberFormat('#,###', 'en_US');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                Text(
                  'ເລືອກລູກຄ້າ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),
                if (widget.onCreate != null)
                  TextButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text(
                      'ສ້າງໃໝ່',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'ຄົ້ນຫາ ຊື່ / ເບີໂທ / ລະຫັດ',
                prefixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyStateView(
                    icon: hasQuery && !_loading
                        ? Icons.search_off
                        : Icons.person_search_outlined,
                    title: hasQuery && !_loading
                        ? 'ບໍ່ພົບລູກຄ້າ "${_q.trim()}"'
                        : hasQuery
                        ? 'ກຳລັງຄົ້ນຫາ…'
                        : 'ພິມຊື່ ຫຼື ເບີໂທ',
                    subtitle: hasQuery && !_loading
                        ? 'ລອງປ່ຽນຄຳຄົ້ນ ຫຼື ສ້າງລູກຄ້າໃໝ່'
                        : 'ໃຊ້ຊ່ອງຄົ້ນຫາດ້ານເທິງ',
                  )
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _CustomerRow(
                      customer: filtered[i],
                      pointsFmt: pointsFmt,
                      onTap: () => Navigator.pop(context, filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.customer,
    required this.pointsFmt,
    required this.onTap,
  });
  final Customer customer;
  final NumberFormat pointsFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final hasDiscount = c.discountPct > 0;
    final discountLabel = c.discountPct == c.discountPct.toInt()
        ? c.discountPct.toInt().toString()
        : c.discountPct.toStringAsFixed(1);
    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(kRadiusSm),
                ),
                child: Text(
                  c.name.isNotEmpty ? c.name.trim()[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if ((c.phone ?? '').trim().isNotEmpty) c.phone!,
                        '${pointsFmt.format(c.pointBalance)} ແຕ້ມ',
                        if ((c.groupName ?? '').trim().isNotEmpty) c.groupName!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(kRadiusSm),
                  ),
                  child: Text(
                    '−$discountLabel%',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
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
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
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

// Active-promotions list (web POS parity). Lists every promo that's live
// right now with its terms, plus a "ເລືອກ → ກະຕ່າ" action that drops the
// trigger product straight into the cart.
class _PromotionListSheet extends StatelessWidget {
  const _PromotionListSheet({
    required this.promotions,
    required this.nameForCode,
    required this.typeLabel,
    required this.fmt,
  });

  final List<Promotion> promotions;
  final String? Function(String code) nameForCode;
  final String Function(Promotion p) typeLabel;
  final NumberFormat fmt;

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(
              children: [
                Icon(Icons.local_offer_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ໂປຣໂມຊັ່ນທີ່ໃຊ້ໄດ້ (${promotions.length})',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: promotions.isEmpty
                ? EmptyStateView(
                    icon: Icons.local_offer_outlined,
                    title: 'ບໍ່ມີໂປຣໂມຊັ່ນ active ໃນຕອນນີ້',
                    subtitle: 'ໂປຣໂມຊັ່ນຈະປາກົດທີ່ນີ້ເມື່ອຮອດເວລາໃຊ້',
                  )
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: promotions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _PromotionCard(
                      promo: promotions[i],
                      nameForCode: nameForCode,
                      typeLabel: typeLabel,
                      fmtDate: _fmtDate,
                      fmt: fmt,
                      onPick: () => Navigator.of(context).pop(promotions[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({
    required this.promo,
    required this.nameForCode,
    required this.typeLabel,
    required this.fmtDate,
    required this.fmt,
    required this.onPick,
  });

  final Promotion promo;
  final String? Function(String code) nameForCode;
  final String Function(Promotion p) typeLabel;
  final String Function(DateTime? d) fmtDate;
  final NumberFormat fmt;
  final VoidCallback onPick;

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(kRadiusPill),
    ),
    child: Text(
      text,
      style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w900),
    ),
  );

  Widget _itemRow({
    required String pillText,
    required Color pillBg,
    required Color pillFg,
    required String code,
    required int qty,
    required String priceText,
  }) {
    final name = nameForCode(code) ?? code;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _pill(pillText, pillBg, pillFg),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$code${qty > 0 ? '  ×$qty' : ''}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            priceText,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _terms() {
    final tq = (promo.triggerQty ?? 0).toInt();
    final bq = (promo.bonusQty ?? 0).toInt();
    final bp = promo.bonusPriceKip ?? 0;
    final fp = promo.fixedPriceKip ?? 0;
    final tCode = promo.triggerItemCode?.trim() ?? '';
    final bCode = promo.bonusItemCode?.trim() ?? '';
    final rows = <Widget>[];
    switch (promo.promoType.toLowerCase()) {
      case 'fixed_price_period':
        if (tCode.isNotEmpty) {
          rows.add(
            _itemRow(
              pillText: 'ສິນຄ້າຫຼັກ',
              pillBg: AppColors.primary.withValues(alpha: 0.14),
              pillFg: AppColors.primary,
              code: tCode,
              qty: 0,
              priceText: '${fmt.format(fp)} ກີບ/ໜ່ວຍ',
            ),
          );
        }
        break;
      case 'item_pair_price':
        if (tCode.isNotEmpty) {
          rows.add(
            _itemRow(
              pillText: 'ສິນຄ້າຫຼັກ',
              pillBg: AppColors.primary.withValues(alpha: 0.14),
              pillFg: AppColors.primary,
              code: tCode,
              qty: tq,
              priceText: 'ລາຄາປົກກະຕິ',
            ),
          );
        }
        if (bCode.isNotEmpty) {
          rows.add(
            _itemRow(
              pillText: 'ສິນຄ້າແຖມ',
              pillBg: AppColors.gold.withValues(alpha: 0.16),
              pillFg: AppColors.gold,
              code: bCode,
              qty: bq,
              priceText: '${fmt.format(bp)} ກີບ/ໜ່ວຍ',
            ),
          );
        }
        break;
      case 'bogo':
        if (tCode.isNotEmpty) {
          rows.add(
            _itemRow(
              pillText: 'ຊື້ $tq',
              pillBg: AppColors.primary.withValues(alpha: 0.14),
              pillFg: AppColors.primary,
              code: tCode,
              qty: tq,
              priceText: bp > 0 ? '${fmt.format(bp)} ກີບ/ໜ່ວຍ' : 'ລາຄາປົກກະຕິ',
            ),
          );
        }
        if (bCode.isNotEmpty) {
          rows.add(
            _itemRow(
              pillText: 'ແຖມ $bq',
              pillBg: AppColors.success.withValues(alpha: 0.16),
              pillFg: AppColors.success,
              code: bCode,
              qty: bq,
              priceText: 'ຟຣີ',
            ),
          );
        }
        break;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final start = promo.startAt;
    final end = promo.endAt;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      promo.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeLabel(promo),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(kRadiusMd),
                child: InkWell(
                  onTap: onPick,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ເລືອກ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.add_shopping_cart,
                          size: 15,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          ..._terms(),
          if (start != null || end != null) ...[
            const SizedBox(height: 8),
            Text(
              '${fmtDate(start)}  →  ${fmtDate(end)}',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if ((promo.timeFrom?.trim().isNotEmpty ?? false) ||
              (promo.timeTo?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${promo.timeFrom ?? '--:--'} – ${promo.timeTo ?? '--:--'}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
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
                                  // Prefer the descriptive name — fall back
                                  // to "ສາງ <code>" only when no name came
                                  // back from the API (e.g. unknown warehouse).
                                  Text(
                                    opt.warehouse.name.trim().isNotEmpty &&
                                            opt.warehouse.name !=
                                                opt.warehouse.code
                                        ? opt.warehouse.name
                                        : 'ສາງ ${opt.warehouse.code}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (opt.warehouse.name.trim().isNotEmpty &&
                                      opt.warehouse.name != opt.warehouse.code)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'ສາງ ${opt.warehouse.code}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
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
                                  opt.stock <= 0 ? '0' : stockText,
                                  style: TextStyle(
                                    color: opt.stock <= 0
                                        ? AppColors.warning
                                        : AppColors.success,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  opt.stock <= 0 ? 'Backorder' : 'ໃນສາງ',
                                  style: TextStyle(
                                    color: opt.stock <= 0
                                        ? AppColors.warning
                                        : AppColors.textMuted,
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

// ── Product row (main list) ─────────────────────────────────────────────
// Two-row layout: item name across the top (single line, truncated),
// item code on the bottom-left with price on the bottom-right. A thin
// indigo accent bar appears on the left edge — and a small qty pill on
// the name row — once the product is in the cart. No generic leading
// icon: it added visual weight without information.
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.item,
    required this.qty,
    required this.stock,
    required this.companyBalance,
    required this.unitPrice,
    required this.fmt,
    this.promoName,
    required this.onTap,
  });

  final InventoryItem item;
  final int qty;
  final double stock;
  final double companyBalance;
  final double unitPrice;
  final NumberFormat fmt;
  final String? promoName;
  final VoidCallback onTap;

  Color _statusColor(InventoryItem item) {
    if (companyBalance <= 0) {
      return AppColors.danger;
    } else if (companyBalance <= item.salesMinimumStock) {
      return AppColors.warning;
    } else {
      return AppColors.success;
    }
  }

  String _statusLabel(InventoryItem item) {
    if (companyBalance <= 0) {
      return 'ໝົດ';
    } else if (companyBalance <= item.salesMinimumStock) {
      return 'ໃກ້ໝົດ';
    } else {
      return 'ມີສິນຄ້າ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final inCart = qty > 0;
    final statusColor = _statusColor(item);
    final statusLabel = _statusLabel(item);
    final unit = item.unitName ?? 'ອັນ';
    final isDark = ThemeService.isDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadiusLg),
          border: Border.all(
            color: inCart ? AppColors.primary : AppColors.border.withValues(alpha: isDark ? 0.35 : 0.6),
            width: inCart ? 1.6 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: inCart
                  ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.18)
                  : (isDark ? const Color(0x10000000) : const Color(0x04000000)),
              blurRadius: inCart ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SurfaceCard(
          onTap: onTap,
          padding: const EdgeInsets.all(kSpace4),
          accent: statusColor,
          radius: kRadiusLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBubble(
                    icon: Icons.widgets_outlined,
                    color: statusColor,
                    size: BubbleSize.md,
                  ),
                  const SizedBox(width: kSpace3),
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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 5),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text(
                                item.code,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (item.brandName != null && item.brandName!.isNotEmpty) ...[
                                Text('  ·  ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                Text(
                                  item.brandName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: kSpace2),
                  // Quantity in cart pill + Status Badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (inCart) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(kRadiusPill),
                          ),
                          child: Text(
                            '×$qty',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: kSpace1 + 2),
                      ],
                      StatusBadge(
                        label: statusLabel,
                        color: statusColor,
                        size: StatusBadgeSize.small,
                      ),
                    ],
                  ),
                ],
              ),
              
              if (promoName != null && promoName!.isNotEmpty) ...[
                const SizedBox(height: kSpace2 + 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(kRadiusSm),
                    border: Border.all(
                      color: AppColors.brandOrange.withValues(alpha: 0.22),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: AppColors.brandOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ໂປຣ: $promoName',
                        style: const TextStyle(
                          color: AppColors.brandOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: kSpace4),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.16) : AppColors.bg.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: isDark ? 0.25 : 0.45),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ຈຳນວນໃນສະຕັອກ',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fmt.format(companyBalance)} $unit',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: kTabularFigures,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppColors.border.withValues(alpha: isDark ? 0.35 : 0.7),
                    ),
                    const SizedBox(width: kSpace3),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.sell_outlined,
                            size: 15,
                            color: unitPrice > 0 ? AppColors.primary : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ລາຄາຂາຍ',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                unitPrice > 0
                                    ? '${fmt.format(unitPrice)} ກີບ'
                                    : 'ຍັງບໍ່ມີລາຄາ',
                                style: TextStyle(
                                  color: unitPrice > 0 ? AppColors.primary : AppColors.textMuted,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: kTabularFigures,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

