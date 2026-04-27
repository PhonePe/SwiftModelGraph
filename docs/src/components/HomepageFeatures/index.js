import clsx from 'clsx';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: 'Simple Annotations',
    icon: (
      <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
        <path d="M5 14l6 6L23 8" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    ),
    description: (
      <>
        Three macros — <code>@ChimeraSchema</code>, <code>@ChimeraProperty</code>, <code>@ChimeraMetaData</code> —
        are all you need. No configuration files, no build plugins.
      </>
    ),
  },
  {
    title: 'JSON Schema Draft 2020-12',
    icon: (
      <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
        <rect x="4" y="3" width="14" height="18" rx="2" stroke="currentColor" strokeWidth="2"/>
        <path d="M10 3v18M4 9h14M4 15h14" stroke="currentColor" strokeWidth="1.5" opacity="0.5"/>
        <rect x="10" y="7" width="14" height="18" rx="2" stroke="currentColor" strokeWidth="2"/>
      </svg>
    ),
    description: (
      <>
        Generates standard JSON Schema Draft 2020-12, compatible with OpenAPI 3.1, AJV, and all
        major schema validators and code generators.
      </>
    ),
  },
  {
    title: 'Multi-Strategy Discovery',
    icon: (
      <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
        <circle cx="12" cy="12" r="8" stroke="currentColor" strokeWidth="2"/>
        <path d="M18 18l6 6" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round"/>
      </svg>
    ),
    description: (
      <>
        Finds models via macro scanning and IndexStoreDB protocol conformance — works regardless
        of how your Swift project is structured.
      </>
    ),
  },
  {
    title: 'Polymorphic Types',
    icon: (
      <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
        <path d="M14 4v8m0 0l-8 8m8-8l8 8" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
        <circle cx="14" cy="4" r="2" fill="currentColor"/>
        <circle cx="6" cy="22" r="2" fill="currentColor"/>
        <circle cx="22" cy="22" r="2" fill="currentColor"/>
      </svg>
    ),
    description: (
      <>
        Use <code>@ChimeraPolymorphic</code> and <code>@PolymorphicMapping</code> to generate <code>oneOf</code> schemas with discriminator
        fields for protocol-backed polymorphic types.
      </>
    ),
  },
  {
    title: 'Rich Constraints',
    icon: (
      <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
        <rect x="4" y="4" width="20" height="20" rx="4" stroke="currentColor" strokeWidth="2"/>
        <path d="M10 14h8M14 10v8" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
      </svg>
    ),
    description: (
      <>
        Attach <code>minLength</code>, <code>maxLength</code>, <code>pattern</code>, <code>min</code>,
        <code>max</code>, and more directly to your Swift properties.
      </>
    ),
  },
  {
    title: 'Fast CLI',
    icon: (
      <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
        <path d="M7 8l6 6-6 6M15 20h8" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    ),
    description: (
      <>
        Single command, seconds to run. Use <code>--macro-only</code> to scan only annotated files
        and speed up large codebases even further.
      </>
    ),
  },
];

function Feature({ icon, title, description }) {
  return (
    <div className={clsx('col col--4', styles.featureCol)}>
      <div className={styles.featureCard}>
        <div className={styles.featureIconWrapper}>{icon}</div>
        <h3 className={styles.featureTitle}>{title}</h3>
        <p className={styles.featureDescription}>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <h2 className={styles.sectionTitle}>Capabilities</h2>
        <p className={styles.sectionSubtitle}>
          Powerful, zero-config schema generation that works with your existing Swift code.
        </p>
        <div className={clsx('row', styles.featureRow)}>
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
