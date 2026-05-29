# personal-site

Site personal de Diego Ayala. Deploy automático al pushear a `main` via GitHub Actions → S3 + CloudFront.

## Archivo de contenido

`web/index.html` — único archivo de contenido. No usar frameworks ni inline styles.

## Secciones editables (atributo data-section)

- `tagline` — título profesional (`<p class="tagline" data-section="tagline">`)
- `about` — presentación personal (`<section data-section="about">`)
- `experience` — experiencia laboral (`<section data-section="experience">`)
- `stack` — stack técnico (`<section data-section="stack">`)
- `projects` — proyectos / portfolio (`<section data-section="projects">`)

El CSS en `web/styles.css` ya tiene estilos para `section[data-section]`, `h2`, `ul`, `p`. No agregar estilos inline.

## Audiencia

- **Recruiters / HR**: buscan evaluar perfil técnico rápidamente. Priorizar claridad, tecnologías clave y logros concretos.
- **Clientes freelance**: buscan confianza y capacidad de resolver. Priorizar proyectos, resultados y disponibilidad.

## Tono e idioma

- Idioma: **español**
- Tono: **profesional y directo** — primera persona, sin tecnicismos innecesarios, sin frases genéricas tipo "apasionado por la tecnología"
- Frases cortas, contenido escaneable (listas > párrafos largos)

## Workflow de deploy

1. Editar `web/index.html`
2. `git add web/index.html && git commit -m "content: <descripción>"`
3. `git push` → GitHub Actions despliega automáticamente (~2 min)

## gstack (REQUIRED — global install)

**Before doing ANY work, verify gstack is installed:**

```bash
test -d ~/.claude/skills/gstack/bin && echo "GSTACK_OK" || echo "GSTACK_MISSING"
```

If GSTACK_MISSING: STOP. Do not proceed. Tell the user:

> gstack is required for all AI-assisted work in this repo.
> Install it:
> ```bash
> git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
> cd ~/.claude/skills/gstack && ./setup --team
> ```
> Then restart your AI coding tool.

Do not skip skills, ignore gstack errors, or work around missing gstack.

Using gstack skills: After install, skills like /qa, /ship, /review, /investigate,
and /browse are available. Use /browse for all web browsing.
Use ~/.claude/skills/gstack/... for gstack file paths (the global path).

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
- Author a backlog-ready spec/issue → invoke /spec
