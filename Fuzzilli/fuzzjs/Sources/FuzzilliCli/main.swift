// Copyright 2019 Google LLC
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
import Fuzzilli

//
// Process commandline arguments.
//
let args = Arguments.parse(from: CommandLine.arguments)

if args["-h"] != nil || args["--help"] != nil || args.numPositionalArguments != 1 {
    print("""
Usage:
\(args.programName) [options] --profile=<profile> /path/to/jsshell

Options:
    --profile=name               : Select one of several preconfigured profiles.
                                   Available profiles: \(profiles.keys).
    --jobs=n                     : Total number of fuzzing jobs. This will start one master thread and n-1 worker threads.
    --engine=name                : The fuzzing engine to use. Available engines: "mutation" (default), "hybrid", "multi".
                                   Only the mutation engine should be regarded stable at this point.
    --corpus=name                : The corpus scheduler to use. Available schedulers: "basic" (default), "markov"
    --logLevel=level             : The log level to use. Valid values: "verbose", info", "warning", "error", "fatal" (default: "info").
    --numIterations=n            : Run for the specified number of iterations (default: unlimited).
    --timeout=n                  : Timeout in ms after which to interrupt execution of programs (default depends on the profile).
    --minMutationsPerSample=n    : Discard samples from the corpus only after they have been mutated at least this many times (default: 25).
    --minCorpusSize=n            : Keep at least this many samples in the corpus regardless of the number of times
                                   they have been mutated (default: 1000).
    --maxCorpusSize=n            : Only allow the corpus to grow to this many samples. Otherwise the oldest samples
                                   will be discarded (default: unlimited).
    --markovDropoutRate=p        : Rate at which low edge samples are not selected, in the Markov Corpus Scheduler,
                                   per round of sample selection. Used to ensure diversity between fuzzer instances
                                   (default: 0.10)
    --consecutiveMutations=n     : Perform this many consecutive mutations on each sample (default: 5).
    --minimizationLimit=p        : When minimizing interesting programs, keep at least this percentage of the original instructions
                                   regardless of whether they are needed to trigger the interesting behaviour or not.
                                   See Minimizer.swift for an overview of this feature (default: 0.0).
    --storagePath=path           : Path at which to store output files (crashes, corpus, etc.) to.
    --resume                     : If storage path exists, import the programs from the corpus/ subdirectory
    --overwrite                  : If storage path exists, delete all data in it and start a fresh fuzzing session
    --exportStatistics           : If enabled, fuzzing statistics will be collected and saved to disk in regular intervals.
                                   Requires --storagePath.
    --statisticsExportInterval=n : Interval in minutes for saving fuzzing statistics to disk (default: 10).
                                   Requires --exportStatistics.
    --importCorpusAll=path       : Imports a corpus of protobufs to start the initial fuzzing corpus.
                                   All provided programs are included, even if they do not increase coverage.
                                   This is useful for searching for variants of existing bugs.
                                   Can be used alongside with importCorpusNewCov, and will run first
    --importCorpusNewCov=path    : Imports a corpus of protobufs to start the initial fuzzing corpus.
                                   This only includes programs that increase coverage.
                                   This is useful for jump starting coverage for a wide range of JavaScript samples.
                                   Can be used alongside importCorpusAll, and will run second.
                                   Since all imported samples are asynchronously minimized, the corpus will show a smaller
                                   than expected size until minimization completes.
    --importCorpusMerge=path     : Imports a corpus of protobufs to start the initial fuzzing corpus.
                                   This only keeps programs that increase coverage but does not attempt to minimize
                                   the samples. This is mostly useful to merge existing corpora from previous fuzzing
                                   sessions that will have redundant samples but which will already be minimized.
    --instanceType=type          : Specified the instance type for distributed fuzzing. Possible values:
                                                     master: Accept connections from workers over the network.
                                                     worker: Connect to a master instance and synchronize with it.
                                               intermediate: Run as both network master and worker.
                                       standalone (default): Don't participate in distributed fuzzing.
                                   Note: it is *highly* recommended to run distributed fuzzing in an isolated network!
    --bindTo=host:port           : When running as network master, bind to this address (default: 127.0.0.1:1337).
    --connectTo=host:port        : When running as network worker, connect to the master instance at this address (default: 127.0.0.1:1337).
    --corpusSyncMode=mode        : How the corpus is synchronized during distributed fuzzing. Possible values:
                                                  up: newly discovered corpus samples are only sent to master instances but
                                                      not to workers. This way, the workers are forced to generate their own
                                                      corpus, which may lead to more diverse samples overall. However, master
                                                      instances will still have the full XYZ
                                                down: newly discovered corpus samples are only sent to worker instances but
                                                      not to masters. This may make sense when importing a corpus in the master
                                      full (default): newly discovered corpus samples are sent in both direction. This is the
                                                      default behaviour and will generally cause all instances in the network
                                                      to have very roughly the same corpus.
                                               none : corpus samples are not shared with any other instances in the network.
                                   Note: thread workers (--jobs=X) always synchronize their corpus.
    --dontFuzz                   : If used, this instace will not perform fuzzing. Can be useful for master instances.
    --diagnostics                : Enable saving of programs that failed or timed-out during execution. Also tracks
                                   executions on the current REPRL instance.
    --swarmTesting               : Enable Swarm Testing mode. The fuzzer will choose random weights for the code generators per process.
    --inspect                    : Enable inspection for generated programs. When enabled, additional .fuzzil.history files are written
                                   to disk for every interesting or crashing program. These describe in detail how the program was generated
                                   through mutations, code generation, and minimization.
    --argumentRandomization      : Enable JS engine argument randomization
""")
    exit(0)
}

