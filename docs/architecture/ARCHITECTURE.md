# Architecture

The platform is a microservices monorepo with eight deployable Go services, a Next.js backoffice, and a React Native app. The API gateway is the single public API entry point. Services remain stateless. MySQL databases are separately owned. Critical cross-service effects use an outbox/event approach; the local baseline keeps event interfaces explicit and can run synchronously where no broker is available.

Security boundaries are enforced server-side. Mobile UI visibility is never treated as authorization. Access/refresh credentials belong in secure platform storage on mobile.
