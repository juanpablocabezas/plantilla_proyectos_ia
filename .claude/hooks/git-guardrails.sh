#!/usr/bin/env bash
# git-guardrails.sh — hook PreToolUse (OPT-IN) que bloquea acciones de git que
# violan el branching de CONTRIBUTING.md. No está activo por defecto; se habilita
# desde settings.json / settings.local.json (ver docs/conventions/ai-agents.md).
#
# Contrato del hook: lee el JSON del evento por stdin y devuelve exit 2 para
# BLOQUEAR la herramienta — el motivo (stderr) se le muestra al agente. Exit 0
# permite.
#
# Política de fallo, en dos niveles:
#   - Ambigüedad (comando no parseable, no es un repo, HEAD desacoplado): falla
#     ABIERTO para no trabar el flujo.
#   - Entorno roto (falta perl): falla CERRADO. Un guardrail que se desactiva en
#     silencio es peor que uno ausente: creerías estar protegido sin estarlo.
#
# Dependencia: perl con JSON::PP y Text::ParseWords (ambos módulos core). Viene
# incluido en Git for Windows, macOS y las distribuciones Linux habituales, así
# que no hay nada que instalar allí donde ya funciona git.
#
# Cobertura: cada invocación `git …` del comando (incluso encadenadas con && o ;),
# respetando `git -C <ruta>`. Limitación conocida (fail-open): `cd <otra-ruta> &&
# git …` evalúa la rama del cwd de la sesión, no la del destino del `cd`.
set -euo pipefail

payload="$(cat)"

# Comprobamos que perl existe Y que sus módulos cargan: un binario presente pero
# inservible (p. ej. un stub de PATH) debe tratarse como ausente, no como válido.
if ! perl -MJSON::PP -MText::ParseWords -e "" >/dev/null 2>&1; then
  case "$payload" in
    *git*)
      echo "⛔ git-guardrails: falta perl con JSON::PP y Text::ParseWords, así que no puedo" >&2
      echo "   verificar la rama. Bloqueo por precaución. Instala perl o desactiva este hook" >&2
      echo "   en .claude/settings.json (docs/conventions/ai-agents.md)." >&2
      exit 2 ;;
    *) exit 0 ;;
  esac
fi

# Analiza el comando: por cada invocación de git emite una línea
# "subcomando<TAB>force<TAB>ruta-de--C" (solo para commit/push).
verdicts="$(printf '%s' "$payload" | perl -MJSON::PP -MText::ParseWords -e '
use strict; use warnings;

my $raw  = do { local $/; <STDIN> };
my $data = eval { decode_json($raw) } || {};
my $cmd  = eval { $data->{tool_input}{command} } // "";

# Solo nos interesan los comandos que mencionan git; el resto pasa sin tocar.
exit 0 unless $cmd =~ /git/;

my @toks = eval { shellwords($cmd) };
exit 0 if $@ || !@toks;  # comando no parseable: falla abierto

my %SEP = map { $_ => 1 } ("&&", "||", ";", "|");
my %OPT = map { $_ => 1 } ("-C", "-c", "--git-dir", "--work-tree", "--namespace");

my $i = 0;
while ($i < @toks) {
    if ($toks[$i] ne "git") { $i++; next; }
    my ($cdir, $sub, $force) = ("", "", 0);
    my $j = $i + 1;
    while ($j < @toks && !$SEP{$toks[$j]}) {
        my $t = $toks[$j];
        if (!length $sub) {
            if ($OPT{$t}) {
                $cdir = $toks[$j + 1] if $t eq "-C" && $j + 1 < @toks;
                $j += 2;
                next;
            }
            if ($t =~ /^-/) { $j++; next; }
            $sub = $t;
        } else {
            if ($t eq "--force" || $t eq "--force-with-lease" || $t =~ /^--force-with-lease=/) {
                $force = 1;
            } elsif ($t =~ /^-[^-]/ && $t =~ /f/) {
                $force = 1;
            }
        }
        $j++;
    }
    print "$sub\t$force\t$cdir\n" if $sub eq "commit" || $sub eq "push";
    $i = $j;
}
' 2>/dev/null || true)"

[ -z "$verdicts" ] && exit 0

protected_re='^(main|master|develop)$'
block() { echo "⛔ git-guardrails: $1" >&2; exit 2; }

while IFS=$'\t' read -r sub force cdir; do
  [ -z "$sub" ] && continue

  # Rama del repo objetivo; symbolic-ref la resuelve incluso sin commits. Si no
  # es un repo git (o está en detached HEAD), no hay rama protegida que cuidar.
  if [ -n "$cdir" ]; then
    branch="$(git -C "$cdir" symbolic-ref --short -q HEAD 2>/dev/null || true)"
  else
    branch="$(git symbolic-ref --short -q HEAD 2>/dev/null || true)"
  fi

  # 1. Nada de commits directos en ramas protegidas.
  if [ "$sub" = "commit" ] && [ -n "$branch" ] && [[ "$branch" =~ $protected_re ]]; then
    block "No hagas commit directo en '$branch'. Crea una rama feat/…|fix/…|docs/…|chore/… (CONTRIBUTING.md)."
  fi

  # 2. Nada de push directo desde ramas protegidas, ni force-push a nada compartido.
  if [ "$sub" = "push" ]; then
    if [ -n "$branch" ] && [[ "$branch" =~ $protected_re ]]; then
      block "No hagas push directo desde '$branch'. Abre un PR desde tu rama (CONTRIBUTING.md)."
    fi
    if [ "$force" = "1" ]; then
      block "Force-push bloqueado: reescribir historial compartido rompe a otros (CONTRIBUTING.md)."
    fi
  fi
done <<<"$verdicts"

exit 0
