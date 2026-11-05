import '../../../core/constants/app_constants.dart';
import '../domain/factory_info.dart';

/// Placeholder details: replace with the real factory, or load them from the server.
class FakeFactoryRepository implements FactoryRepository {
  @override
  Future<FactoryInfo> assignedFactory() async => const FactoryInfo(
    name: 'ICECLUB Factory (sample)',
    address: 'Sample Industrial Estate, Andheri East, Mumbai 400069',
    contactName: 'Loading Supervisor',
    phone: AppConstants.supportPhone,
    loadingHours: '5 AM - 8 PM',
    instructions: 'Check the bag count and seal before loading. Keep ice covered during transport.',
  );
}
