/// Portefeuille prépayé (cahier §5) : montants en centimes entiers.
/// Demande de retrait vers un compte bancaire (SEPA).
class PayoutRequest {
  const PayoutRequest({required this.amountCents, required this.iban, required this.holderName});

  final int amountCents;
  final String iban;
  final String holderName;
}

/// Montant saisi en euros (« 12 », « 12,5 », « 12.50 ») en centimes entiers, sans passer par
/// un flottant ; `null` si la saisie n'est pas un montant positif à deux décimales au plus.
int? parseEurosToCents(String input) {
  final match = RegExp(r'^(\d{1,6})(?:[.,](\d{1,2}))?$')
      .firstMatch(input.replaceAll(' ', '').trim());
  if (match == null) return null;
  final cents = int.parse(match[1]!) * 100 + int.parse((match[2] ?? '0').padRight(2, '0'));
  return cents > 0 ? cents : null;
}

class Wallet {
  const Wallet({required this.balanceCents, required this.heldCents, required this.history});

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    balanceCents: json['balanceCents'] as int,
    heldCents: json['heldCents'] as int,
    history: [
      for (final e in json['history'] as List<dynamic>)
        WalletEntry.fromJson(e as Map<String, dynamic>),
    ],
  );

  final int balanceCents;

  /// Retenu pour un trajet en cours, libéré au paiement ou à la clôture.
  final int heldCents;
  final List<WalletEntry> history;
}

class WalletEntry {
  const WalletEntry({required this.kind, required this.amountCents, required this.at});

  factory WalletEntry.fromJson(Map<String, dynamic> json) => WalletEntry(
    kind: json['kind'] as String,
    amountCents: json['amountCents'] as int,
    at: DateTime.parse(json['createdAt'] as String),
  );

  /// topup, ride_charge, ride_credit, payout, refund.
  final String kind;
  final int amountCents;
  final DateTime at;
}
