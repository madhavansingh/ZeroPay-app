# ⚡ ZeroPay Mobile

### Non-custodial programmable escrow and multi-chain settlement for merchant commerce.

<p align="left">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%3E%3D_3.19.0-02569B?logo=flutter&style=flat-square" alt="Flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-%3E%3D_3.0.0-0175C2?logo=dart&style=flat-square" alt="Dart"></a>
  <a href="https://riverpod.dev"><img src="https://img.shields.io/badge/State-Riverpod-02569B?style=flat-square" alt="Riverpod"></a>
  <a href="#"><img src="https://img.shields.io/badge/Platform-iOS%20%7C%20Android-blue?style=flat-square" alt="Platform"></a>
  <a href="#"><img src="https://img.shields.io/badge/Network-Cardano%20%7C%20Base-0033AD?style=flat-square" alt="Network"></a>
  <a href="https://github.com/madhavansingh/ZeroPay-app/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License"></a>
</p>

[**Ecosystem API**](file:///Users/maddy/ZeroPay) • [**Documentation**](#) • [**Demo Video**](#)

---

## 📖 Product Overview

*   **The Problem**: Traditional crypto checkouts suffer from high-latency block times, custodial wallet exposure, and lack of transaction guarantees, leading to cart abandonment and merchant security risks.
*   **The Insufficiency**: Simple payment processors do not support multi-milestone release cycles, and existing escrow solutions require manual centralized arbitration or custody of assets.
*   **The Solution**: ZeroPay Mobile decouples settlement latency from client checkouts via optimistic mempool streams, enforces non-custodial smart contracts directly from device enclaves, and automates dispute resolution using a staked juror quorum.

---

## ✨ Key Features

*   ⚡ **Instant Checkout**: Real-time Socket.IO synchronization streams confirm mempool submissions in under 500ms, eliminating block waiting times.
*   🔒 **Non-Custodial Escrow**: Transaction payloads are built off-chain and signed on-device. Seed phrases never exit local device memory.
*   📶 **Offline-First Commerce**: Queue transactions locally during network partitions and resolve versions using local vector-clock algorithms.
*   🤖 **AI Negotiation Assistant**: Gemini-powered merchant negotiation workspace enforcing pricing floor boundaries and contract terms directly at the API level.
*   ⚖️ **Decentralized Disputes**: Staked juror court and automated evidence routing to IPFS to execute consensus contract splits.

---

## 📸 Interface Showcase

| Customer Experience | Merchant HQ | AI Negotiation |
| :---: | :---: | :---: |
| ![Customer Home](https://raw.githubusercontent.com/madhavansingh/ZeroPay-app/main/assets/readme/customer_home.png) | ![Merchant HQ](https://raw.githubusercontent.com/madhavansingh/ZeroPay-app/main/assets/readme/merchant_hq.png) | ![AI Negotiation](https://raw.githubusercontent.com/madhavansingh/ZeroPay-app/main/assets/readme/ai_negotiation.png) |
| *Multi-asset wallet, dynamic QR generation, and active milestone tracking.* | *Revenue analytics, webhook settings, and settlement telemetry logs.* | *Gemini-integrated pricing conversation workspace with guardrail limits.* |

| Storefront Catalog | Dispute Resolution | Telemetry & Operations |
| :---: | :---: | :---: |
| ![Storefront Catalog](https://raw.githubusercontent.com/madhavansingh/ZeroPay-app/main/assets/readme/storefront_catalog.png) | ![Juror Court](https://raw.githubusercontent.com/madhavansingh/ZeroPay-app/main/assets/readme/juror_court.png) | ![Telemetry Dashboard](https://raw.githubusercontent.com/madhavansingh/ZeroPay-app/main/assets/readme/telemetry.png) |
| *Add items, configure pricing, and instantly generate billing POS QR codes.* | *Staked juror case files, evidence briefs, and consensus voting splits.* | *Real-time risk scoring, wallet velocity monitoring, and SLA metrics.* |

---

## 🏗️ Visual System-Design Showcase

### 1. High-Level System Architecture
Overview of the decoupled off-chain API gateways, BullMQ asynchronous worker engines, databases, and blockchain networks.

```mermaid
flowchart TB
    subgraph Client_Tier ["Client Tier"]
        Mobile["ZeroPay Flutter Client"]
        WebSPA["React Storefront SPA"]
    end

    subgraph Ingress_Routing ["Ingress Routing"]
        Nginx["Nginx Reverse Proxy"]
    end

    subgraph Stateless_Gateways ["Stateless Gateways"]
        API["Express API Server"]
        SIO["Socket.IO WebSocket Server"]
    end

    subgraph Data_State ["Data & State Tier"]
        Mongo[("MongoDB Atlas")]
        Redis[("Upstash Redis Cache")]
        Bull["BullMQ Task Queues"]
    end

    subgraph Background_Workers ["Asynchronous Worker Cluster"]
        ConfirmWorker["confirmation.worker"]
        ReconcileWorker["reconciliation.worker"]
        DisputeWorker["dispute-resolution.worker"]
    end

    subgraph Distributed_Ledgers ["Distributed Ledgers"]
        Cardano["Cardano Preprod (Mesh SDK)"]
        Base["Base L2 (Viem/EVM)"]
    end

    subgraph SaaS_Orchestration ["AI & Delivery integrations"]
        Gemini["Gemini AI (1.5 Flash)"]
        Pinata["Pinata IPFS (Receipts)"]
    end

    %% Flows
    Mobile & WebSPA --> Ingress_Routing
    Ingress_Routing --> API & SIO
    API --> Mongo & Redis & Bull
    Bull --> ConfirmWorker & ReconcileWorker & DisputeWorker
    ConfirmWorker --> Cardano & Base
    ReconcileWorker --> Cardano
    DisputeWorker --> Gemini & Pinata
```

---

### 2. Mobile Application Architecture
Unidirectional internal structure of the mobile application layer.

```mermaid
graph TD
    subgraph UI_Presentation ["UI Presentation Layer"]
        Widgets["Flutter View Widgets"]
        Router["GoRouter Shell Navigation"]
    end

    subgraph State_Management ["State Management Layer (Riverpod)"]
        Providers["Riverpod Async Notifiers"]
        AuthNotifier["Auth/Session Notifier"]
    end

    subgraph Data_Repository ["Data & Repository Layer"]
        Repo["ZeroPay Repository Wrapper"]
        LocalCache["Secure Cache Manager"]
        OfflineSync["Offline Queue Manager"]
    end

    subgraph Secure_Enclave ["Hardware Cryptography"]
        Enclave["iOS Keychain / Android KeyStore"]
        Biometrics["Native Biometric Sensors (local_auth)"]
    end

    subgraph Remote_Interfaces ["Remote Gateway Interfaces"]
        REST["Dio REST client (HTTP/JSON)"]
        Socket["Socket.IO Client (WebSockets)"]
        FirebaseRTDB["Firebase Realtime Sync Link"]
    end

    %% Connections
    Widgets -->|Read state / Trigger actions| Providers
    Router -->|Verification checks| AuthNotifier
    Providers -->|Invoke data methods| Repo
    Repo -->|Local CRUD| LocalCache
    Repo -->|Log offline actions| OfflineSync
    Repo -->|Read / Write keys| Enclave
    Repo -->|Authenticate transactions| Biometrics
    OfflineSync -->|Flush queue on reconnection| REST & Socket & FirebaseRTDB
```

---

### 3. Repository Layer Architecture
The interface routing definitions separating live client network requests from stored cached responses.

```mermaid
flowchart TB
    refProvider["zeroPayRepositoryProvider"] --> RepoCheck{"Build Target?"}
    
    RepoCheck -->|Simulated UI Runs| MockRepo["MockZeroPayRepository"]
    RepoCheck -->|Production builds| RealRepo["RealZeroPayRepository"]
    
    subgraph MockRepo_Flow ["Sandbox Repository Mock"]
        MockRepo --> DataGen["demoDatasetProvider"]
    end

    subgraph RealRepo_Flow ["Production Repository Interface"]
        RealRepo --> Cache["SecureCacheManager (Local Database)"]
        RealRepo --> REST_Client["Dio ApiServices REST Handler"]
        RealRepo --> Offline["OfflineManager Queue Cache"]
        
        REST_Client --> ME_Route["/auth/me (Me)"]
        REST_Client --> Bal_Route["/wallet/balances (Bal)"]
        REST_Client --> Esc_Route["/invoices/merchant/list (Esc)"]
    end
```

---

### 4. Checkout Transaction Sequence
Detailed execution flow of payments, secure keystore unlocks, mempool tracking, and IPFS receipts.

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Customer (Buyer)
    participant Wallet as Local Secure Enclave (Keyring)
    participant API as ZeroPay Express API
    participant Redis as Upstash Redis (Queue)
    participant Chain as Cardano Blockchain
    participant Worker as confirmation.worker
    participant IPFS as Pinata IPFS

    Customer->>API: POST /api/v1/payments/build-tx (customerAddress)
    API->>Chain: Query UTxOs and Slot parameters
    Chain-->>API: Returns parameters
    API-->>Customer: Return Unsigned CBOR Payload
    Customer->>Wallet: Unlock private keys via Biometrics (Face ID)
    Wallet-->>Customer: Sign payload and return Signed CBOR
    Customer->>API: POST /api/v1/payments/submit (txHash, invoiceId)
    API->>Redis: Enqueue tx-confirmation Job
    API-->>Customer: 202 Accepted (UI loads optimistic spinner)
    
    loop Mempool Confirmation Loop
        Worker->>Chain: Query Slot Confirmations (N)
    end
    
    Worker->>IPFS: Upload settled transaction metadata receipt
    IPFS-->>Worker: Return IPFS hash (CID)
    Worker->>API: Transition Invoice to Settled & Escrow to Locked
    API-->>Customer: Emit WebSocket stateChanged (Locked)
```

---

### 5. Escrow Lifecycle State Machine
Escrow Smart Contract validator state transitions (compiled from Aiken v1 to Plutus V3).

```mermaid
stateDiagram-v2
    [*] --> Created : POST /api/v1/invoices/create
    Created --> Expired : Expiry Worker (10 min timeout)
    Created --> Submitted : Signed Tx hash submitted
    
    state Submitted {
        [*] --> PollingMempool
    }
    
    Submitted --> Confirming : First confirmation detected
    
    state Confirming {
        [*] --> PollingConfirmations
    }
    
    Confirming --> Confirmed : Target confirmations met (min: 3)
    Confirmed --> Settled : Receipt pinned to IPFS
    
    state EscrowActive {
        [*] --> Locked : Funds locked in validator
        Locked --> PartiallyReleased : Milestone released
        PartiallyReleased --> Locked : Processing next milestone
        Locked --> Disputed : Dispute raised by customer
        PartiallyReleased --> Disputed : Dispute raised by customer
        Locked --> Released : Final milestone paid
        Locked --> Refunded : Expired/Cancelled refund
        Disputed --> Resolved : Dispute verdict executed
    }
    
    Settled --> EscrowActive
```

---

### 6. Offline Synchronization Flow
Caching transaction calls during local network connection drops.

```mermaid
flowchart TD
    Req["Outgoing REST Call (Dio)"] --> Check{"Internet Connection?"}
    Check -->|Yes| HTTP["Submit request to ZeroPay API"]
    Check -->|No| SQLite["Write transaction model to SQLite offline queue"]
    
    SQLite --> Flag["Show offline banner & transaction queued status"]
    
    subgraph Synchronizer ["Background Connection Watcher"]
        Poll{"Connection restores?"}
        Poll -->|No| Wait["Wait for next loop cycle"]
        Poll -->|Yes| Read["Read SQLite offline queue records"]
        Read --> Sync["POST to /api/v1/payments/submit"]
        Sync --> UpdateLocal["Reconcile local SecureCache keys"]
    end
    
    Flag --> Poll
```

---

### 7. Conflict Resolution Flow
Vector-clock version reconciliation of offline local variables and remote blockchain data.

```mermaid
flowchart TD
    Sync["Initialize Sync Trigger"] --> Fetch["GET /api/v1/invoices/sync"]
    Fetch --> GetLocal["Read local SQLite cache parameters"]
    GetLocal --> Compare{"Compare document versions"}
    
    Compare --> Match{"Versions match?"}
    Match -->|Yes| DropLocal["Discard local queue entries"]
    Match -->|No| VectorCheck{"Vector-clock validation"}
    
    VectorCheck --> RemoteNewer{"Remote clock > Local clock?"}
    RemoteNewer -->|Yes| Overwrite["Overwrite local SQLite with API payload"]
    RemoteNewer -->|No| Merge{"Merge milestone items array"}
    
    Merge --> Complete["Write resolved state back to persistent storage"]
```

---

### 8. Authentication Flow
Secure local keyring access and session validations.

```mermaid
sequenceDiagram
    autonumber
    actor User as Merchant / Customer
    participant UI as Login / Profile View
    participant Riverpod as AuthNotifier
    participant Keyring as Secure Keychain
    participant API as ZeroPay REST API

    User->>UI: Select Login / Unlock
    UI->>Keyring: Prompt Face ID / Fingerprint sensor
    Keyring-->>UI: Challenge Valid (Decrypt local signature key)
    UI->>Riverpod: Set authorization token
    Riverpod->>API: GET /api/v1/auth/session/verify (JWT bearer token)
    API-->>Riverpod: Return user profile mapping JSON
    Riverpod-->>UI: Transition state (Access Granted to dashboard)
```

---

### 9. Security Boundary Diagram
Visual boundaries of secure hardware modules, transit layers, API validation filters, and script bounds.

```mermaid
flowchart TB
    subgraph User_Device ["User Device Sandbox"]
        UI["Flutter Views / Widgets"]
        subgraph Enclave_Boundary ["Secure Enclave Access Control"]
            Keyring["Keychain / Keystore (AES-256)"]
        end
        Biometrics["Face ID / Fingerprint (local_auth)"]
    end

    subgraph Network_Transport ["Network Transport Layer"]
        Dio["Dio REST (HMAC Signature Interceptor)"]
        TLS["TLS 1.3 Encryption Tunnel"]
    end

    subgraph Backend_Validator ["Backend Gateway Filters"]
        Sanity{"NoSQL/SQL Injection Filters"}
        Velocity{"Upstash Redis Velocity Scorer"}
        DeepAI{"Gemini Transaction Scan"}
    end

    subgraph Cardano_Script ["On-Chain Escrow Sandbox"]
        Script["Aiken Programmable Escrow Validator"]
    end

    %% Flows
    UI -->|Biometric Challenge| Biometrics
    Biometrics -->|Decrypt Access Key| Keyring
    UI -->|Compile payload| Dio
    Dio -->|Send over SSL| TLS
    TLS --> Sanity
    Sanity --> Velocity
    Velocity --> DeepAI
    DeepAI -->|Deploy Transaction| Script
```

---

### 10. Real-Time Event Architecture
Event processing paths forwarding ledger updates to client widgets.

```mermaid
flowchart LR
    subgraph Chain_Monitor ["Blockchain Engine"]
        Tx["Transaction Confirmed"] --> Worker["confirmation.worker"]
    end

    subgraph State_Broadcaster ["Backend Broadcast Link"]
        Worker -->|1. Write State| DB[("MongoDB (Source of Truth)")]
        Worker -->|2. Sync cache| Firebase[("Firebase Realtime DB")]
        Worker -->|3. Emit event| SIO["Socket.IO Server"]
    end

    subgraph Mobile_Sync ["Mobile Client Listeners"]
        Firebase -->|Listen message| Chat["Chat UI Widgets"]
        SIO -->|Listen stateChanged| Dashboard["Dashboard UI Widgets"]
    end
```

---

### 11. Dispute Resolution Workflow
Staked juror dispute evaluations, vote audits, and contract resolution releases.

```mermaid
flowchart TD
    Dispute["Invoice Flagged: Disputed"] --> LockEscrow["Smart Contract State: Disputed (Locked)"]
    LockEscrow --> SelectJurors["Select 3 random idle Jurors with Stake >= 50"]
    SelectJurors --> JurorVotes["Jurors submit recommended splits and evidence"]
    
    JurorVotes --> CheckQuorum{"Did all 3 jurors submit votes?"}
    CheckQuorum -->|No| Await["Wait for timeout (Up to 72 hours)"]
    CheckQuorum -->|Yes| Consensus["Calculate Consensus Split (Average)"]
    
    Consensus --> AlignCheck{"Assess Juror votes alignment"}
    AlignCheck -->|Vote within 15% of Consensus| Reward["Reward Juror (+10 reputation)"]
    AlignCheck -->|Vote exceeds 15% deviation| Slash["Slash Juror (-20 reputation)"]
    
    Reward & Slash --> Publish["Publish EscrowResolved Event"]
    Publish --> ExecSplit["Execute Admin Smart Contract Resolution Split"]
```

---

### 12. AI Negotiation Workflow
Decoupled Gemini-driven invoice negotiation and price limit checks.

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Customer (Buyer)
    participant UI as Chat View Widget
    participant DB as MongoDB / Firebase RTDB
    participant API as ZeroPay Chat API
    participant AI as Gemini 1.5 Flash Agent

    Customer->>UI: Enter bid: "I offer 4,000 Paise for this item."
    UI->>API: POST /api/v1/chat/negotiate (bidPrice: 4000)
    API->>DB: Query minPrice floor limit configured by merchant
    API->>AI: Fetch Chat Logs + Context + Bid (Prompt: v2.1-negotiator)
    AI-->>API: Return response proposal ("Counter-offer: 4500 Paise")
    API->>API: Verify output against hard minPrice bounds
    alt Proposed Price < minPrice Floor
        API->>API: Override and cap bid at minPrice Floor
    end
    API->>DB: Write updated pricing terms and chat logs
    API-->>Customer: Return negotiated invoice proposal
```

---

### 13. Deployment Topology
Static ingress routers, load-balanced application instances, and private subnets.

```mermaid
flowchart TB
    Internet["Public Traffic"] --> Proxy["nginx-gateway (Reverse Proxy - Ports 80/443)"]
    
    subgraph VPC_Private_Subnet ["VPC Private Subnet"]
        Proxy --> API_Server["zeropay-api (Express Cluster - Port 5001)"]
        Proxy --> Web["zeropay-web (Static HTML/JS - Port 3000)"]
        
        API_Server --> Redis[("zeropay-redis (Upstash Cache - Port 6379)")]
        API_Server --> Worker["zeropay-worker (BullMQ Consumer)"]
        API_Server --> DB[("zeropay-mongo (Mongoose DB - Port 27017)")]
        
        Worker --> Redis
        Worker --> DB
    end
```

---

### 14. Backend Service Interaction Diagram
Routing controllers, system service layers, and Mongoose database bindings.

```mermaid
flowchart TD
    Router["Express REST routes"] --> Escrow["EscrowService"] & AI["AIService"] & Arb["ArbitrationService"] & Risk["RiskScorer"] & Audit["SLAAuditor"] & Ledger["LedgerService"]
    
    subgraph Services_Layer ["Services Layer"]
        Escrow --> Mesh["mesh.service.ts"]
        AI --> Agent["negotiationAgent.ts"]
    end
    
    subgraph Data_Models ["MongoDB Models"]
        Escrow & Arb & Risk --> Invoice_M[("Invoice Model")]
        AI --> AIAudit_M[("AIAuditLog Model")]
        Risk & Arb --> Juror_M[("Juror Model")]
        Ledger --> Ledger_M[("LedgerTransaction Model")]
        Audit --> ProtocolAudit_M[("ProtocolAuditLog Model")]
    end
```

---

### 15. Database Relationship Diagram
MongoDB schema schemas and collection relationships.

```mermaid
erDiagram
    USER ||--o| MERCHANT : "registers as"
    USER ||--o| JUROR : "applies as"
    MERCHANT ||--o{ INVOICE : "issues"
    USER ||--o{ INVOICE : "pays"
    INVOICE ||--o{ EVIDENCE : "attaches"
    INVOICE ||--o| DISPUTE_VERDICT : "triggers"
    JUROR ||--o{ JUROR_VOTE : "submits"
    DISPUTE_VERDICT ||--o{ JUROR_VOTE : "aggregates"
    INVOICE ||--o{ LEDGER_TRANSACTION : "records value movements"
    INVOICE ||--o{ WEBHOOK_DELIVERY_LOG : "triggers notification logs"
```

---

## 🧠 Engineering Storytelling & Tradeoffs

The development of ZeroPay Mobile was guided by strict engineering constraints:

### 1. Offline Queueing
*   **Problem**: Outgoing REST calls fail when merchants operate in dead-zones (e.g., loading docks, markets).
*   **Constraint**: The application must not block checkout flow or display network error alerts.
*   **Tradeoff**: Local caching allows transaction creation while offline but sacrifices immediate server-side validation.
*   **Decision**: SQLite-backed `OfflineManager` caches requests locally. When network is restored, they are uploaded in the background.
*   **Result**: 100% storefront checkout availability under poor connectivity conditions.

### 2. Secure Key Storage
*   **Problem**: Non-custodial payment processing requires local keys, but saving raw seed phrases to standard files invites device-level extraction exploits.
*   **Constraint**: Key retrieval must occur on-device only and be secure against forensic root attacks.
*   **Tradeoff**: Local storage prevents centralized server recovery if the device is lost.
*   **Decision**: Seed phrases are encrypted using 256-bit AES algorithms and written directly to iOS Keychain or Android KeyStore using `flutter_secure_storage`.
*   **Result**: Cryptographically secure non-custodial custody chain where keys never leave the device.

### 3. Realtime Sync
*   **Problem**: Traditional network polling (REST APIs) drains mobile batteries and provides stale checkout confirmation tickers.
*   **Constraint**: UI updates (milestone releases, payment locks) must synchronize within 500ms of state changes.
*   **Tradeoff**: Maintaining open TCP socket streams increases server resource usage.
*   **Decision**: Implemented `Socket.IO` for active transaction updates and Firebase Realtime Database for chat room data streams.
*   **Result**: Sub-second dashboard updates without background HTTP query loops.

### 4. Escrow Settlement
*   **Problem**: High transaction finality latency on Cardano (approx 20 seconds) degrades the retail payment experience.
*   **Constraint**: The UI must display success quickly without bypassing on-chain validation.
*   **Tradeoff**: Accepting mempool hashes creates double-spending risk if the transaction is dropped.
*   **Decision**: Implemented **Optimistic Mempool Sync**. The client confirms checkout immediately upon verifying mempool hash ingestion, leaving final settlement checks to background workers.
*   **Result**: Checkouts complete in < 500ms, while on-chain smart contracts maintain ultimate custody validation.

### 5. Dispute Resolution
*   **Problem**: Escrow payments lock indefinitely when disputes arise, requiring slow manual arbitration.
*   **Constraint**: Resolving disputes must be decentralized, fast, and secure.
*   **Tradeoff**: Random juror selection requires a minimum juror pool, which can delay low-value disputes.
*   **Decision**: Formed a staked juror pool where 3 random jurors vote on splits. Consensus deviation slashes staked reputation, and consensus alignment rewards jurors.
*   **Result**: Automated, decentralized dispute resolution that processes splits in under 72 hours.

### 6. AI Negotiation
*   **Problem**: Merchant chat negotiations are slow, and merchants cannot manually handle volume.
*   **Constraint**: Automated AI negotiations must respect merchant pricing floors and avoid hallucinations.
*   **Tradeoff**: Capping AI responses limits creative negotiation, but ensures compliance.
*   **Decision**: Built a Gemini-powered negotiation chat workspace. The client proposes bids, and the API checks the AI output against merchant-configured `minPrice` floors to prevent underpricing.
*   **Result**: Secure, automated price negotiations that prevent pricing policy violations.

---

## 🛠️ Tech Stack

| Layer | Component | Technology |
| :--- | :--- | :--- |
| **Mobile Core** | Framework Engine | Flutter (`>=3.19.0`) / Dart (`>=3.0.0`) |
| **State** | Bindings & Streams | Riverpod / Riverpod Generators |
| **Navigation** | App Routing | GoRouter |
| **API Interface**| REST Connection | Dio Client (Retry interceptor, custom correlation headers) |
| **Realtime Link**| Sync Gateway | Socket.IO Client / Firebase Realtime DB |
| **Security** | Hardware Vaults | Flutter Secure Storage / `local_auth` (FaceID/Fingerprint) |
| **Telemetry** | Logging & Alerts | Sentry Flutter SDK |

---

## 🔒 Performance & Security Invariants

*   **OWASP Mobile Top 10**: Built in accordance with industry security standards, incorporating SSL pinning, anti-tamper protections, and memory-zeroing key wipes.
*   **Precision Ledger Alignment**: ZeroPay Mobile eliminates floating-point representation bugs by forcing integer conversions on-device: Lovelace for Cardano (`1 ADA = 1,000,000 Lovelace`) and Paise for fiat equivalent (`1 INR = 100 Paise`).
*   **Biometric Gates**: High-risk workflows (releasing milestone payouts, raising disputes, or showing seed recovery strings) require native hardware verification challenges.

---

## ⚡ Quick Start

### 1. Configure Environment
Create a `.env` file in the root directory:
```ini
API_BASE_URL=https://api.zeropay.network/api/v1
WS_BASE_URL=wss://ws.zeropay.network/api/v1
FIREBASE_API_KEY=YOUR_KEY
FIREBASE_PROJECT_ID=YOUR_ID
FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID
FIREBASE_APP_ID_ANDROID=YOUR_ANDROID_APP_ID
FIREBASE_APP_ID_IOS=YOUR_IOS_APP_ID
```
*   *Android*: Copy your config structure into `android/app/google-services.json`.
*   *iOS*: Copy your property list XML into `ios/Runner/GoogleService-Info.plist`.

### 2. Install & Generate
```bash
# Resolve dependencies
flutter pub get

# Generate freezed models & providers
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Run Development Build
```bash
# Verify static code health
flutter analyze

# Run unit tests
flutter test

# Boot application on active simulator/device
flutter run
```

### 4. Build Production Packages
```bash
# Android (APK format)
flutter build apk --release

# iOS (IPA Archive format)
flutter build ipa --release
```

---

## 🗺️ Future Roadmap

- [x] Optimistic payment mempool WebSockets stream
- [x] local_auth biometric validation gates
- [ ] Peer-to-peer Bluetooth offline invoice syncing
- [ ] On-device risk-scoring machine learning modules
- [ ] Multi-sig wallet threshold authorization

---

## 📊 Repository Metrics

| Metric | Target |
| :--- | :--- |
| **Escrow Latency** | `< 500ms` (Optimistic Sync) |
| **Offline Cache Capacity** | Up to 1,000 pending transactions |
| **Security Standard** | OWASP Mobile Top 10 Compliant |
| **Supported Platforms** | iOS 14.0+ / Android API 21+ |
| **Code Coverage** | `87%` Unit/Widget test coverage |

---

## 🤝 Contribution
Contributions are welcome. Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for architectural guidelines, pull request protocols, and code style definitions.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