// Helper function that prints out an error message, then exits the process.
func configError(_ msg: String) -> Never {
    print(msg)
    exit(-1)
}

let jsShellPath = args[0]

if !FileManager.default.fileExists(atPath: jsShellPath) {
    configError("Invalid JS shell path \"\(jsShellPath)\", file does not exist")
}

var profile: Profile! = nil
if let val = args["--profile"], let p = profiles[val] {
    profile = p
}
if profile == nil {
    configError("Please provide a valid profile with --profile=profile_name. Available profiles: \(profiles.keys)")
}

let numJobs = args.int(for: "--jobs") ?? 1
let logLevelName = args["--logLevel"] ?? "info"
let engineName = args["--engine"] ?? "mutation"
let corpusName = args["--corpus"] ?? "basic"
let numIterations = args.int(for: "--numIterations") ?? -1
let timeout = args.int(for: "--timeout") ?? profile.timeout
let minMutationsPerSample = args.int(for: "--minMutationsPerSample") ?? 25
let minCorpusSize = args.int(for: "--minCorpusSize") ?? 1000
let maxCorpusSize = args.int(for: "--maxCorpusSize") ?? Int.max
let markovDropoutRate = args.double(for: "--markovDropoutRate") ?? 0.10
let consecutiveMutations = args.int(for: "--consecutiveMutations") ?? 5
let minimizationLimit = args.double(for: "--minimizationLimit") ?? 0.0
let storagePath = args["--storagePath"]
var resume = args.has("--resume")
let overwrite = args.has("--overwrite")
let exportStatistics = args.has("--exportStatistics")
let statisticsExportInterval = args.uint(for: "--statisticsExportInterval") ?? 10
let corpusImportAllPath = args["--importCorpusAll"]
let corpusImportCovOnlyPath = args["--importCorpusNewCov"]
let corpusImportMergePath = args["--importCorpusMerge"]
let instanceType = args["--instanceType"] ?? "standalone"
let corpusSyncMode = args["--corpusSyncMode"] ?? "full"
let dontFuzz = args.has("--dontFuzz")
let diagnostics = args.has("--diagnostics")
let inspect = args.has("--inspect")
let swarmTesting = args.has("--swarmTesting")
let randomizingArguments = args.has("--argumentRandomization")

