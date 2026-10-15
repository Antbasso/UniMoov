enum ApiHealth { ok, degraded }

/// Interprète la réponse de `GET /health` (200 ou 503 avec `{ status, db }`).
ApiHealth parseHealth(Object? body) {
  if (body is Map<String, dynamic> && body['status'] == 'ok') return ApiHealth.ok;
  if (body is Map<String, dynamic> && body['status'] == 'degraded') return ApiHealth.degraded;
  throw const FormatException('Réponse /health inattendue');
}
