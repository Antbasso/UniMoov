/// Portefeuille prépayé (cahier §5) : montants en centimes entiers.
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
