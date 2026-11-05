class FactoryInfo {
  const FactoryInfo({
    required this.name,
    required this.address,
    required this.contactName,
    required this.phone,
    required this.loadingHours,
    required this.instructions,
  });

  final String name;
  final String address;
  final String contactName;
  final String phone;
  final String loadingHours;
  final String instructions;
}

abstract interface class FactoryRepository {
  Future<FactoryInfo> assignedFactory();
}
