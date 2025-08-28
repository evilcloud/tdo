import Foundation
import TDOCore
import TDOTerminal
#if os(macOS)
extension Notification.Name {
    static let tdoPin = Notification.Name("tdoPin")
    static let tdoUnpin = Notification.Name("tdoUnpin")
    static let tdoExit = Notification.Name("tdoExit")
    static let tdoReloadConfig = Notification.Name("tdoReloadConfig")
}
#endif

// Parse global flags: --file, --archive (best-effort; stripped from argv)
func splitGlobalFlags(_ args: [String]) -> (paths: (String?, String?), rest: [String]) {
    var filePath: String? = nil
    var archivePath: String? = nil
    var out: [String] = []
    var i = 0
    while i < args.count {
        let a = args[i]
        if a == "--file", i + 1 < args.count {
            filePath = args[i + 1]
            i += 2
            continue
        } else if a == "--archive", i + 1 < args.count {
            archivePath = args[i + 1]
            i += 2
            continue
        } else {
            out.append(a)
            i += 1
        }
    }
    return ((filePath, archivePath), out)
}

// Shared renderer configuration for both CLI commands and interactive shell
func makeRenderer() -> Renderer {
    Renderer(
        config: RenderConfig(
            colorize: nil,  // auto if TTY
            dimNotes: true,
            blankLineBeforeBlock: true,
            blankLineAfterBlock: true,
            groupFooSections: true,
            wrapWidth: nil,  // e.g. 100 to hard-wrap
            listTextWidth: 48  // align age column (set nil to disable)
        )
    )
}

func runShell(env initialEnv: Env) -> Int32 {
    var env = initialEnv
    let engine = Engine()
    let renderer = makeRenderer()

    if let tasks = try? engine.openTasks(env: env) {
        renderer.printBlock(renderer.renderOpenList(tasks))
    } else {
        renderer.printBlock(["error: could not load tasks"])
    }

    while true {
        fputs("> ", stdout)
        fflush(stdout)
        guard let line = readLine() else { break }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            if let tasks = try? engine.openTasks(env: env) {
                renderer.printBlock(renderer.renderOpenList(tasks))
            } else {
                renderer.printBlock(["error: could not load tasks"])
            }
            continue
        }

        let lower = trimmed.lowercased()
        if lower == "exit" || lower == "quit" {
#if os(macOS)
            DistributedNotificationCenter.default().post(name: .tdoExit, object: nil)
#endif
            break
        }

        let argv = trimmed.split(separator: " ").map(String.init)
        do {
            let cmd = try Parser.parse(argv: argv)
            switch cmd {
            case .shell:
                continue
            case .list:
                let tasks = try engine.openTasks(env: env)
                renderer.printBlock(renderer.renderOpenList(tasks))
            case .pin:
#if os(macOS)
                DistributedNotificationCenter.default().post(name: .tdoPin, object: nil)
#endif
                break
            case .unpin:
#if os(macOS)
                DistributedNotificationCenter.default().post(name: .tdoUnpin, object: nil)
#endif
                break
            case .exit:
#if os(macOS)
                DistributedNotificationCenter.default().post(name: .tdoExit, object: nil)
#endif
                break
            case .configShow:
                if let text = try? String(contentsOf: env.configURL, encoding: .utf8) {
                    renderer.printBlock(text.split(separator: "\n").map(String.init))
                }
                continue
            case .configOpen:
                Config.openEditor(env.configURL)
                continue
            case .configTransparency(let v):
                var cfg = env.config
                cfg.transparency = v
                try? cfg.save(to: env.configURL)
                if let newEnv = try? env.reloading() { env = newEnv }
#if os(macOS)
                DistributedNotificationCenter.default().post(name: .tdoReloadConfig, object: nil)
#endif
                renderer.printBlock(["set transparency to \(v)"])
                continue
            case .configPin(let on):
                var cfg = env.config
                cfg.pin = on
                try? cfg.save(to: env.configURL)
                if let newEnv = try? env.reloading() { env = newEnv }
#if os(macOS)
                DistributedNotificationCenter.default().post(name: .tdoReloadConfig, object: nil)
#endif
                renderer.printBlock(["default pin \(on ? "on" : "off")"])
                continue
            default:
                let (lines, mutated, _) = engine.execute(cmd, env: env)
                renderer.printBlock(lines)
                if mutated {
                    let tasks = try engine.openTasks(env: env)
                    renderer.printBlock(renderer.renderOpenList(tasks))
                }
            }
        } catch {
            renderer.printBlock(["error: \(error)"])
        }
    }
    return ExitCode.ok.rawValue
}

func runEntry() -> Int32 {
    var args = CommandLine.arguments
    args.removeFirst()

    let (paths, rest) = splitGlobalFlags(args)

    let env: Env
    do { env = try Env(activePath: paths.0, archivePath: paths.1) } catch {
        fputs("error: \(error)\n", stderr)
        return ExitCode.ioError.rawValue
    }

    // Default to listing tasks when no command is provided
    let argv = rest.isEmpty ? ["list"] : rest

    do {
        let cmd = try Parser.parse(argv: argv)
        let engine = Engine()
        let renderer = makeRenderer()

        switch cmd {
        case .shell:
            return runShell(env: env)

        case .list:
            let tasks = try engine.openTasks(env: env)
            renderer.printBlock(renderer.renderOpenList(tasks))
            return ExitCode.ok.rawValue

        case .pin:
#if os(macOS)
            DistributedNotificationCenter.default().post(name: .tdoPin, object: nil)
#else
            renderer.printBlock(["pin is only available on macOS"])
#endif
            return ExitCode.ok.rawValue

        case .unpin:
#if os(macOS)
            DistributedNotificationCenter.default().post(name: .tdoUnpin, object: nil)
#else
            renderer.printBlock(["unpin is only available on macOS"])
#endif
            return ExitCode.ok.rawValue

        case .exit:
#if os(macOS)
            DistributedNotificationCenter.default().post(name: .tdoExit, object: nil)
#else
            renderer.printBlock(["exit is only available on macOS"])
#endif
            return ExitCode.ok.rawValue
        case .configShow:
            if let text = try? String(contentsOf: env.configURL, encoding: .utf8) {
                renderer.printBlock(text.split(separator: "\n").map(String.init))
            }
            return ExitCode.ok.rawValue
        case .configOpen:
            Config.openEditor(env.configURL)
            return ExitCode.ok.rawValue
        case .configTransparency(let v):
            var cfg = env.config
            cfg.transparency = v
            try? cfg.save(to: env.configURL)
#if os(macOS)
            DistributedNotificationCenter.default().post(name: .tdoReloadConfig, object: nil)
#endif
            renderer.printBlock(["set transparency to \(v)"])
            return ExitCode.ok.rawValue
        case .configPin(let on):
            var cfg = env.config
            cfg.pin = on
            try? cfg.save(to: env.configURL)
#if os(macOS)
            DistributedNotificationCenter.default().post(name: .tdoReloadConfig, object: nil)
#endif
            renderer.printBlock(["default pin \(on ? "on" : "off")"])
            return ExitCode.ok.rawValue

        case .do_, .find, .foo, .act, .undo, .show:
            let (lines, mutated, code) = engine.execute(cmd, env: env)
            renderer.printBlock(lines)
            if mutated {
                let tasks = try engine.openTasks(env: env)
                renderer.printBlock(renderer.renderOpenList(tasks))
            }
            return code.rawValue
        }
    } catch {
        let renderer = makeRenderer()
        renderer.printBlock(["error: \(error)"])
        return ExitCode.userError.rawValue
    }
}

// Entry
exit(runEntry())
