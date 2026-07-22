#!/usr/bin/env bash
# check-placeholders.sh — verifica los placeholders `[ASÍ]` de la plantilla.
#
# Dos modos, autodetectados:
#   - Modo PLANTILLA (existe TEMPLATE-USAGE.md): todo placeholder usado en el
#     repo debe estar documentado en el catálogo de TEMPLATE-USAGE.md (§3),
#     de forma literal o cubierto por un comodín como `[COMANDO_*]`.
#   - Modo INSTANCIA (TEMPLATE-USAGE.md ya fue borrado): no debe quedar ningún
#     placeholder sin rellenar, salvo en los esqueletos intencionales.
#
# Uso:
#   bash .github/scripts/check-placeholders.sh [raíz-del-repo]
#
# Requiere: git, perl. Sale con 1 si encuentra problemas.
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

CATALOG="TEMPLATE-USAGE.md"

# Rutas que se saltan en ambos modos:
#   - esqueletos que conservan placeholders a propósito (plantillas de docs);
#   - las plantillas de issues (sus corchetes son prefijos de título como "[BUG] …");
#   - .github/scripts/ (el tooling: menciona placeholders como texto de ejemplo);
#   - .claude/ (instrucciones para agentes, no documentación del proyecto).
# Todo lo demás versionado se escanea, incluidos LICENSE, workflows y FUNDING.yml —
# un placeholder olvidado en un archivo no-markdown es tan real como en un .md.
SKIP='^(\.github/ISSUE_TEMPLATE/.*\.md$|\.github/scripts/|\.claude/|docs/conventions/_template\.md|docs/decisions/0000-template\.md|specs/_template/)'

# Menciones "meta" sobre el propio sistema de placeholders (no son placeholders
# que haya que rellenar; aparecen en instrucciones de la plantilla).
META='^(PLACEHOLDER|PLACEHOLDERS|CORCHETES_EN_MAYÚSCULAS)$'

# Extrae placeholders [MAYÚSCULAS] de un archivo, ignorando los enlaces
# markdown `[TEXTO](destino)` gracias al lookahead negativo. El -Mutf8 es
# imprescindible: sin él, la clase del patrón ([Á-Ñ…]) se interpreta como bytes
# sueltos mientras -CSD decodifica la entrada como caracteres, y los
# placeholders acentuados como [AÑO] pasan sin detectarse.
extract() {
  perl -CSD -Mutf8 -ne 'while (/\[([A-ZÁÉÍÓÚÑ0-9_\/]{2,})\](?!\()/g) { print "$ARGV:$.: [$1]\n" }' "$1"
}

files() {
  git ls-files | grep -Ev "$SKIP" | while IFS= read -r f; do
    # Solo archivos de texto: los binarios no llevan placeholders.
    grep -Iq . "$f" 2>/dev/null && printf '%s\n' "$f" || true
  done
}

if [ -f "$CATALOG" ]; then
  # ── Modo PLANTILLA: consistencia del catálogo ──────────────────────────────
  # Prefijos comodín documentados en el catálogo, p. ej. `[COMANDO_*]` → COMANDO_.
  wildcards="$(perl -CSD -Mutf8 -ne 'while (/\[([A-ZÁÉÍÓÚÑ0-9_\/]+_)\*\]/g) { print "$1\n" }' "$CATALOG" | sort -u)"

  missing=0
  placeholders="$(
    files | grep -v "^$CATALOG$" | while IFS= read -r f; do extract "$f"; done \
      | sed -E 's/^.*\[([^]]+)\]$/\1/' | sort -u
  )"

  while IFS= read -r p; do
    [ -z "$p" ] && continue
    printf '%s' "$p" | grep -Eq "$META" && continue
    grep -qF "[$p]" "$CATALOG" && continue
    covered=0
    while IFS= read -r w; do
      [ -n "$w" ] && case "$p" in "$w"*) covered=1 ;; esac
    done <<<"$wildcards"
    [ "$covered" -eq 1 ] && continue
    echo "❌ [$p] se usa en el repo pero no está en el catálogo de $CATALOG (§3)."
    missing=1
  done <<<"$placeholders"

  if [ "$missing" -ne 0 ]; then
    echo "→ Añade los placeholders faltantes al catálogo de $CATALOG."
    exit 1
  fi
  echo "✅ Placeholders: todos los usados están documentados en el catálogo."
else
  # ── Modo INSTANCIA: no deben quedar placeholders sin rellenar ──────────────
  leftovers="$(files | while IFS= read -r f; do extract "$f"; done || true)"
  # También aquí las menciones meta no cuentan como pendientes.
  leftovers="$(printf '%s' "$leftovers" | grep -Ev '\[(PLACEHOLDER|PLACEHOLDERS|CORCHETES_EN_MAYÚSCULAS)\]' || true)"

  if [ -n "$leftovers" ]; then
    echo "❌ Quedan placeholders sin rellenar:"
    printf '%s\n' "$leftovers"
    echo "→ Rellénalos o borra el documento si no aplica (la plantilla original trae la guía en TEMPLATE-USAGE.md)."
    exit 1
  fi
  echo "✅ Placeholders: no queda ninguno sin rellenar."
fi
