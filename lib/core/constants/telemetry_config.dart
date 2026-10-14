const sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue:
      'https://dc53304a6805d5e433dd658ffb299ae7@o4512252084879360.ingest.de.sentry.io/4512252095365200',
);

const posthogProjectToken = String.fromEnvironment(
  'POSTHOG_PROJECT_TOKEN',
  defaultValue: 'phc_oPrUMYqunTFa5ekqfFVYiCGHeEnUuHG8CGPT9xQVKGGJ',
);

const posthogHost = String.fromEnvironment(
  'POSTHOG_HOST',
  defaultValue: 'https://eu.i.posthog.com',
);
