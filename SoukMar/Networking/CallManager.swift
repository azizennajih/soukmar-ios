import Foundation
import AVFoundation
import WebRTC

/// Masked in-app voice calling (Tranche 23, second half) — audio-only
/// WebRTC, signaled over the *existing* Socket.IO chat connection
/// (`ChatSocketManager`), same contract as soukmar-backend's `socket.ts`
/// `call_offer`/`call_answer`/`call_ice_candidate`/`call_end` relay events
/// and Web's `chat.service.ts` (`startCall`/`acceptCall`/`rejectCall`/
/// `endCall`/`toggleMute`). Free public STUN only (no TURN, no paid
/// signaling) — calls only connect when both peers are directly reachable
/// (no relay fallback behind strict/symmetric NATs), same tradeoff Web
/// documents for its own zero-cost calling feature.
///
/// **API calls verified against `stasel/WebRTC-iOS`'s own reference
/// `WebRTCClient.swift`/`SessionDescription.swift`/`IceCandidate.swift`**
/// (the package author's demo app, read directly from GitHub) rather than
/// guessed from memory, since there is no local compiler here to catch a
/// wrong method signature — `RTCSessionDescription`/`RTCIceCandidate` have
/// no built-in String<->enum conversion helpers, for instance, so this
/// mirrors the demo's own manual `switch`-based mapping instead of
/// assuming one exists.
///
/// **Scoping note inherited from Phase 5's chat architecture**:
/// `ChatSocketManager.onEvent` only has a listener wired up while some
/// `ChatView` is the active screen (see that file's doc comment — "only
/// one screen listens at a time"), and the socket itself only connects
/// lazily when a chat screen opens, not globally at login like Web's
/// `ChatService.connect()`. So unlike Web (or a phone's native dialer),
/// an incoming call can only be received while the recipient already has
/// that exact conversation's `ChatView` open — not from anywhere in the
/// app. Documented as a known, accepted limitation in CLAUDE.md rather
/// than silently shipped as a surprise.
enum CallState: Equatable {
    case idle, outgoing, incoming, active
}

/// Swift-friendly mirror of `RTCSdpType`'s two cases this feature needs,
/// with manual string conversion — mirrors stasel's own demo app pattern
/// (`SessionDescription.swift`), since the framework itself exposes no
/// `RTCSessionDescription.type(for:)`-style helper.
private enum SdpKind: String {
    case offer, answer

    var rtcType: RTCSdpType {
        switch self {
        case .offer: return .offer
        case .answer: return .answer
        }
    }
}

@MainActor
final class CallManager: NSObject, ObservableObject {
    static let shared = CallManager()

    @Published private(set) var state: CallState = .idle
    @Published private(set) var incomingCallerName: String?
    @Published private(set) var muted = false
    @Published var callError: String?

