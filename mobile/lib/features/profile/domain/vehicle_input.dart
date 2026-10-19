/// Lecture des champs du véhicule (virgule ou point décimal), bornes de l'API.
abstract final class VehicleInput {
  static const consumptionMin = 2.0;
  static const consumptionMax = 20.0;
  static const seatsMin = 1;
  static const seatsMax = 8;
  static const detourMin = 0;
  static const detourMax = 60;

  static double? consumption(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null || value < consumptionMin || value > consumptionMax) return null;
    return (value * 10).round() / 10;
  }

  static int? seats(String text) => _intInRange(text, seatsMin, seatsMax);
  static int? detour(String text) => _intInRange(text, detourMin, detourMax);

  static int? _intInRange(String text, int min, int max) {
    final value = int.tryParse(text.trim());
    return value == null || value < min || value > max ? null : value;
  }

  static const modelMax = 40;
  static const colorMax = 30;

  /// Modèle ou couleur : texte non vide, borné (comme le serveur).
  static String? label(String text, int max) {
    final value = text.trim();
    return value.isEmpty || value.length > max ? null : value;
  }

  /// Affichage français : « 5,8 ».
  static String formatConsumption(double value) => value.toStringAsFixed(1).replaceAll('.', ',');
}
