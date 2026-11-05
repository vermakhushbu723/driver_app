class Rider {
  const Rider({
    required this.id,
    required this.phone,
    required this.name,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.licenceNumber,
    required this.zone,
    required this.joinedOn,
    this.onDuty = true,
  });

  final String id;
  final String phone;
  final String name;
  final String vehicleType;
  final String vehicleNumber;
  final String licenceNumber;
  final String zone;
  final DateTime joinedOn;
  final bool onDuty;

  Rider copyWith({bool? onDuty}) => Rider(
    id: id,
    phone: phone,
    name: name,
    vehicleType: vehicleType,
    vehicleNumber: vehicleNumber,
    licenceNumber: licenceNumber,
    zone: zone,
    joinedOn: joinedOn,
    onDuty: onDuty ?? this.onDuty,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'vehicleType': vehicleType,
    'vehicleNumber': vehicleNumber,
    'licenceNumber': licenceNumber,
    'zone': zone,
    'joinedOn': joinedOn.toIso8601String(),
    'onDuty': onDuty,
  };

  factory Rider.fromJson(Map<String, dynamic> j) => Rider(
    id: j['id'] as String,
    phone: j['phone'] as String,
    name: j['name'] as String,
    vehicleType: j['vehicleType'] as String,
    vehicleNumber: j['vehicleNumber'] as String,
    licenceNumber: j['licenceNumber'] as String,
    zone: j['zone'] as String,
    joinedOn: DateTime.parse(j['joinedOn'] as String),
    onDuty: j['onDuty'] as bool,
  );
}

/// Riders are added by the admin, so there is no self-registration.
abstract interface class AuthRepository {
  Future<Rider?> currentRider();

  Future<void> sendOtp(String phone);

  Future<Rider> verifyOtp(String phone, String otp);

  Future<Rider> signInWithPassword(String phone, String password);

  Future<void> changePassword({required String current, required String next});

  Future<Rider> setOnDuty(bool onDuty);

  Future<void> logout();
}
