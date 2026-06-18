import AVFoundation
import UIKit

enum CameraError: LocalizedError {
    case notReady, captureFailed

    var errorDescription: String? {
        switch self {
        case .notReady:      return "카메라가 아직 준비되지 않았어요."
        case .captureFailed: return "촬영에 실패했어요. 다시 시도해주세요."
        }
    }
}

/// 후면/전면 정지 촬영 래퍼.
/// - 권한 확인 → 세션 구성(입력+출력 원자적) → 시작/정지 → 촬영.
/// - 구성은 메인에서 동기로(프리뷰 표시 안정), 시작·정지·촬영은 전용 큐에서.
/// - 상태(`status`)는 항상 메인에서 발행.
@MainActor
final class CameraController: NSObject, ObservableObject {
    enum Status: Equatable { case idle, configuring, ready, denied, failed }

    @Published private(set) var status: Status = .idle
    @Published private(set) var position: AVCaptureDevice.Position = .back

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "catch.camera.session")

    private var isConfigured = false
    private var shouldRun = false               // 켜져 있어야 하는지(구성 완료 전 start 요청 대비)
    private var activeCapture: PhotoCaptureDelegate?  // 캡처 진행 중 델리게이트 강한 보유

    override init() {
        super.init()
        // 권한이 이미 있으면 즉시 동기 구성(프리뷰가 곧바로 뜨도록).
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { configureIfNeeded() }
    }

    // MARK: - 권한 + 구성

    /// 카메라 진입 전 호출: 권한 확인 후 세션을 구성한다(세션 시작은 별도).
    func prepare() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            status = .configuring
            guard await AVCaptureDevice.requestAccess(for: .video) else { status = .denied; return }
        default:
            status = .denied
            return
        }
        configureIfNeeded()
    }

    /// 메인에서 동기 구성(이게 표시에 안정적). 입력·출력 모두 성공해야 .ready.
    private func configureIfNeeded() {
        guard !isConfigured else { status = .ready; return }
        status = .configuring
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let input = makeInput(for: position),
              session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            status = .failed
            Log.camera.error("session configure failed")
            return
        }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()

        isConfigured = true
        status = .ready
        if shouldRun { startSession() }   // 구성 전 들어온 start 요청 처리(레이스 방지)
    }

    private func makeInput(for position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return nil }
        return input
    }

    // MARK: - 실행 제어

    func startSession() {
        shouldRun = true
        guard isConfigured else { return }      // 구성되면 configureIfNeeded가 다시 시작
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stopSession() {
        shouldRun = false
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// 전/후면 전환.
    func flip() {
        guard isConfigured else { return }
        position = (position == .back) ? .front : .back
        let newPosition = position
        sessionQueue.async { [session, weak self] in
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            if let input = self?.makeInput(for: newPosition), session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()
        }
    }

    // MARK: - 촬영

    func capturePhoto() async throws -> UIImage {
        guard status == .ready else { throw CameraError.notReady }
        return try await withCheckedThrowingContinuation { continuation in
            // 캡처 1건 전용 델리게이트 — 완료까지 컨트롤러가 강하게 보유해 콜백 유실을 막는다.
            let delegate = PhotoCaptureDelegate { [weak self] result in
                Task { @MainActor in self?.activeCapture = nil }
                continuation.resume(with: result)
            }
            self.activeCapture = delegate
            sessionQueue.async { [output, session] in
                guard session.isRunning else {
                    // 세션이 안 켜졌으면 무한 대기 대신 명확히 실패.
                    Task { @MainActor in self.activeCapture = nil }
                    continuation.resume(throwing: CameraError.notReady)
                    return
                }
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
            }
        }
    }
}

/// 캡처 1건 전용 델리게이트. 완료 시 결과를 한 번만 전달한다.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<UIImage, Error>) -> Void

    init(completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            completion(.failure(error))
        } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            completion(.success(image))
        } else {
            completion(.failure(CameraError.captureFailed))
        }
    }
}
