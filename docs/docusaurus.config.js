// @ts-check
import { themes as prismThemes } from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'SwiftModelGraph',
  tagline: 'Generate JSON Schema from Swift Models — Automatically',
  favicon: 'img/favicon.ico',

  url: 'https://phonepe.github.io',
  baseUrl: '/SwiftModelGraph/',

  organizationName: 'PhonePe',
  projectName: 'SwiftModelGraph',
  deploymentBranch: 'gh-pages',
  trailingSlash: false,

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  markdown: {
    mermaid: true,
  },

  themes: ['@docusaurus/theme-mermaid'],

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: './sidebars.js',
          editUrl: 'https://github.com/PhonePe/SwiftModelGraph/tree/main/docs/',
        },
        blog: {
          showReadingTime: true,
          feedOptions: {
            type: ['rss', 'atom'],
          },
          editUrl: 'https://github.com/PhonePe/SwiftModelGraph/tree/main/docs/',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  plugins: [
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'core-concepts',
        path: 'core-concepts',
        routeBasePath: 'core-concepts',
        sidebarPath: './sidebars-core-concepts.js',
        editUrl: 'https://github.com/PhonePe/SwiftModelGraph/tree/main/docs/',
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'performance',
        path: 'performance',
        routeBasePath: 'performance',
        sidebarPath: './sidebars-performance.js',
        editUrl: 'https://github.com/PhonePe/SwiftModelGraph/tree/main/docs/',
      },
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/social-card.png',
      colorMode: {
        defaultMode: 'light',
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
      navbar: {
        title: 'SwiftModelGraph',
        logo: {
          alt: 'SwiftModelGraph Logo',
          src: 'img/logo.svg',
          srcDark: 'img/logo-dark.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docsSidebar',
            position: 'left',
            label: 'Documentation',
          },
          {
            to: '/core-concepts/overview',
            label: 'Core Concepts',
            position: 'left',
            activeBaseRegex: '/core-concepts',
          },
          {
            to: '/performance/overview',
            label: 'Performance',
            position: 'left',
            activeBaseRegex: '/performance',
          },
          {
            to: '/blog',
            label: 'Blog',
            position: 'left',
          },
          {
            href: 'https://github.com/PhonePe/SwiftModelGraph',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Documentation',
            items: [
              { label: 'Introduction', to: '/docs/' },
              { label: 'Installation', to: '/docs/installation' },
              { label: 'Quick Start', to: '/docs/quick-start' },
              { label: 'CLI Usage', to: '/docs/guides/cli-usage' },
            ],
          },
          {
            title: 'Guides',
            items: [
              { label: 'Annotations', to: '/docs/guides/annotations' },
              { label: 'Polymorphic Types', to: '/docs/guides/polymorphic-types' },
              { label: 'JSON Schema Output', to: '/docs/guides/json-schema-output' },
            ],
          },
          {
            title: 'Core Concepts',
            items: [
              { label: 'Overview', to: '/core-concepts/overview' },
              { label: 'Discovery System', to: '/core-concepts/discovery' },
              { label: 'Graph Building', to: '/core-concepts/graph-building' },
              { label: 'Cycle Detection', to: '/core-concepts/cycle-detection' },
            ],
          },
          {
            title: 'Community',
            items: [
              { label: 'GitHub', href: 'https://github.com/PhonePe/SwiftModelGraph' },
              { label: 'Issues', href: 'https://github.com/PhonePe/SwiftModelGraph/issues' },
              { label: 'Contributing', to: '/docs/contributing' },
              { label: 'Changelog', to: '/docs/changelog' },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} PhonePe. Built with Docusaurus.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ['swift', 'bash', 'json'],
      },
      mermaid: {
        theme: { light: 'base', dark: 'dark' },
        options: {
          themeVariables: {
            primaryColor: '#0066cc',
            primaryTextColor: '#ffffff',
            primaryBorderColor: '#d2d2d7',
            lineColor: '#6e6e73',
            secondaryColor: '#f5f5f7',
            tertiaryColor: '#ffffff',
            fontFamily: '-apple-system, BlinkMacSystemFont, SF Pro Text, Helvetica Neue, sans-serif',
            fontSize: '14px',
          },
        },
      },
      algolia: undefined,
    }),
};

export default config;
