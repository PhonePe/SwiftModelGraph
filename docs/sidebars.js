/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docsSidebar: [
    {
      type: 'doc',
      id: 'intro',
      label: 'Introduction',
    },
    {
      type: 'doc',
      id: 'installation',
      label: 'Installation',
    },
    {
      type: 'doc',
      id: 'quick-start',
      label: 'Quick Start',
    },
    {
      type: 'category',
      label: 'Guides',
      items: [
        'guides/annotations',
        'guides/polymorphic-types',
        'guides/cli-usage',
        'guides/json-schema-output',
      ],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/overview',
        'architecture/discovery-system',
        'architecture/parsers',
        'architecture/graph-building',
      ],
    },
    {
      type: 'category',
      label: 'Examples',
      items: [
        'examples/ecommerce',
        'examples/blog-cms',
        'examples/social-media',
      ],
    },
    {
      type: 'category',
      label: 'Community',
      items: [
        'contributing',
        'code-of-conduct',
        'changelog',
      ],
    },
  ],
};

export default sidebars;
