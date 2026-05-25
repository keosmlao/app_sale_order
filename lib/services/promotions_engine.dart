import 'dart:math' as math;
import '../models/models.dart';

class EngineLine {
  final String productId;
  final int quantity;
  final double price;             // unit price KIP (original)
  final double gross;             // price * quantity
  final double customerDiscount;   // customer discount amount (standing discount/special price)
  double promoDiscount;           // promotional discount amount (accumulated)
  String promoLabel;              // promotional label (accumulated)
  double amount;                  // net amount: gross - customerDiscount - promoDiscount

  EngineLine({
    required this.productId,
    required this.quantity,
    required this.price,
    required this.customerDiscount,
    this.promoDiscount = 0.0,
    this.promoLabel = '',
    double? amount,
  })  : gross = price * quantity,
        amount = amount ?? (price * quantity - customerDiscount);
}

int? timeToMinutes(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return null;
  final parts = timeStr.split(':');
  if (parts.length < 2) return null;
  final hours = int.tryParse(parts[0]) ?? 0;
  final minutes = int.tryParse(parts[1]) ?? 0;
  return hours * 60 + minutes;
}

bool isPromoActiveNow(Promotion p, DateTime now) {
  if (!p.isActive) return false;
  if (p.startAt != null && p.startAt!.isAfter(now)) return false;
  if (p.endAt != null && p.endAt!.isBefore(now)) return false;
  
  final fromMin = timeToMinutes(p.timeFrom);
  final toMin = timeToMinutes(p.timeTo);
  if (fromMin != null && toMin != null) {
    final nowMin = now.hour * 60 + now.minute;
    if (fromMin <= toMin) {
      if (nowMin < fromMin || nowMin > toMin) return false;
    } else {
      if (nowMin < fromMin && nowMin > toMin) return false;
    }
  }
  return true;
}

void _pushLabel(EngineLine line, String label) {
  line.promoLabel = line.promoLabel.isNotEmpty
      ? '${line.promoLabel} + $label'
      : label;
}

List<EngineLine> applyPromotions(
  List<EngineLine> lines,
  List<Promotion> promotions,
  DateTime now,
) {
  final active = promotions.where((p) => isPromoActiveNow(p, now)).toList();
  final byCode = <String, List<EngineLine>>{};
  for (final line in lines) {
    byCode.putIfAbsent(line.productId, () => []).add(line);
  }

  // 1. Fixed price for a period (unconditional — only the time window gates it).
  for (final p in active) {
    if (p.promoType != 'fixed_price_period') continue;
    final code = p.triggerItemCode?.trim();
    final fixed = p.fixedPriceKip ?? 0.0;
    if (code == null || code.isEmpty || fixed < 0) continue;
    final matches = byCode[code] ?? [];
    for (final line in matches) {
      if (line.price <= fixed) continue;
      final savingsPerUnit = line.price - fixed;
      line.promoDiscount += savingsPerUnit * line.quantity;
      _pushLabel(line, p.name);
    }
  }

  // 2. Item pair: bonus is priced at a fixed value when trigger is in cart.
  for (final p in active) {
    if (p.promoType != 'item_pair_price') continue;
    final triggerCode = p.triggerItemCode?.trim();
    final bonusCode = p.bonusItemCode?.trim();
    final bonusPrice = p.bonusPriceKip ?? 0.0;
    if (triggerCode == null || triggerCode.isEmpty || bonusCode == null || bonusCode.isEmpty) continue;
    final triggerLines = byCode[triggerCode] ?? [];
    final bonusLines = byCode[bonusCode] ?? [];
    if (triggerLines.isEmpty || bonusLines.isEmpty) continue;
    final triggerQty = triggerLines.fold<int>(0, (s, l) => s + l.quantity);
    if (triggerQty <= 0) continue;
    
    int remaining = triggerQty;
    for (final bonus in bonusLines) {
      if (remaining <= 0) break;
      final eligible = math.min(remaining, bonus.quantity);
      if (eligible <= 0 || bonus.price <= bonusPrice) continue;
      final savingsPerUnit = bonus.price - bonusPrice;
      bonus.promoDiscount += savingsPerUnit * eligible;
      _pushLabel(bonus, p.name);
      remaining -= eligible;
    }
  }

  // 3. BOGO: every `triggerQty` units of trigger is priced at the configured
  //    main-item price, and `bonusQty` units of bonus are free.
  for (final p in active) {
    if (p.promoType != 'bogo') continue;
    final triggerCode = p.triggerItemCode?.trim();
    final bonusCode = p.bonusItemCode?.trim();
    final triggerQty = (p.triggerQty ?? 0.0).toInt();
    final bonusQty = (p.bonusQty ?? 0.0).toInt();
    final triggerPromoPrice = p.bonusPriceKip ?? 0.0;
    
    if (triggerCode == null ||
        triggerCode.isEmpty ||
        bonusCode == null ||
        bonusCode.isEmpty ||
        triggerQty <= 0 ||
        bonusQty <= 0 ||
        triggerPromoPrice <= 0) {
      continue;
    }
    final triggerLines = byCode[triggerCode] ?? [];
    final bonusLines = byCode[bonusCode] ?? [];
    if (triggerLines.isEmpty || bonusLines.isEmpty) continue;
    final cartTriggerQty = triggerLines.fold<int>(0, (s, l) => s + l.quantity);
    final sets = cartTriggerQty ~/ triggerQty;
    if (sets <= 0) continue;

    int triggerBudget = sets * triggerQty;
    for (final trigger in triggerLines) {
      if (triggerBudget <= 0) break;
      final promoOnThisLine = math.min(triggerBudget, trigger.quantity);
      if (trigger.price > triggerPromoPrice) {
        trigger.promoDiscount += promoOnThisLine * (trigger.price - triggerPromoPrice);
        _pushLabel(trigger, p.name);
      }
      triggerBudget -= promoOnThisLine;
    }

    int freeBudget = sets * bonusQty;
    for (final bonus in bonusLines) {
      if (freeBudget <= 0) break;
      final freeOnThisLine = math.min(freeBudget, bonus.quantity);
      bonus.promoDiscount += freeOnThisLine * bonus.price;
      _pushLabel(bonus, p.name);
      freeBudget -= freeOnThisLine;
    }
  }

  // Recompute the net per line, never below zero.
  for (final line in lines) {
    line.amount = math.max(
      0.0,
      line.gross - line.customerDiscount - line.promoDiscount,
    );
  }
  return lines;
}
