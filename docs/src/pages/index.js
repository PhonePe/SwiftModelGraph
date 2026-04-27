import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';
import styles from './index.module.css';

function HomepageHero() {
  return (
    <div className={styles.hero}>
      <div className={styles.heroInner}>
        <div className={styles.heroIcon}>
          <svg width="64" height="64" viewBox="0 0 64 64" fill="none">
            <rect width="64" height="64" rx="14" fill="url(#grad)" />
            <path d="M20 44V20l12 8-12 8zm12-8l12-8v16l-12-8z" fill="white" opacity="0.95" />
            <defs>
              <linearGradient id="grad" x1="0" y1="0" x2="64" y2="64">
                <stop stopColor="#5e5ce6" />
                <stop offset="1" stopColor="#0a84ff" />
              </linearGradient>
            </defs>
          </svg>
        </div>
        <p className={styles.heroEyebrow}>Framework</p>
        <h1 className={styles.heroTitle}>ModelGraphGenerator</h1>
        <p className={styles.heroSubtitle}>
          Generate JSON Schema from Swift models automatically. Annotate your structs
          with <code>@ChimeraSchema</code>, and ModelGraphGenerator discovers every model,
          resolves inheritance and cycles, and emits Draft 2020-12 compliant schemas.
        </p>
        <div className={styles.heroCta}>
          <Link className={styles.heroLink} to="/docs/quick-start">
            Get Started
          </Link>
          <Link className={styles.heroLinkSecondary} to="/docs/">
            Documentation
          </Link>
        </div>
      </div>
    </div>
  );
}

function QuickExample() {
  return (
    <div className={styles.example}>
      <div className={styles.exampleInner}>
        <h2 className={styles.exampleTitle}>See it in action</h2>
        <p className={styles.exampleSubtitle}>
          Annotate a Swift model and generate a complete JSON Schema in seconds.
        </p>
        <div className={styles.exampleGrid}>
          <div className={styles.examplePane}>
            <div className={styles.examplePaneHeader}>Swift Model</div>
            <pre className={styles.exampleCode}>
              <code>{`@ChimeraSchema(key: "product")
struct Product {
    @ChimeraProperty(description: "Product name",
                     minLength: 1)
    let name: String

    @ChimeraProperty(description: "Price in USD",
                     min: 0.0)
    let price: Double

    let categories: [String]
    let inStock: Bool
}`}</code>
            </pre>
          </div>
          <div className={styles.exampleArrow}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M5 12h14m-7-7l7 7-7 7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
          <div className={styles.examplePane}>
            <div className={styles.examplePaneHeader}>JSON Schema</div>
            <pre className={styles.exampleCode}>
              <code>{`{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "description": "Product name",
      "minLength": 1
    },
    "price": {
      "type": "number",
      "description": "Price in USD",
      "minimum": 0.0
    },
    "categories": {
      "type": "array",
      "items": { "type": "string" }
    },
    "inStock": { "type": "boolean" }
  },
  "required": ["name", "price",
    "categories", "inStock"]
}`}</code>
            </pre>
          </div>
        </div>
      </div>
    </div>
  );
}

function TopicSection({ title, description, links }) {
  return (
    <div className={styles.topicSection}>
      <h2 className={styles.topicTitle}>{title}</h2>
      {description && <p className={styles.topicDescription}>{description}</p>}
      <div className={styles.topicGrid}>
        {links.map((link, idx) => (
          <Link key={idx} className={styles.topicCard} to={link.to}>
            <div className={styles.topicCardIcon}>{link.icon}</div>
            <div>
              <div className={styles.topicCardTitle}>{link.title}</div>
              <div className={styles.topicCardDesc}>{link.desc}</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}

export default function Home() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description="Generate JSON Schema from Swift Models automatically using ModelGraphGenerator and ChimeraSchema annotations"
    >
      <HomepageHero />
      <QuickExample />
      <main className={styles.main}>
        <HomepageFeatures />

        <div className={styles.topics}>
          <div className="container">
            <TopicSection
              title="Essentials"
              description="Everything you need to get started with ModelGraphGenerator."
              links={[
                {
                  icon: '1',
                  title: 'Installation',
                  desc: 'Add ModelGraphGenerator to your project via Swift Package Manager.',
                  to: '/docs/installation',
                },
                {
                  icon: '2',
                  title: 'Quick Start',
                  desc: 'Generate your first JSON Schema in under 5 minutes.',
                  to: '/docs/quick-start',
                },
                {
                  icon: '3',
                  title: 'CLI Usage',
                  desc: 'Learn the command-line interface and all available flags.',
                  to: '/docs/guides/cli-usage',
                },
              ]}
            />

            <TopicSection
              title="Architecture"
              description="Understand how ModelGraphGenerator works under the hood."
              links={[
                {
                  icon: 'D',
                  title: 'Discovery System',
                  desc: 'How root models are found via macros and IndexStoreDB.',
                  to: '/core-concepts/discovery',
                },
                {
                  icon: 'P',
                  title: 'AST Parsing',
                  desc: 'SwiftSyntax-powered property and type extraction.',
                  to: '/core-concepts/ast-parsing',
                },
                {
                  icon: 'G',
                  title: 'Graph Building',
                  desc: 'Recursive model resolution with cycle detection.',
                  to: '/core-concepts/graph-building',
                },
              ]}
            />
          </div>
        </div>
      </main>
    </Layout>
  );
}
