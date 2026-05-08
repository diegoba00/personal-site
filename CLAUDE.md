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