guard numJobs >= 1 else {
    configError("Must have at least 1 job")
}

let logLevelByName: [String: LogLevel] = ["verbose": .verbose, "info": .info, "warning": .warning, "error": .error, "fatal": .fatal]
guard let logLevel = logLevelByName[logLevelName] else {
    configError("Invalid log level \(logLevelName)")
}

let validEngines = ["mutation", "hybrid", "multi"]
guard validEngines.contains(engineName) else {
    configError("--engine must be one of \(validEngines)")
}

let validCorpora = ["basic", "markov"]
guard validCorpora.contains(corpusName) else {
    configError("--corpus must be one of \(validCorpora)")
}

if corpusName != "markov" && args.double(for: "--markovDropoutRate") != nil {
    configError("The markovDropoutRate setting is only compatible with the markov corpus")
}

if markovDropoutRate < 0 || markovDropoutRate > 1 {
    print("The markovDropoutRate must be between 0 and 1")
}

if corpusName == "markov" && (args.int(for: "--maxCorpusSize") != nil || args.int(for: "--minCorpusSize") != nil
    || args.int(for: "--minMutationsPerSample") != nil ) {
    configError("--maxCorpusSize, --minCorpusSize, --minMutationsPerSample are not compatible with the Markov corpus")
}

if corpusImportAllPath != nil && corpusName == "markov" {
    // The markov corpus probably won't have edges associated with some samples, which will then never be mutated.
    configError("Markov corpus is not compatible with --importCorpusAll")
}

if (resume || overwrite) && storagePath == nil {
    configError("--resume and --overwrite require --storagePath")
}

if let path = storagePath {
    let directory = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    if !directory.isEmpty && !resume && !overwrite {
        configError("Storage path \(path) exists and is not empty. Please specify either --resume or --overwrite or delete the directory manually")
    }
}

if resume && overwrite {
    configError("Must only specify one of --resume and --overwrite")
}

if exportStatistics && storagePath == nil {
    configError("--exportStatistics requires --storagePath")
}

if statisticsExportInterval <= 0 {
    configError("statisticsExportInterval needs to be > 0")
}

if args.has("--statisticsExportInterval") && !exportStatistics  {
    configError("statisticsExportInterval requires --exportStatistics")
}

if minCorpusSize < 1 {
    configError("--minCorpusSize must be at least 1")
}

if maxCorpusSize < minCorpusSize {
    configError("--maxCorpusSize must be larger than --minCorpusSize")
}

if minimizationLimit < 0 || minimizationLimit > 1 {
    configError("--minimizationLimit must be between 0 and 1")
}

let validInstanceTypes = ["master", "worker", "intermediate", "standalone"]
guard validInstanceTypes.contains(instanceType) else {
    configError("--instanceType must be one of \(validInstanceTypes)")
}
var isNetworkMaster = instanceType == "master" || instanceType == "intermediate"
var isNetworkWorker = instanceType == "worker" || instanceType == "intermediate"

if args.has("--bindTo") && !isNetworkMaster {
    configError("--bindTo is only valid for master instances")
}
if args.has("--connectTo") && !isNetworkWorker {
    configError("--connectTo is only valid for worker instances")
}

func parseAddress(_ argName: String) -> (String, UInt16) {
    var result: (ip: String, port: UInt16) = ("127.0.0.1", 1337)
    if let address = args[argName] {
        if let parsedAddress = Arguments.parseHostPort(address) {
            result = parsedAddress
        } else {
            configError("Argument \(argName) must be of the form \"host:port\"")
        }
    }
    return result
}

var addressToBindTo: (ip: String, port: UInt16) = parseAddress("--bindTo")
var addressToConnectTo: (ip: String, port: UInt16) = parseAddress("--connectTo")

