import Foundation
import TDOCore
import TDOTerminal

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

func runShell(env: Env) -> Int32 {
    let engine = Engine()
    let renderer = makeRenderer()

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
        if lower == "exit" || lower == "quit" { break }

        let argv = trimmed.split(separator: " ").map(String.init)
        do {
            let cmd = try Parser.parse(argv: argv)
            switch cmd {
            case .shell:
                continue
            case .list:
                let tasks = try engine.openTasks(env: env)
                renderer.printBlock(renderer.renderOpenList(tasks))
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

    let (paths, restRaw) = splitGlobalFlags(args)
    let rest = restRaw.isEmpty ? ["shell"] : restRaw

    let env: Env
    do { env = try Env(activePath: paths.0, archivePath: paths.1) } catch {
        fputs("error: \(error)\n", stderr)
        return ExitCode.ioError.rawValue
    }

    do {
        let cmd = try Parser.parse(argv: rest)
        let engine = Engine()
        let renderer = makeRenderer()

        switch cmd {
        case .shell:
            return runShell(env: env)

        case .list:
            let tasks = try engine.openTasks(env: env)
            renderer.printBlock(renderer.renderOpenList(tasks))
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
