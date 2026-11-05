abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/otp';

  static const home = '/';
  static const orders = '/orders';
  static const pickup = '/pickup';
  static const collection = '/collection';
  static const menu = '/menu';

  static const factoryDetails = '/factory-details';
  static const pickupQuantity = '/pickup-quantity';
  static const loadingConfirmation = '/loading-confirmation';
  static const pickupPhotos = '/pickup-photos';

  static const duty = '/duty';
  static const liveGps = '/live-gps';
  static const routeTracking = '/route-tracking';

  static const cashCollection = '/cash-collection';
  static const upiCollection = '/upi-collection';
  static const paymentHistory = '/payment-history';
  static const cashHandover = '/cash-handover';

  static const returnPhotos = '/return-photos';

  static const deliveryHistory = '/delivery-history';
  static const collectionHistory = '/collection-history';

  static const attendance = '/attendance';
  static const salary = '/salary';
  static const incentives = '/incentives';

  static const notifications = '/notifications';
  static const notificationSettings = '/notification-settings';
  static const support = '/support';
  static const tickets = '/tickets';
  static const newTicket = '/new-ticket';
  static const profile = '/profile';
  static const vehicle = '/vehicle';
  static const documents = '/documents';
  static const changePassword = '/change-password';

  static String order(String id) => '$orders/$id';
  static String orderList(String filter) => '/order-list/$filter';
  static String deliverySection(String section) => '/delivery/$section';
  static String returns(String type) => '/returns/$type';
  static String newReturn(String type) => '/new-return/$type';
  static String ticket(String id) => '$tickets/$id';
  static String loading(String id) => '/loading/$id';
  static String completeDelivery(String id) => '/complete-delivery/$id';
  static String failDelivery(String id) => '/fail-delivery/$id';
}
