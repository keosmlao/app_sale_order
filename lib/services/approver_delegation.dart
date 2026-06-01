// In-memory mock of the price-approval delegation list. Managers tag a
// few "ຫົວໜ້າໜ່ວຍງານ" employees as approvers from the home dashboard,
// and the cart-side price-request flow can ask whether the logged-in
// user is in the set.
//
// Replace with a real /api/approvers backend when ready — keep the same
// surface (isDelegated / setDelegated / all) so call sites don't change.

class ApproverDelegationService {
  static final Set<String> _codes = <String>{};

  static bool isDelegated(String? employeeCode) {
    if (employeeCode == null || employeeCode.isEmpty) return false;
    return _codes.contains(employeeCode);
  }

  static void setDelegated(String employeeCode, bool value) {
    if (value) {
      _codes.add(employeeCode);
    } else {
      _codes.remove(employeeCode);
    }
  }

  static int get count => _codes.length;
  static List<String> get all => List.unmodifiable(_codes);
}
