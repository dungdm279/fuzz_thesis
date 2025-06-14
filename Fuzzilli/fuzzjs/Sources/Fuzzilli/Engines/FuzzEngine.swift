// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import NIO
import RediStack


//let redis = try! RedisConnection.make(
//        configuration: try .init(hostname: "127.0.0.1", port: 9067),
//        boundEventLoop: MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
//    ).wait()


public protocol FuzzEngine: ComponentBase {
    // Performs a single round of fuzzing using the engine.
    func fuzzOne(_ group: DispatchGroup)
}

extension FuzzEngine {
    public func execute(_ program: Program) -> ExecutionOutcome {
        dispatchPrecondition(condition: .onQueue(fuzzer.getQueue()))
        fuzzer.dispatchEvent(fuzzer.events.ProgramGenerated, data: program)

        let execution = fuzzer.execute(program)

        switch execution.outcome {
            case .crashed(let termsig):
                fuzzer.processCrash(program, withSignal: termsig, withStderr: execution.stderr, withStdout: execution.stdout, origin: .local, withExectime: execution.execTime)
                program.contributors.generatedCrashingSample()

            case .succeeded:
                fuzzer.dispatchEvent(fuzzer.events.ValidProgramFound, data: program)
                
            
                
                //let script = fuzzer.lifter.lift(program)
                //let result = try! redis.send(RedisCommand.init(keyword: "LLEN", arguments: [RESPValue.init(from: "dt_queue")], mapValueToResult: { $0 })).wait()
                //if (result.int!) < 10000 {
                //    try! redis.send(RedisCommand.init(keyword: "LPUSH", arguments: [RESPValue.init(from: "dt_queue"), RESPValue.init(from: script.data(using: String.Encoding.utf8))], mapValueToResult: { _ in })).wait()
                //}
                
                
                /*
                fuzzer.dispatchEvent(fuzzer.events.myPreExecute, data: program)
                let result2 = fuzzer.execute(program)
                fuzzer.dispatchEvent(fuzzer.events.myPostExecute, data: program)
                */
            
                var isInteresting = false
                if let aspects = fuzzer.evaluator.evaluate(execution, program) {
                    if fuzzer.config.enableInspection {
                        program.comments.add("Program may be interesting due to \(aspects)", at: .footer)
                    }
                    isInteresting = fuzzer.processMaybeInteresting(program, havingAspects: aspects, origin: .local)
                }

                if isInteresting {
                    program.contributors.generatedInterestingSample()
                } else {
                    program.contributors.generatedValidSample()
                }

            case .failed(_):
                if fuzzer.config.enableDiagnostics {
                    program.comments.add("Stdout:\n" + execution.stdout, at: .footer)
                }
                fuzzer.dispatchEvent(fuzzer.events.InvalidProgramFound, data: program)
                program.contributors.generatedInvalidSample()

            case .timedOut:
                fuzzer.dispatchEvent(fuzzer.events.TimeOutFound, data: program)
                program.contributors.generatedTimeOutSample()
        }

        if fuzzer.config.enableDiagnostics {
            // Ensure deterministic execution behaviour. This can for example help detect and debug REPRL issues.
            ensureDeterministicExecutionOutcomeForDiagnostic(of: program)
        }

        return execution.outcome
    }

    private func ensureDeterministicExecutionOutcomeForDiagnostic(of program: Program) {
        let execution1 = fuzzer.execute(program)
        let stdout1 = execution1.stdout, stderr1 = execution1.stderr
        let execution2 = fuzzer.execute(program)
        switch (execution1.outcome, execution2.outcome) {
        case (.succeeded, .failed(_)),
             (.failed(_), .succeeded):
            let stdout2 = execution2.stdout, stderr2 = execution2.stderr
            logger.warning("""
                Non-deterministic execution detected for program
                \(fuzzer.lifter.lift(program))
                // Stdout of first execution
                \(stdout1)
                // Stderr of first execution
                \(stderr1)
                // Stdout of second execution
                \(stdout2)
                // Stderr of second execution
                \(stderr2)
                """)
        default:
            break
        }
    }
}