let corpusSyncModeByName: [String: NetworkCorpusSynchronizationMode] = ["up": .up, "down": .down, "full": .full, "none": .none]
guard let corpusSyncMode = corpusSyncModeByName[corpusSyncMode] else {
    configError("Invalid network corpus synchronization mode \(corpusSyncMode)")
}

// Make it easy to detect typos etc. in command line arguments
if args.unusedOptionals.count > 0 {
    configError("Invalid arguments: \(args.unusedOptionals)")
}

// Initialize the logger such that we can print to the screen.
let logger = Logger(withLabel: "Cli")

///
/// Chose the code generator weights.
///

if swarmTesting {
    logger.info("Choosing the following weights for Swarm Testing mode.")
    logger.info("Weight | CodeGenerator")
}

let disabledGenerators = Set(profile.disabledCodeGenerators)
let additionalCodeGenerators = profile.additionalCodeGenerators
let regularCodeGenerators: [(CodeGenerator, Int)] = CodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators1: [(CodeGenerator, Int)] = FixupCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators2: [(CodeGenerator, Int)] = TypeCheckHoistingCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators3: [(CodeGenerator, Int)] = StrengthReductionCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators4: [(CodeGenerator, Int)] = ConstantFoldingCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators5: [(CodeGenerator, Int)] = CFGSimplificationCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators6: [(CodeGenerator, Int)] = LocalCSECodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators7: [(CodeGenerator, Int)] = PhantomInsertionCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators8: [(CodeGenerator, Int)] = CriticalEdgeBreakingCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators9: [(CodeGenerator, Int)] = ArgumentsEliminationCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators10: [(CodeGenerator, Int)] = PutStackSinkingCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators11: [(CodeGenerator, Int)] = ConstantHoistingCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators12: [(CodeGenerator, Int)] = GlobalCSECodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators13: [(CodeGenerator, Int)] = ObjectAllocationSinkingCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators14: [(CodeGenerator, Int)] = ValueRepReductionCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators15: [(CodeGenerator, Int)] = LICMCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators16: [(CodeGenerator, Int)] = IntegerRangeOptimizationCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}
let regularCodeGenerators17: [(CodeGenerator, Int)] = IntegerCheckCombiningCodeGenerators.map {
    guard let weight = codeGeneratorWeights[$0.name] else {
        logger.fatal("Missing weight for code generator \($0.name) in CodeGeneratorWeights.swift")
    }
    return ($0, weight)
}

var codeGenerators: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators1: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators2: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators3: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators4: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators5: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators6: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators7: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators8: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators9: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators10: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators11: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators12: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators13: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators14: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators15: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators16: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])
var codeGenerators17: WeightedList<CodeGenerator> = WeightedList<CodeGenerator>([])

for (generator, var weight) in (additionalCodeGenerators + regularCodeGenerators) {
    if disabledGenerators.contains(generator.name) {
        continue
    }

    if swarmTesting {
        weight = Int.random(in: 1...30)
        logger.info(String(format: "%6d | \(generator.name)", weight))
    }

    codeGenerators.append(generator, withWeight: weight)
}

for (generator, _) in (additionalCodeGenerators + regularCodeGenerators1) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators1.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators2) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators2.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators3) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators3.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators4) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators4.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators5) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators5.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators6) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators6.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators7) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators7.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators8) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators8.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators9) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators9.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators10) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators10.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators11) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators11.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators12) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators12.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators13) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators13.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators14) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators14.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators15) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators15.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators16) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators16.append(generator, withWeight: Int(5))
}
for (generator, _) in (additionalCodeGenerators + regularCodeGenerators17) {
    if disabledGenerators.contains(generator.name) {
        continue
    }
    codeGenerators17.append(generator, withWeight: Int(5))
}

//
// Construct a fuzzer instance.
//