    private static let iceServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
    ]

    // Shared across calls, a fresh RTCPeerConnection is created per call —
    // mirrors stasel's own demo (`WebRTCClient.factory`).
    private static let factory = RTCPeerConnectionFactory()

    // Audio-only, so no video offer/answer constraint needed — mirrors the
    // demo's `mediaConstrains` dict, minus the video half.
    private static let offerAnswerConstraints = RTCMediaConstraints(
        mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
        optionalConstraints: nil
    )

    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var activeConversationId: String?
    private var pendingOfferSdp: RTCSessionDescription?

    private let socketManager = ChatSocketManager.shared

    private override init() { super.init() }

    // MARK: - Incoming socket events (routed here from ChatViewModel)

    func handleIncomingOffer(conversationId: String, sdpType: String, sdp: String, fromUserId: String, fromUserName: String) {
        guard state == .idle else {
            // Already on a call elsewhere — decline automatically instead
            // of leaving the caller hanging, mirrors Web exactly.
            socketManager.emitCallEnd(conversationId: conversationId)
            return
        }
        let kind = SdpKind(rawValue: sdpType) ?? .offer
        pendingOfferSdp = RTCSessionDescription(type: kind.rtcType, sdp: sdp)
        activeConversationId = conversationId
        incomingCallerName = fromUserName
        callError = nil
        state = .incoming
    }

    func handleCallAnswer(conversationId: String, sdpType: String, sdp: String) {
        guard let peerConnection, conversationId == activeConversationId else { return }
        let kind = SdpKind(rawValue: sdpType) ?? .answer
        let description = RTCSessionDescription(type: kind.rtcType, sdp: sdp)
        peerConnection.setRemoteDescription(description) { [weak self] _ in
            Task { @MainActor in self?.state = .active }
        }
    }

    func handleIceCandidate(conversationId: String, candidate: String, sdpMid: String?, sdpMLineIndex: Int32) {
        guard let peerConnection, conversationId == activeConversationId else { return }
        // Arriving after teardown is harmless to ignore, mirrors Web's
        // try/catch around addIceCandidate().
        peerConnection.add(RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid))
    }

    func handleCallEnd(conversationId: String) {
        guard conversationId == activeConversationId else { return }
        teardownCall()
    }

    // MARK: - User actions

    func startCall(conversationId: String) {
        guard state == .idle else { return }
        callError = nil
        Task {
            guard await requestMicPermission() else {
                callError = "mic_denied"
                return
            }
            guard let pc = makePeerConnection() else {
                callError = "failed"
                return
            }
            configureAudioSession()
            activeConversationId = conversationId
            peerConnection = pc
            addLocalAudioTrack(to: pc)

            pc.offer(for: Self.offerAnswerConstraints) { [weak self] sdp, _ in
                guard let self, let sdp else { return }
                pc.setLocalDescription(sdp) { _ in
                    Task { @MainActor in
                        guard self.activeConversationId == conversationId else { return }
                        self.socketManager.emitCallOffer(conversationId: conversationId, sdpType: sdp.type == .offer ? "offer" : "answer", sdp: sdp.sdp)
                        self.state = .outgoing
                    }
                }
            }
        }
    }

    func acceptCall() {
        guard state == .incoming, let conversationId = activeConversationId, let offer = pendingOfferSdp else { return }
        callError = nil
        Task {
            guard await requestMicPermission() else {
                callError = "mic_denied"
                rejectCall()
                return
            }
            guard let pc = makePeerConnection() else {
                callError = "failed"
                return
            }
            configureAudioSession()
            peerConnection = pc
            addLocalAudioTrack(to: pc)

            pc.setRemoteDescription(offer) { [weak self] _ in
                guard let self else { return }
                pc.answer(for: Self.offerAnswerConstraints) { sdp, _ in
                    guard let sdp else { return }
                    pc.setLocalDescription(sdp) { _ in
                        Task { @MainActor in
                            guard self.activeConversationId == conversationId else { return }
                            self.socketManager.emitCallAnswer(conversationId: conversationId, sdpType: sdp.type == .offer ? "offer" : "answer", sdp: sdp.sdp)
                            self.incomingCallerName = nil
                            self.state = .active
                        }
                    }
                }
            }
        }
    }

    func rejectCall() {
        if let conversationId = activeConversationId {
            socketManager.emitCallEnd(conversationId: conversationId)
        }
        teardownCall()
    }

    func endCall() {
        if let conversationId = activeConversationId {
            socketManager.emitCallEnd(conversationId: conversationId)
        }
        teardownCall()
    }

    func toggleMute() {
        guard let localAudioTrack else { return }
        muted.toggle()
        localAudioTrack.isEnabled = !muted
    }

    // MARK: - Internals

    /// `RTCPeerConnectionFactory.peerConnection(with:constraints:delegate:)`
    /// is declared `nullable` in WebRTC's current Objective-C header (bridges
    /// to `RTCPeerConnection?` in Swift, not a plain `RTCPeerConnection`) —
    /// verified directly against webrtc.googlesource.com's current
    /// `RTCPeerConnectionFactory.h` rather than assumed non-optional from
    /// the (older) reference demo app, which likely predates this header
    /// picking up `nullable`.
    private func makePeerConnection() -> RTCPeerConnection? {
        let config = RTCConfiguration()
        config.iceServers = Self.iceServers
        config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        return Self.factory.peerConnection(with: config, constraints: constraints, delegate: self)
    }

    private func addLocalAudioTrack(to pc: RTCPeerConnection) {
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = Self.factory.audioSource(with: audioConstraints)
        let track = Self.factory.audioTrack(with: audioSource, trackId: "audio0")
        localAudioTrack = track
        pc.add(track, streamIds: ["stream0"])
    }

    /// Uses WebRTC's own `RTCAudioSession` wrapper (lock/configure/unlock),
    /// not a raw `AVAudioSession` call, since WebRTC manages this session
    /// internally and expects callers to go through its lock rather than
    /// fighting its own audio routing. **Not** the reference demo's exact
    /// single-argument `setCategory(_:)` call — that 2-parameter
    /// `setCategory:error:` overload no longer exists in WebRTC's current
    /// `RTCAudioSession.h` (verified directly against
    /// webrtc.googlesource.com's current header, which only declares
    /// `setCategory:mode:options:error:` and `setCategory:withOptions:error:`
    /// now) — the demo app predates that header change. Both parameters take
    /// the `AVAudioSession.Category`/`.Mode` value itself, not `.rawValue`
    /// (a first attempt passed `.rawValue`, i.e. a `String`, which doesn't
    /// match either overload's expected enum-typed parameter). The Swift
    /// argument label for the options parameter is `with:`, not
    /// `withOptions:` — Swift renamed it from the ObjC-derived
    /// `setCategory(_:withOptions:)` to `setCategory(_:with:)` (the older
    /// spelling is `obsoleted in Swift 3` per the compiler's own note).
    private func configureAudioSession() {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord, with: [])
            try session.setMode(AVAudioSession.Mode.voiceChat)
            try session.setActive(true)
        } catch {
            // Non-fatal — the call can still proceed with default routing.
        }
    }

    /// Plain `AVAudioSession` (not `RTCAudioSession`) for the permission
    /// prompt itself — WebRTC's wrapper has no permission API of its own,
    /// this is purely an OS-level mic-access question, same as Web's
    /// `navigator.mediaDevices.getUserMedia({audio: true})` try/catch.
    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func teardownCall() {
        peerConnection?.close()
        peerConnection = nil
        localAudioTrack = nil
        pendingOfferSdp = nil
        activeConversationId = nil
        incomingCallerName = nil
        muted = false
        callError = nil
        state = .idle
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        try? session.setActive(false)
        session.unlockForConfiguration()
    }
}

