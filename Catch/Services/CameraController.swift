import AVFoundation
import UIKit

enum CameraError: Error { case captureFailed }

/// 후면 카메라 정지 촬영 래퍼.
@MainActor
final class CameraController: NSObject, ObservableObject {
    enum Status { case unknown, configuring, ready, denied, failed }

    @Published var status: Status = .unknown

    /// 디버그용 현재 권한(0=미정,1=제한,2=거부,3=허용).
    var authRaw: Int { AVCaptureDevice.authorizationStatus(for: .video).rawValue }

    @Published var position: AVCaptureDevice.Position = .back

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "catch.camera.session")
    private var captureContinuation: CheckedContinuation<UIImage, Error>?

    override init() {
        super.init()
        start()   // 생성 즉시 권한 확인 + 입력 구성(뷰 라이프사이클에 의존 안 함)
    }

    /// 전/후면 전환.
    func flip() async {
        position = position == .back ? .front : .back
        await reconfigureInput()
    }

    private func reconfigureInput() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                self.session.beginConfiguration()
                for input in self.session.inputs { self.session.removeInput(input) }
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.position),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                self.session.commitConfiguration()
                cont.resume()
            }
        }
    }

    /// 앱 진입 시 권한 팝업만 띄운다(세션 시작은 안 함).
    func ensurePermission() async {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
    }

    /// 권한 상태에 따라 분기 후 세션 구성.
    func requestAccessAndConfigure() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await configure()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { await configure() } else { status = .denied }
        default:
            status = .denied
        }
    }

    private func configure() async {
        // 이미 구성됐다면(중복 호출) 다시 추가하지 않고 바로 시작.
        if !session.inputs.isEmpty {
            startSession()
            status = .ready
            return
        }
        status = .configuring
        // 세션 구성 성공 여부를 동기적으로 받아온다(상태 레이스 방지).
        let success = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            sessionQueue.async {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                // 중복 추가 방지: 기존 입력/출력 정리 후 재구성.
                for input in self.session.inputs { self.session.removeInput(input) }
                for output in self.session.outputs { self.session.removeOutput(output) }

                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.position),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    cont.resume(returning: false); return
                }
                self.session.addInput(input)

                guard self.session.canAddOutput(self.photoOutput) else {
                    self.session.commitConfiguration()
                    cont.resume(returning: false); return
                }
                self.session.addOutput(self.photoOutput)
                self.session.commitConfiguration()
                cont.resume(returning: true)
            }
        }
        if success {
            startSession()
            status = .ready
        } else {
            status = .failed
        }
    }

    private var wantsRunning = false

    func startSession() {
        wantsRunning = true
        let session = self.session
        sessionQueue.async {
            if !session.inputs.isEmpty, !session.isRunning { session.startRunning() }
        }
    }

    func stopSession() {
        wantsRunning = false
        let session = self.session
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: - 견고한 시작(완료 핸들러 기반 — Task 취소/서스펜션 영향 없음)

    /// 진입 시 1회 호출. 권한 확인 후 입력만 구성(세션 시작은 startSession이 담당).
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureInputs()
        case .notDetermined:
            status = .configuring
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureInputs() } else { self?.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    /// 입력/출력 구성 — 메인에서 동기적으로(큐 데드락 회피). startRunning만 백그라운드.
    private func configureInputs() {
        if !session.inputs.isEmpty { status = .ready; if wantsRunning { startSession() }; return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            session.commitConfiguration()
            status = .ready
            if wantsRunning { startSession() }
        } else {
            session.commitConfiguration()
            status = .failed
        }
    }

    /// 메인 뷰로 나갈 때 — 세션 정지 + 상태 리셋(재진입 시 매번 검정→페이드).
    func deactivate() {
        stopSession()
        status = .unknown
    }

    func capturePhoto() async throws -> UIImage {
        // 직전 촬영이 아직 진행 중이면 중복 호출을 거부(continuation 덮어쓰기/누수 방지).
        guard captureContinuation == nil else { throw CameraError.captureFailed }
        let settings = AVCapturePhotoSettings()
        return try await withCheckedThrowingContinuation { cont in
            self.captureContinuation = cont
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        let result: Result<UIImage, Error>
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            result = .success(image)
        } else {
            result = .failure(CameraError.captureFailed)
        }
        Task { @MainActor in
            switch result {
            case .success(let image): self.captureContinuation?.resume(returning: image)
            case .failure(let err): self.captureContinuation?.resume(throwing: err)
            }
            self.captureContinuation = nil
        }
    }
}