func makeFuzzer(for profile: Profile, with configuration: Configuration) -> Fuzzer {
    // A script runner to execute JavaScript code in an instrumented JS engine.
    let runner = REPRL(executable: jsShellPath, processArguments: profile.getProcessArguments(randomizingArguments), processEnvironment: profile.processEnv, maxExecsBeforeRespawn: profile.maxExecsBeforeRespawn)

    let engine: FuzzEngine
    switch engineName {
    case "hybrid":
        engine = HybridEngine(numConsecutiveMutations: consecutiveMutations)
    case "multi":
        let mutationEngine = MutationEngine(numConsecutiveMutations: consecutiveMutations)
        let hybridEngine = HybridEngine(numConsecutiveMutations: consecutiveMutations)
        let engines = WeightedList<FuzzEngine>([
            (mutationEngine, 1),
            (hybridEngine, 1),
        ])
        engine = MultiEngine(engines: engines, initialActive: hybridEngine, iterationsPerEngine: 1000)
    default:
        engine = MutationEngine(numConsecutiveMutations: consecutiveMutations)
    }

    // Program templates to use.
    var programTemplates = profile.additionalProgramTemplates
    for template in ProgramTemplates {
        guard let weight = programTemplateWeights[template.name] else {
            print("Missing weight for program template \(template.name) in ProgramTemplateWeights.swift")
            exit(-1)
        }

        programTemplates.append(template, withWeight: weight)
    }

    // The environment containing available builtins, property names, and method names.
    let environment = JavaScriptEnvironment(additionalBuiltins: profile.additionalBuiltins, additionalObjectGroups: [])

    // A lifter to translate FuzzIL programs to JavaScript.
    let lifter = JavaScriptLifter(prefix: profile.codePrefix,
                                  suffix: profile.codeSuffix,
                                  ecmaVersion: profile.ecmaVersion)

    // The evaluator to score produced samples.
    let evaluator = ProgramCoverageEvaluator(runner: runner)

    // Corpus managing interesting programs that have been found during fuzzing.
    let corpus: Corpus
    switch corpusName {
    case "basic":
        // Edit here
        corpus = MyMarkovCorpus(covEvaluator: evaluator as ProgramCoverageEvaluator, dropoutRate: markovDropoutRate)
       //corpus = BasicCorpus(minSize: minCorpusSize, maxSize: maxCorpusSize, minMutationsPerSample: minMutationsPerSample)
    case "markov":
        corpus = MarkovCorpus(covEvaluator: evaluator as ProgramCoverageEvaluator, dropoutRate: markovDropoutRate)
    default:
        logger.fatal("Invalid corpus name provided")
    }

    // Minimizer to minimize crashes and interesting programs.
    let minimizer = Minimizer()

    /// The mutation fuzzer responsible for mutating programs from the corpus and evaluating the outcome.
    let mutators = WeightedList([
        (ExplorationMutator(),              3),
        (CodeGenMutator(),                  2),
        (SpliceMutator(),                   2),
        //(ProbingMutator(),                  2),
        (InputMutator(isTypeAware: false),  2),
        (InputMutator(isTypeAware: true),   1),
        // Can be enabled for experimental use, ConcatMutator is a limited version of CombineMutator
        // (ConcatMutator(),                1),
        (OperationMutator(),                1),
        (CombineMutator(),                  1),
        (JITStressMutator(),                1),
    ])

    // Construct the fuzzer instance.
    return Fuzzer(configuration: config,
                  scriptRunner: runner,
                  engine: engine,
                  mutators: mutators,
                  codeGenerators: codeGenerators,
                  codeGenerators1: codeGenerators1,
                  codeGenerators2: codeGenerators2,
                  codeGenerators3: codeGenerators3,
                  codeGenerators4: codeGenerators4,
                  codeGenerators5: codeGenerators5,
                  codeGenerators6: codeGenerators6,
                  codeGenerators7: codeGenerators7,
                  codeGenerators8: codeGenerators8,
                  codeGenerators9: codeGenerators9,
                  codeGenerators10: codeGenerators10,
                  codeGenerators11: codeGenerators11,
                  codeGenerators12: codeGenerators12,
                  codeGenerators13: codeGenerators13,
                  codeGenerators14: codeGenerators14,
                  codeGenerators15: codeGenerators15,
                  codeGenerators16: codeGenerators16,
                  codeGenerators17: codeGenerators17,
                  programTemplates: programTemplates,
                  evaluator: evaluator,
                  environment: environment,
                  lifter: lifter,
                  corpus: corpus,
                  minimizer: minimizer)
}

