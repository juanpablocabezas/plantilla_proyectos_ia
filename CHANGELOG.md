# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Added

- Estructura inicial del proyecto.
- `.gitattributes` que normaliza los fines de línea a LF en todos los sistemas.
- `.prettierrc` que fija `endOfLine: lf`, para que el formateo no dependa del sistema
  donde se ejecute.
- `.gitmessage`, plantilla de mensajes de commit con la estructura de Conventional
  Commits. Se activa con `git config commit.template .gitmessage` (documentado en
  `CONTRIBUTING.md`).

### Changed

- El check de placeholders escanea ahora **todos** los archivos versionados de texto
  (LICENSE, workflows, `dependabot.yml`, `CODEOWNERS.example`…), no solo `*.md` y
  `.env.example`. Un placeholder olvidado en un archivo no-markdown ya no pasa CI en
  verde al instanciar.
- Las referencias al repositorio de origen apuntan ahora a
  `juanpablocabezas/plantilla_proyectos_ia`: el comando `degit` de instalación, el
  guardián de seguridad de `/instanciar` y el `.template-origin` que escribe
  `/actualizar-plantilla`.

### Deprecated

### Removed

- La maquinaria de paridad entre variantes hermanas: el workflow `template-parity.yml`,
  el script `check-parity.sh` y la skill `/portar-cambio`. Solo servían para sincronizar
  la familia de cuatro repositorios (es/en × con/sin IA) de la plantilla de origen, que
  esta plantilla no tiene.
- El andamiaje pensado para contribuidores externos anónimos, que no aplica a proyectos
  con un equipo conocido: `FUNDING.yml` y las secciones "Apóyanos"/"Agradecimientos" del
  `README.md`, la plantilla de issue `support_question.md`, el enlace de contacto a
  Discussions y la etiqueta `good first issue`. La gobernanza para el equipo
  (`CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`) se conserva intacta.

### Fixed

- **Todo proyecto instanciado fallaba el job "Enlaces internos" en su primera corrida de
  CI.** Dos enlaces relativos apuntaban a archivos que la propia guía manda borrar o
  renombrar: `docs/conventions/README.md` → `../../TEMPLATE-USAGE.md` (siempre se borra;
  es lo que activa el modo INSTANCIA del checker) y `.github/workflows/README.md` →
  `ci.example.yml` (siempre se renombra a `ci.yml`). Ahora el primero es un enlace
  absoluto al repo de origen y el segundo se menciona sin enlazar. Detectado con el
  ensayo de instanciación completo, no con los checks del repo — que pasaban en verde.
- `.github/workflows/README.md` afirmaba que la extensión `.example` impide que GitHub
  ejecute `ci.example.yml`. Es falso: Actions registra cualquier `.yml` de la carpeta y
  el workflow aparece como `[active]`. Corregido, con la advertencia de no marcar sus
  jobs vacíos (`Lint`, `Tests`, `Build`) como checks requeridos.
- `TEMPLATE-USAGE.md` §5 mandaba borrar `template-parity.yml`, `check-parity.sh` y la
  skill `portar-cambio`, eliminados en esta misma versión. La instrucción se reemplazó
  por la que de verdad importa: borrar `TEMPLATE-USAGE.md` al terminar.
- Los hooks `git-guardrails` y `secret-guardrails` ya no dependen de `python3`, que en
  Windows resuelve al stub de Microsoft Store y los desactivaba en silencio. Ahora usan
  `perl` (`JSON::PP` y `Text::ParseWords`, ambos core), incluido en Git for Windows.
- `check-placeholders.sh` nunca detectaba los placeholders acentuados (`[AÑO]`,
  `[TECNOLOGÍA]`, `[DECISIÓN_*]`…): el patrón de perl interpretaba su clase de
  caracteres como bytes mientras `-CSD` decodificaba la entrada como UTF-8, así que
  nunca coincidían. Con `-Mutf8` la detección funciona; afloraron 18 placeholders
  acentuados que se añadieron al catálogo.

### Security

- Los hooks de guardrails fallan _cerrados_ cuando falta su intérprete, en lugar de
  permitir la acción sin avisar.

## [0.1.0] - [FECHA]

### Added

- Versión inicial.

<!--
Enlaces de comparación entre versiones (ajusta a tu repositorio):
[Unreleased]: [URL_REPOSITORIO]/compare/v0.1.0...HEAD
[0.1.0]: [URL_REPOSITORIO]/releases/tag/v0.1.0
-->
