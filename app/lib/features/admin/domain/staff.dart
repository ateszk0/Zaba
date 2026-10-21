/// What a staff member may do: an `operator` handles orders, an `admin` also
/// reads the audit log. (The database enforces this; the app only decides what
/// to show.)
enum StaffRole {
  admin,
  operator;

  static StaffRole? fromCode(Object? code) => switch (code) {
    'admin' => StaffRole.admin,
    'operator' => StaffRole.operator,
    _ => null,
  };
}