// The configuration of this fuzzer.
let config = Configuration(timeout: UInt32(timeout),
                           logLevel: logLevel,
                           crashTests: profile.crashTests,
                           isFuzzing: !dontFuzz,
                           minimizationLimit: minimizationLimit,
                           enableDiagnostics: diagnostics,
                           enableInspection: inspect)

let fuzzer = makeFuzzer(for: profile, with: config)

// Create a "UI". We do this now, before fuzzer initialization, so
// we are able to print log messages generated during initialization.
let ui = TerminalUI(for: fuzzer)

// Remaining fuzzer initialization must happen on the fuzzer's dispatch queue.
fuzzer.sync {
    // Always want some statistics.
    fuzzer.addModule(Statistics())

    // Check core file generation on linux, prior to moving corpus file directories
    fuzzer.checkCoreFileGeneration()

    // Store samples to disk if requested.
    if let path = storagePath {
        if resume {
            // Move the old corpus to a new directory from which the files will be imported afterwards
            // before the directory is deleted.
            do {
                try FileManager.default.moveItem(atPath: path + "/corpus", toPath: path + "/old_corpus")
            } catch {
                logger.info("Nothing to resume from: \(path)/corpus does not exist")
                resume = false
            }
        } else if overwrite {
            logger.info("Deleting all files in \(path) due to --overwrite")
            try? FileManager.default.removeItem(atPath: path)
        } else {
            // The corpus directory must be empty. We already checked this above, so just assert here
            let directory = (try? FileManager.default.contentsOfDirectory(atPath: path + "/corpus")) ?? []
            assert(directory.isEmpty)
        }

        fuzzer.addModule(Storage(for: fuzzer,
                                 storageDir: path,
                                 statisticsExportInterval: exportStatistics ? Double(statisticsExportInterval) * Minutes : nil
        ))
    }

    // Synchronize over the network if requested.
    if isNetworkMaster {
        fuzzer.addModule(NetworkMaster(for: fuzzer, address: addressToBindTo.ip, port: addressToBindTo.port, corpusSynchronizationMode: corpusSyncMode))
    }
    if isNetworkWorker {
        fuzzer.addModule(NetworkWorker(for: fuzzer, hostname: addressToConnectTo.ip, port: addressToConnectTo.port, corpusSynchronizationMode: corpusSyncMode))
    }

    // Synchronize with thread workers if requested.
    if numJobs > 1 {
        fuzzer.addModule(ThreadMaster(for: fuzzer))
    }

    // Check for potential misconfiguration.
    if !isNetworkWorker && storagePath == nil {
        logger.warning("No filesystem storage configured, found crashes will be discarded!")
    }

    // Exit this process when the main fuzzer stops.
    fuzzer.registerEventListener(for: fuzzer.events.ShutdownComplete) { reason in
        exit(reason.toExitCode())
    }

    // Initialize the fuzzer, and run startup tests
    fuzzer.initialize()
    fuzzer.runStartupTests()
}

