import 'dart:math';

class Utils {
  static String generateProductCode() {
    final random = Random();
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }
}
