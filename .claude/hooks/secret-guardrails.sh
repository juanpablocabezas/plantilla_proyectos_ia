#!/usr/bin/env bash
# secret-guardrails.sh — hook PreToolUse (OPT-IN) para Write|Edit que bloquea
# escrituras del agente sobre archivos de secretos: el `.env` real y llaves
# privadas. Convierte la regla "nunca le des secretos a un agente" de
# docs/conventions/ai-agents.md en una garantía dura. No está activo por
# defecto; se habilita desde settings.json / settings.local.json.
#
# Contrato del hook: lee el JSON del evento por stdin y devuelve exit 2 para
# BLOQUEAR la herramienta — el motivo (stderr) se le muestra al agente. Exit 0
# permite.
#
# Política de fallo, en dos niveles:
#   - Ambigüedad (el evento no trae ruta): falla ABIERTO, no hay nada que juzgar.
#   - Entorno roto (falta perl): falla CERRADO. Un guardrail que se desactiva en
#     silencio es peor que uno ausente: creerías estar protegido sin estarlo.
#
# Dependencia: perl con JSON::PP (módulo core). Viene incluido en Git for
# Windows, macOS y las distribuciones Linux habituales.
set -euo pipefail

payload="$(cat)"

# Comprobamos que perl existe Y que su módulo carga: un binario presente pero
# inservible (p. ej. un stub de PATH) debe tratarse como ausente, no como válido.
if ! perl -MJSON::PP -e "" >/dev/null 2>&1; then
  echo "⛔ secret-guardrails: falta perl con JSON::PP, así que no puedo comprobar la ruta." >&2
  echo "   Bloqueo por precaución. Instala perl o desactiva este hook en" >&2
  echo "   .claude/settings.json (docs/conventions/ai-agents.md)." >&2
  exit 2
fi

path="$(printf '%s' "$payload" | perl -MJSON::PP -e '
use strict; use warnings;
my $raw  = do { local $/; <STDIN> };
my $data = eval { decode_json($raw) } || {};
print eval { $data->{tool_input}{file_path} } // "";
' 2>/dev/null || true)"
[ -z "$path" ] && exit 0

base="$(basename "$path")"
block() { echo "⛔ secret-guardrails: $1" >&2; exit 2; }

case "$base" in
  # Las plantillas de configuración sí se editan: son el contrato, sin valores reales.
  .env.example|.env.sample|.env.template) exit 0 ;;
  # El .env real (y variantes como .env.local, .env.production) no se toca.
  .env|.env.*)
    block "No escribas en '$base': los valores reales de entorno no se tocan ni se leen. Edita .env.example en su lugar (docs/conventions/secrets.md)." ;;
  # Llaves privadas y certificados.
  *.pem|*.key|id_rsa|id_rsa.*|id_ed25519|id_ed25519.*|id_ecdsa|id_ecdsa.*)
    block "No escribas en '$base': parece una llave privada o certificado (SECURITY.md)." ;;
esac

exit 0
