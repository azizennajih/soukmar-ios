import Foundation
import WebRTC

/// Masked in-app voice calling (Tranche 23) — audio-only, signaled over the
/// existing Socket.IO chat connection (ChatSocketManager), never revealing
/// either side's real phone number. Free public STUN only, no TURN, no paid
/// signaling — matches soukmar's web client (chat.service.ts's
/// startCall/acceptCall/rejectCall/endCall/toggleMute) and
/// soukmar-backend's socket.ts call_offer/call_answer/call_ice_candidate/
/// call_end relay events.
///
/// **Status as of this tranche**: only the WebRTC dependency itself
/// (stasel/WebRTC, a prebuilt Google WebRTC XCFramework via SPM — free,
/// no signup/API key, see project.yml's `packages:` comment) is wired up
/// and exercised here with a minimal real call into its API (building an
/// `RTCPeerConnectionFactory` + `RTCConfiguration` with the two free STUN
/// servers), specifically so a Codemagic build proves the binary framework
/// actually resolves *and* links/compiles against real usage — not just
/// that `xcodebuild -resolvePackageDependencies` succeeds, which alone
/// wouldn't catch a linker-level problem with a binary XCFramework
/// dependency. The full offer/answer/ICE-candidate state machine, the
/// Socket.IO event wiring, and the calling UI (call button, incoming-call
/// cover, active-call bar) are intentionally NOT built yet — see this
/// tranche's CLAUDE.md entry for why: this project has no local
/// Xcode/simulator (see CLAUDE.md's "kein lokaler Mac" section), so a
/// binary SPM dependency's very first Codemagic build needs to be
/// confirmed green before investing further time in the larger feature,
/// per this tranche's own scoping instructions.
enum CallManager {
    static let iceServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
    ]

    /// Exercises the real WebRTC API surface (factory + configuration
    /// construction) so this file doesn't just `import WebRTC` without
    /// ever touching a symbol from it — a genuine compile+link check.
    static func makeConfiguration() -> RTCConfiguration {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan
        return config
    }

    static let peerConnectionFactory = RTCPeerConnectionFactory()
}
