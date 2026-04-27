# ModelGraphGenerator Docs

Documentation website for [ModelGraphGenerator](https://github.com/PhonePe/ModelGraphGenerator), built with [Docusaurus](https://docusaurus.io/).

## Local Development

### Prerequisites

- Node.js 18+
- npm 9+

### Install

```bash
npm install
```

### Start Dev Server

```bash
npm start
```

This opens a browser at `http://localhost:3000/ModelGraphGenerator/`. Pages hot-reload on save.

### Build for Production

```bash
npm run build
```

Static output is generated in `build/`.

### Serve Production Build Locally

```bash
npm run serve
```

## Deployment

The docs site is deployed to GitHub Pages automatically via `.github/workflows/deploy-docs.yml` when changes are pushed to `main`.

Manual deploy:

```bash
GIT_USER=<your-github-username> npm run deploy
```

## Structure

```
docs/
├── blog/              # Blog posts (release notes, announcements)
├── docs/              # Documentation Markdown files
│   ├── guides/        # How-to guides
│   ├── architecture/  # Internal architecture deep-dives
│   └── examples/      # Real-world usage examples
├── src/
│   ├── components/    # React components
│   ├── css/           # Custom CSS / theming
│   └── pages/         # Custom pages (homepage)
└── static/            # Static assets (images, example JSONs)
    └── examples/      # Generated JSON Schema examples
```
