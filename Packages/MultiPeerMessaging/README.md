# MultiPeerMessaging

A standalone Swift package for one server with multiple simultaneous clients,
using Bonjour discovery, mutually authenticated QUIC, and JSON messages.
Requires Swift tools 6.2 and iOS/iPadOS 26, visionOS 26, or macOS 26.

## Architecture and provenance

Derived from the networking architecture and security implementation of
[`C5-Cihuy/network-example`](https://github.com/C5-Cihuy/network-example),
`iPadCompanionApp/Packages/PeerToPeerMessaging`, commit
`6925d93e3d8beda730a0788dcd97fbb393fd4f64`, as copied into this repository.
See `LICENSE.txt` for the Apple sample license. The original local package is
unchanged; this package does not depend on it and is not wire-compatible with it.

Changes include a per-client connection registry, independent stream/receive
tasks, targeted sends, concurrent broadcast with individual results, peer-aware
events, capacity and handshake limits, and separate session/device identities.
Networking has no SwiftUI dependency. UI adapters are deliberately left to the
consuming app; they should have one event/message consumer and fan out as needed.

### Source structure

```text
Sources/MultiPeerMessaging/
├── Actors/
│   ├── Server.swift
│   └── Client.swift
├── Protocols/
│   └── PeerMessagingProtocols.swift
├── TLS/
│   ├── TLSIdentity.swift
│   └── CertificateTrustManager.swift
├── Internal/
│   ├── ConnectionRegistry.swift
│   ├── ServerConnection.swift
│   └── WireEnvelope.swift
├── ConnectionTypes.swift
├── MessagingConfiguration.swift
└── MessagingError.swift
```

The actors use focused extensions for lifecycle, messaging, and connection state.
TLS identity creation and certificate trust each retain serialized keychain access.
Internal types are not part of the public API. There is no shared single-peer
manager protocol: the server supports targeted sending and broadcast, while the
client sends to its one connected server.

### API naming migration

- `Host` → `Server` (no compatibility alias).
- `PeerMessage` → `PeerToPeerMessage`.
- `events` → `networkUpdateEvents`.
- `messages` → `receivedMessages`.
- `Client.connectedHost` → `Client.connectedServer`.

The wire format, discovery configuration, and keychain identifiers are unchanged.
When importing both packages, qualify shared names as needed, for example
`MultiPeerMessaging.Server<TestMessage>` and
`MultiPeerMessaging.PeerToPeerMessage`.

## Identities

- `sessionID`: shared discovery filter, not a secret or an authorization token.
- `peerID`: unique UUID persisted by the app across launches, used as the local
  certificate subject. Never generate it on every connection or share it between
  installations. The app owns persistence; the package stores its TLS key and
  certificate in the keychain.
- `ConnectionID`: fresh UUID per connection, used for targeted sends and cleanup.

Both sides exchange a versioned hello. Its session must match, and its peer UUID
must match the certificate on that exact QUIC connection. Duplicate active peer
UUIDs are rejected. One bidirectional messaging stream is allowed per client.

## App setup

Add the local package and its `MultiPeerMessaging` product to your app target.
For this repository, make these changes in `project.yml` and regenerate with
`xcodegen generate --spec project.yml`. This repository already links the package
to the `Testing` app target; networking is not started automatically.

Your app's Info.plist must contain:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Connect this device to the server and other participants on your local network.</string>
<key>NSBonjourServices</key>
<array><string>_multipeer._udp</string></array>
```

If you customize `serviceType`, use the same value in the app's Bonjour services.
All participants must use the same service type, ALPN, session ID, and message
schema. Sandboxed macOS apps also need appropriate network client/server entitlements.

## Usage

```swift
import Foundation
import MultiPeerMessaging

struct TestMessage: PeerToPeerMessage {
    enum Kind: String, Codable, Sendable { case ping, acknowledgment, broadcast }
    let id: UUID
    let kind: Kind
    let text: String
}

// Each device supplies its own persisted UUID.
let configuration = try MessagingConfiguration(
    sessionID: "test-room-01",
    peerID: persistedPeerID,
    maximumClients: 8,
    handshakeTimeout: .seconds(15)
)
```

### Server

```swift
let server = Server<TestMessage>(configuration: configuration)

let eventTask = Task {
    for await event in server.networkUpdateEvents { print(event) }
}
let messageTask = Task {
    for await incoming in server.receivedMessages {
        if incoming.message.kind == .ping {
            do {
                try await server.send(TestMessage(
                    id: incoming.message.id, kind: .acknowledgment, text: "Received"
                ), to: incoming.connectionID)
            } catch { print("Reply failed:", error) }
        }
    }
}

try await server.start() // Observe .listening before asking clients to connect.
let peers = await server.connectedPeers
let results = await server.broadcast(TestMessage(id: UUID(), kind: .broadcast, text: "Hello everyone"))
for (id, result) in results { print(id, result) }

// When finished:
await server.stop()
eventTask.cancel()
messageTask.cancel()
```

### Client (on each client device)

```swift
let client = Client<TestMessage>(configuration: configuration)
let eventTask = Task {
    for await event in client.networkUpdateEvents { print(event) }
}
let messageTask = Task {
    for await incoming in client.receivedMessages { print(incoming.message) }
}

try await client.connect() // Returns only after the server acknowledges the hello.
try await client.send(TestMessage(id: UUID(), kind: .ping, text: "Ping"))

// When finished:
await client.disconnect()
eventTask.cancel()
messageTask.cancel()
```

## Lifecycle and delivery semantics

- `start()` launches the listener; readiness/errors arrive through events.
- Calling `start()` or `connect()` while already active throws `alreadyRunning`.
- The client timeout includes discovery, stream opening, and hello exchange.
- Server capacity includes pending handshakes to prevent unlimited idle clients.
- A disconnect removes only that connection. The server continues listening even
  with zero clients. Stop/disconnect are safe to call repeatedly.
- Reconnect explicitly by calling `connect()` again. There is no automatic retry.
- Sends throw when disconnected or when transport fails. Successful send means
  transport submission, not application acknowledgment; use message IDs and
  explicit acknowledgments when that distinction matters.
- Broadcast snapshots currently authenticated connections and returns one result
  per connection. Delivery order across separate broadcast/send calls is not promised.
- `networkUpdateEvents` and `receivedMessages` each have **one consumer**. They are not multicast.
  Streams stay open across stop/restart until the actor is destroyed. Consumers
  must be cancelled by their owner. Default AsyncStream buffering is unbounded:
  consume promptly; this initial test package is not intended for large payloads
  or sustained high-throughput workloads.
- Explicitly stop/disconnect before releasing the networking owner.
- This version does not support client-to-client routing or protocol migration.

## Security limitations

Like the sample, this uses self-signed certificates and trust on first use (TOFU).
Certificate validity dates are checked; subsequent connections must use the same
fingerprint for a peer UUID. Keychain writes are serialized in-process.
TOFU does not verify who a peer is on first contact. Bonjour session IDs are
public, and are not an access-control mechanism. Use only for controlled demos;
production pairing needs explicit authorization and verified identity exchange.
Certificate rotation/trust reset is not exposed yet. Certificates last one year;
an expired or replaced identity requires an intentional identity/trust migration.

## Verification

Run deterministic tests from this package directory:

```sh
swift test
```

Tests cover multi-client bookkeeping, pending capacity, duplicate identities,
disconnect/reconnect isolation, stale cleanup, hello validation, JSON round trips,
invalid configuration, and disconnected sends. They do not start live networking
or touch the keychain, and do not establish real-device interoperability.

For acceptance testing, run one server and two clients on distinct iOS/iPadOS 26
devices on the same Wi-Fi network, with local-network permission granted:

1. Confirm the server emits `.listening`, then connect both clients.
2. Confirm two distinct peer/connection IDs appear in `connectedPeers`.
3. Ping from both; confirm each acknowledgment has the corresponding message ID.
4. Broadcast and confirm both clients receive it.
5. Disconnect one; verify the other can still ping and the listener stays active.
6. Reconnect the first; verify two entries, not three.
7. Stop/restart the server, then reconnect both clients.
8. Check a wrong session ID times out without joining the server.
9. Check duplicate peer IDs and capacity violations are rejected without affecting
   existing clients.

Keep one server per session ID; server selection is currently the first discovered
matching service. A simulator build verifies compilation, not physical discovery.