// Add thread worker instances if requested
//
// This happens here, before any corpus is imported, so that any imported programs are
// forwarded to the ThreadWorkers automatically when they are deemed interesting.
//
// This must *not* happen on the main fuzzer's queue since workers perform synchronous
// operations on the master's dispatch queue.
var instances = [fuzzer]
for _ in 1..<numJobs {
    let worker = makeFuzzer(for: profile, with: config)
    instances.append(worker)
    let g = DispatchGroup()

    g.enter()
    worker.sync {
        worker.addModule(Statistics())
        worker.addModule(ThreadWorker(forMaster: fuzzer))
        worker.registerEventListener(for: worker.events.Initialized) { g.leave() }
        worker.initialize()
    }

    // Wait for the worker to be fully initialized
    g.wait()
}

// Import a corpus if requested and start the main fuzzer instance.
fuzzer.sync {
    func loadCorpus(from dirPath: String) -> [Program] {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: dirPath, isDirectory:&isDir) || !isDir.boolValue {
            logger.fatal("Cannot import programs from \(dirPath), it is not a directory!")
        }

        var programs = [Program]()
        let fileEnumerator = FileManager.default.enumerator(atPath: dirPath)
        while let filename = fileEnumerator?.nextObject() as? String {
            guard filename.hasSuffix(".fuzzil.protobuf") else { continue }
            let path = dirPath + "/" + filename
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let pb = try Fuzzilli_Protobuf_Program(serializedData: data)
                let program = try Program.init(from: pb)
                programs.append(program)
            } catch {
                logger.error("Failed to load program \(path): \(error). Skipping")
            }
        }

        return programs
    }

    // Resume a previous fuzzing session if requested
    if resume, let path = storagePath {
        logger.info("Resuming previous fuzzing session. Importing programs from corpus directory now. This may take some time")
        let corpus = loadCorpus(from: path + "/old_corpus")

        // Delete the old corpus directory now
        try? FileManager.default.removeItem(atPath: path + "/old_corpus")

        fuzzer.importCorpus(corpus, importMode: .interestingOnly(shouldMinimize: false))  // We assume that the programs are already minimized
        logger.info("Successfully resumed previous state. Corpus now contains \(fuzzer.corpus.size) elements")
    }

    // Import a full corpus if requested
    if let path = corpusImportAllPath {
        let corpus = loadCorpus(from: path)
        logger.info("Starting All-corpus import of \(corpus.count) programs. This may take some time")
        fuzzer.importCorpus(corpus, importMode: .all)
        logger.info("Successfully imported \(path). Corpus now contains \(fuzzer.corpus.size) elements")
    }

    // Import a coverage-only corpus if requested
    if let path = corpusImportCovOnlyPath {
        var corpus = loadCorpus(from: path)
        // Sorting the corpus helps avoid minimizing large programs that produce new coverage due to small snippets also included by other, smaller samples
        corpus.sort(by: { $0.size < $1.size })
        logger.info("Starting Cov-only corpus import of \(corpus.count) programs. This may take some time")
        fuzzer.importCorpus(corpus, importMode: .interestingOnly(shouldMinimize: true))
        logger.info("Successfully imported \(path). Samples will be added to the corpus once they are minimized")
    }

    // Import and merge an existing corpus if requested
    if let path = corpusImportMergePath {
        let corpus = loadCorpus(from: path)
        logger.info("Starting corpus merge of \(corpus.count) programs. This may take some time")
        fuzzer.importCorpus(corpus, importMode: .interestingOnly(shouldMinimize: false))
        logger.info("Successfully imported \(path). Corpus now contains \(fuzzer.corpus.size) elements")
    }
}

// Install signal handlers to terminate the fuzzer gracefully.
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM] {
    // Seems like we need this so the dispatch sources work correctly?
    signal(sig, SIG_IGN)

    let source = DispatchSource.makeSignalSource(signal: sig, queue: DispatchQueue.main)
    source.setEventHandler {
        fuzzer.async {
            fuzzer.shutdown(reason: .userInitiated)
        }
    }
    source.activate()
    signalSources.append(source)
}

// Finally, start fuzzing.
for fuzzer in instances {
    fuzzer.sync {
        fuzzer.start(runFor: numIterations)
    }
}

// Start dispatching tasks on the main queue.
RunLoop.main.run()
