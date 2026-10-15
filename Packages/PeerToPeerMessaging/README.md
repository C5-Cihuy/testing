# PeerToPeerMessaging

Local Swift package copied from
[`C5-Cihuy/network-example`](https://github.com/C5-Cihuy/network-example),
directory `iPadCompanionApp/Packages/PeerToPeerMessaging`, at commit
`6925d93e3d8beda730a0788dcd97fbb393fd4f64`.

The Swift sources and package manifest are unchanged. Repository-local agent
settings were omitted. See `LICENSE.txt` for the upstream sample license.

Requires Swift tools 6.2 and declares iOS 26 / visionOS 26 support. The package
depends on Apple's `swift-certificates` package and is linked to the `InSync`
app target as a local package.

Import it with `import PeerToPeerMessaging`. Linking the package does not start
networking. Before using discovery or messaging, configure the app's Bonjour
services and local-network usage description for the service being used.
