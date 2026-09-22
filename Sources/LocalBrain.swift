import Foundation
import Darwin

final class LocalBrain: @unchecked Sendable {
    private let queue = DispatchQueue(label: "tuantuan.laya")
    private var child: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private let lock = NSLock()
    private var stopped = false
    func stop() {
        lock.lock(); stopped = true; let p = child; lock.unlock()
        if let p, p.isRunning { p.terminate() }
    }
    func decide(_ state: [String: Any], completion: @escaping @Sendable (Result<BrainReply, Error>) -> Void) {
        guard let payload = try? JSONSerialization.data(withJSONObject: state) else { return }
        queue.async { [self] in
            do {
                lock.lock(); let finished = stopped; lock.unlock()
                if finished { return }
                try start()
                guard let input, let output else { throw failure("本地模型尚未启动") }
                var line = payload; line.append(10); try input.write(contentsOf: line)
                var response = Data()
                let deadline = Date().addingTimeInterval(25)
                while Date() < deadline {
                    var fd = pollfd(fd: output.fileDescriptor, events: Int16(POLLIN), revents: 0)
                    if poll(&fd, 1, 250) <= 0 { continue }
                    guard let byte = try output.read(upToCount: 1), !byte.isEmpty else { throw failure("模型进程已退出") }
                    if byte.first == 10 {
                        let decoded = try JSONDecoder().decode(BrainReply.self, from: response)
                        completion(.success(decoded)); return
                    }
                    response.append(byte)
                    if response.count > 64_000 { throw failure("模型响应异常") }
                }
                throw failure("模型响应超时")
            } catch {
                if let child, child.isRunning { child.terminate() }
                input = nil; output = nil
                completion(.failure(error))
            }
        }
    }
    private func start() throws {
        if let child, child.isRunning { return }
        let root = Bundle.main.resourceURL!
        let p = Process()
        p.executableURL = root.appendingPathComponent("python/bin/python3")
        p.arguments = [root.appendingPathComponent("brain.py").path, root.appendingPathComponent("model").path]
        var env = ProcessInfo.processInfo.environment
        env["PYTHONHOME"] = root.appendingPathComponent("python").path
        env.removeValue(forKey: "PYTHONPATH")
        env["HF_HUB_OFFLINE"] = "1"; env["TOKENIZERS_PARALLELISM"] = "false"; env["PYTHONDONTWRITEBYTECODE"] = "1"
        p.environment = env
        let incoming = Pipe(), outgoing = Pipe()
        p.standardInput = incoming; p.standardOutput = outgoing; p.standardError = FileHandle.nullDevice
        lock.lock(); defer { lock.unlock() }
        if stopped { throw failure("应用已经退出") }
        try p.run(); child = p; input = incoming.fileHandleForWriting; output = outgoing.fileHandleForReading
    }
    private func failure(_ text: String) -> Error { NSError(domain: "Tuantuan", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
}