// MARK: - RTCPeerConnectionDelegate
//
// All 9 methods below are non-optional protocol requirements (verified
// against stasel/WebRTC-iOS's own `WebRTCClient` conformance) — implemented
// as `nonisolated` no-ops except the two this feature actually needs
// (ICE candidate discovery, connection-failure teardown), each hopping to
// the main actor via `Task { @MainActor in ... }` before touching any
// `@Published`/actor-isolated state, mirroring the exact pattern
// `ChatSocketManager`'s own Socket.IO callbacks already use in this
// codebase (those also fire on a background queue, not the main thread).
extension CallManager: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        // Audio-only: WebRTC's own audio pipeline plays a received audio
        // track automatically through the active RTCAudioSession once the
        // connection is up — no manual renderer attachment needed here
        // (unlike video, which would need an RTCVideoRenderer).
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}

    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        if newState == .failed || newState == .disconnected {
            Task { @MainActor in
                self.teardownCall()
            }
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let sdp = candidate.sdp
        let sdpMid = candidate.sdpMid
        let sdpMLineIndex = candidate.sdpMLineIndex
        Task { @MainActor in
            guard let conversationId = self.activeConversationId else { return }
            self.socketManager.emitCallIceCandidate(conversationId: conversationId, candidate: sdp, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex)
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
