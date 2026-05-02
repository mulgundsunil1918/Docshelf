import '../models/category.dart';

// ─── Helpers ─────────────────────────────────────────────────────────
Category _root(String id, String name, String emoji, List<Category> kids) {
  return Category(
    id: id,
    name: name,
    emoji: emoji,
    depth: 0,
    children: kids
        .map((c) => c.copyWith(parentId: id, depth: 1))
        .toList(growable: false),
  );
}

Category _sub(String id, String name, String emoji) {
  return Category(id: id, name: name, emoji: emoji);
}

// ─── 11 default roots + their subcategories ──────────────────────────
/// The starter category tree shipped with DocShelf.
///
/// All ids are stable strings (`cat_<root>` or `cat_<root>_<sub>`) so they
/// can survive schema migrations without renames. Add custom subcategories
/// at runtime via `CategoryService` — they get `custom_<timestamp>` ids.
final List<Category> kDefaultCategories = [
  _root('cat_identity', 'Identity', '🪪', [
    _sub('cat_identity_aadhaar', 'Aadhaar', '🆔'),
    _sub('cat_identity_pan', 'PAN', '🪪'),
    _sub('cat_identity_passport', 'Passport', '📘'),
    _sub('cat_identity_voter', 'Voter ID', '🗳️'),
    _sub('cat_identity_dl', 'Driving License', '🚙'),
  ]),
  _root('cat_finance', 'Finance', '💰', [
    _sub('cat_finance_bank', 'Bank Statements', '🏦'),
    _sub('cat_finance_itr', 'ITR & Tax', '🧾'),
    _sub('cat_finance_mf', 'Mutual Funds', '📈'),
    _sub('cat_finance_loans', 'Loans', '💳'),
    _sub('cat_finance_demat', 'Demat & Stocks', '📊'),
  ]),
  _root('cat_health', 'Health', '🏥', [
    _sub('cat_health_rx', 'Prescriptions', '💊'),
    _sub('cat_health_lab', 'Lab Reports', '🧪'),
    _sub('cat_health_bills', 'Hospital Bills', '🏥'),
    _sub('cat_health_insurance', 'Health Insurance', '🛡️'),
  ]),
  _root('cat_property', 'Property', '🏠', [
    _sub('cat_property_sale', 'Sale Deed', '🏘️'),
    _sub('cat_property_rent', 'Rent Agreement', '🏠'),
    _sub('cat_property_tax', 'Property Tax', '🧾'),
    _sub('cat_property_will', 'Will & Nominations', '📜'),
  ]),
  _root('cat_vehicle', 'Vehicle', '🚗', [
    _sub('cat_vehicle_rc', 'RC Book', '🚗'),
    _sub('cat_vehicle_insurance', 'Insurance', '🛡️'),
    _sub('cat_vehicle_puc', 'PUC', '🌿'),
    _sub('cat_vehicle_license', 'Driving License', '🪪'),
  ]),
  _root('cat_education', 'Education', '🎓', [
    _sub('cat_education_marks', 'Marksheets', '📑'),
    _sub('cat_education_certs', 'Certificates', '🏆'),
    _sub('cat_education_degrees', 'Degrees', '🎓'),
  ]),
  _root('cat_work', 'Work', '💼', [
    _sub('cat_work_offer', 'Offer Letters', '📨'),
    _sub('cat_work_payslips', 'Payslips', '💵'),
    _sub('cat_work_contracts', 'Contracts', '📝'),
    _sub('cat_work_resume', 'Resume & CV', '📄'),
  ]),
  _root('cat_bills', 'Bills', '🧾', [
    _sub('cat_bills_electricity', 'Electricity', '⚡'),
    _sub('cat_bills_water', 'Water', '💧'),
    _sub('cat_bills_internet', 'Internet', '🌐'),
    _sub('cat_bills_mobile', 'Mobile', '📱'),
  ]),
  _root('cat_travel', 'Travel', '✈️', [
    _sub('cat_travel_tickets', 'Tickets', '🎟️'),
    _sub('cat_travel_visas', 'Visas', '🛂'),
    _sub('cat_travel_bookings', 'Bookings', '🏨'),
  ]),
  _root('cat_family', 'Family', '👨‍👩‍👧', [
    _sub('cat_family_birth', 'Birth Certificates', '👶'),
    _sub('cat_family_marriage', 'Marriage Certificate', '💍'),
    _sub('cat_family_photos', 'Family Photos', '📸'),
  ]),
  _root('cat_other', 'Other / Unsorted', '📦', const []),
];

/// Flatten the default tree into a single list (root + child entries) so
/// services can index by id without recursing every lookup.
List<Category> flattenDefaults() {
  final out = <Category>[];
  for (final root in kDefaultCategories) {
    out.add(root);
    out.addAll(root.children);
  }
  return out;
}
