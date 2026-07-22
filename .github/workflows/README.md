# Workflows de CI/CD

Esta carpeta contiene los workflows de [GitHub Actions](https://docs.github.com/actions)
del proyecto.

## Workflows activos (agnósticos del stack)

Funcionan tal cual, sin importar el lenguaje del proyecto — no los borres al instanciar:

- [`quality.yml`](quality.yml) — calidad de la documentación: formato Markdown
  (Prettier), enlaces internos, placeholders, estructura de skills/agentes y la suite
  de pruebas de los scripts del repo (ver [`../scripts/`](../scripts)).
- [`secret-scan.yml`](secret-scan.yml) — escaneo de secretos con
  [gitleaks](https://github.com/gitleaks/gitleaks) sobre el historial.

## Esqueleto incluido

- `ci.example.yml` — pipeline de CI neutro (lint → test → build). Cuando lo adaptes a
  tu stack, renómbralo a `ci.yml` (por eso aquí se menciona sin enlace: tras renombrarlo
  el enlace quedaría roto).

  > **GitHub sí lo ejecuta.** El `.example` del nombre no lo desactiva: Actions registra
  > cualquier `.yml` de esta carpeta. Sus pasos están comentados, así que los tres jobs
  > (`Lint`, `Tests`, `Build`) pasan vacíos hasta que los completes. Por eso **no los
  > pongas como checks requeridos** en la protección de rama antes de rellenarlos: al
  > reemplazar este archivo por tu CI real, los contexts requeridos dejarían de
  > reportarse y los PRs se quedarían bloqueados esperándolos.

## Workflows recomendados

| Workflow                    | Propósito                                      |
| --------------------------- | ---------------------------------------------- |
| `ci.yml`                    | Lint, tests y build en cada push/PR.           |
| `labeler.yml`               | Auto-etiquetado de PRs (usa `../labeler.yml`). |
| `dependabot-auto-merge.yml` | Auto-merge de PRs de Dependabot (parches).     |
| `deploy.yml`                | Despliegue (depende de tu infraestructura).    |

## Secrets

Define en **Settings → Secrets and variables → Actions** los secretos que
necesiten tus workflows (claves de deploy, tokens, etc.). Ver
[`../../docs/conventions/secrets.md`](../../docs/conventions/secrets.md).
