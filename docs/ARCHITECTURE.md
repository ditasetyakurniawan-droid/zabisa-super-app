# Architecture

## Topology

```text
React Native Mobile
        │
        ▼
    API Gateway ───────────────────────────────────────┐
        │                                              │
        ├─ Identity                                    │
        ├─ Content                                     │
        ├─ Student                                     │
        ├─ Tahfidz                                     │
        ├─ Academic                                    │
        ├─ Donation                                    │
        └─ Notification                                │
                                                       │
Next.js Backoffice → BFF session proxy → API Gateway ──┘

Service-owned MySQL databases
        │
        ├─ transactional business writes
        ├─ local outbox where required
        └─ no direct cross-service database queries

NATS / asynchronous events
MinIO / object storage baseline
```

## Technology baseline

- Go: 1.26.7
- MySQL: 8.4
- React Native: 0.87.0
- React mobile: 19.2.3
- Next.js Backoffice: 16.3.3
- React Backoffice: 19.2.x
- TanStack Query for Backoffice/mobile server state
- Zustand for mobile local/session state
- React Hook Form/Zod remain preferred for structured form validation where
  applicable
- Docker Compose for local platform

## Deliberate architectural decisions

### MySQL is canonical

The original specification used another relational database in places, but the
project decision is **MySQL everywhere**. Do not reintroduce PostgreSQL.

### Service data ownership

Each bounded service owns its database/schema. A service must not query another
service's database directly. Cross-context behavior uses APIs/events.

### API Gateway

External clients address the platform through the API Gateway. Internal service
ports are implementation detail, not client contracts.

### Backoffice BFF

The Backoffice uses a server-side BFF/session cookie layer rather than exposing
raw browser bearer-token management.

### Strict API decoding

Unknown JSON fields are rejected. If UI and API disagree, fix the contract.
Never weaken the decoder merely to accommodate a frontend mismatch.

### Transactional audit/event pattern

Sensitive changes write business state and a local audit/outbox record in the
same service transaction where implemented. Delivery to the central audit read
model happens asynchronously.

## Main local ports

| Component | Host |
|---|---:|
| Backoffice | 3001 |
| API Gateway | 8088 |
| MySQL | 3307 |
| NATS client | 4222 |
| NATS monitoring | 8222 |
| MinIO API | 9000 |
| MinIO console | 9001 |
| Zabisa Metro host | 8082 |

Host port 8081 is intentionally not used by Zabisa Metro because another local
process already occupies it.
