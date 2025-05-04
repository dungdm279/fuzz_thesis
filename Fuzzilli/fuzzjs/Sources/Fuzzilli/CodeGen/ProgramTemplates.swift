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


/// Builtin program templates to target specific types of bugs.
public let ProgramTemplates = [
    ProgramTemplate("B3InferSwitches") { b in
        b.build(n: 10)
        let f = b.buildPlainFunction(with: .parameters(n: 0)) { args in
            b.build(n: 15)
            let first = b.randVar()
            let cond = b.compare(first, with: b.randVar(), using: .equal)
            let cond1 = b.compare(first, with: b.randVar(), using: .equal)
            let cond2 = b.compare(first, with: b.randVar(), using: .equal)
            let cond3 = b.compare(first, with: b.randVar(), using: .equal)
            b.buildIfElse(cond, ifBody: {
                b.build(n: 10)
            }, elseBody: {
                b.buildIfElse(cond1, ifBody: {
                    b.build(n: 10)
                }, elseBody: {
                    b.buildIfElse(cond2, ifBody: {
                        b.build(n: 10)
                    }, elseBody: {
                        b.buildIfElse(cond3, ifBody: {
                            b.build(n: 10)
                        }, elseBody: {
                            b.build(n: 10)
                        })
                    })
                })
            })
            b.doReturn(b.randVar())
        }
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 
            b.callFunction(f, withArgs: [])
        }
    },
    
    ProgramTemplate("VarargsForwarding") { b in
        b.build(n: 10)
        let signature = ProgramTemplate.generateSignature(forFuzzer: b.fuzzer, n: 4)
        let f = b.buildPlainFunction(with: .signature(signature)) { args in
            b.build(n: 15)
            b.doReturn(b.randVar())
        }
        let f1 = b.buildPlainFunction(with: .signature(signature)) { args in
            b.build(n: 15)
            let res = b.callMethod("apply", on: f, withArgs: [b.reuseOrLoadBuiltin("this"), b.reuseOrLoadBuiltin("arguments")])
            b.doReturn(b.randVar())
        }
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 
            b.callFunction(f1, withArgs: b.generateCallArguments(for: signature))
        }
    },

    ProgramTemplate("CFGSimplification") { b in
        b.build(n: 10)
        let f = b.buildPlainFunction(with: .parameters(n: 0)) { args in
            b.build(n: 10)
            let cond = b.compare(b.loadBool(true), with: b.loadBool(true), using: .equal)
            b.buildIfElse(cond, ifBody: {
                b.build(n: 10)
            }, elseBody: {
                b.build(n: 10)
            })
            b.build(n: 10)
            let cond1 = b.compare(b.loadBool(false), with: b.loadBool(true), using: .equal)
            b.buildIf(cond1) {
                b.build(n: 10)
            }
            b.build(n: 5)
            let randV = b.randVar()
            let cond2 = b.compare(randV, with: randV, using: .equal)
            b.buildIf(cond2) {
                b.build(n: 10)
            }
            b.build(n: 5)
            let randInt = Int64.random(in: 0...0x10000)
            let intVar = b.loadInt(randInt)
            let cond3 = b.compare(intVar, with: b.loadInt(randInt), using: .equal)
            b.buildIfElse(cond3, ifBody: {
                b.build(n: 10)
            }, elseBody: {
                b.build(n: 10)
            })

            let f1 = b.buildPlainFunction(with: .parameters(n: 0)) { args1 in
                b.doReturn(b.loadInt(randInt))
            }
            b.build(n: 5)
            let res = b.callFunction(f1, withArgs: [])
            let cond4 = b.compare(res, with: b.loadInt(randInt), using: .equal)
            b.buildIf(cond4) {
                b.build(n: 10)
            }
            b.doReturn(b.randVar())
        }
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 
            b.callFunction(f, withArgs: [])
        }
    },

    ProgramTemplate("ObjectAllocationSinking") { b in
        b.build(n: 10)
        let f = b.buildPlainFunction(with: .parameters(n: 0)) { args in
            b.build(n: 10)
            b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 

                b.build(n: 10)
                var initialProperties = [String: Variable]()
                for _ in 0..<Int.random(in: 0...5) {
                    let propertyName = b.genPropertyNameForWrite()
                    var type = b.type(ofProperty: propertyName)
                    initialProperties[propertyName] = b.randVar(ofType: type) ?? b.generateVariable(ofType: type)
                }
                let obj = b.createObject(with: initialProperties)
                b.build(n: 10)
            }
            b.doReturn(b.randVar())   
        }
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 
            b.callFunction(f, withArgs: [])
        }
    },

    ProgramTemplate("DFGLICM") { b in
        b.build(n: 10)
        let f = b.buildPlainFunction(with: .parameters(n: 0)) { args in
            b.build(n: 10)
            var s = b.loadInt(0)
            let Math = b.reuseOrLoadBuiltin("Math")
            var values = b.randVars(upTo: Int.random(in: 1...3))
            for _ in 0..<Int.random(in: 1...2) {
                values.append(b.loadInt(b.genInt()))
            }
            for _ in 0..<Int.random(in: 0...1) {
                values.append(b.loadFloat(b.genFloat()))
            }
            b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 

                b.build(n: 10)
                guard let method = b.type(of: Math).randomMethod() else { return }
                var args = [Variable]()
                for _ in 0..<b.methodSignature(of: method, on: Math).numParameters {
                    args.append(chooseUniform(from: values))
                }
                s = b.binary(s, b.callMethod(method, on: Math, withArgs: args), with: .Add)
                b.build(n: 10)
            }
            b.build(n: 10)
            b.doReturn(b.randVar())   
        }
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 
            b.callFunction(f, withArgs: [])
        }
    },

    ProgramTemplate("BoundCheckGen") { b in
        b.build(n: 10)

        let sig = Signature(expects: [.anything], returns: .anything)

        let randomNearMax = Int64.random(in: 0x7fffffc0...0x7fffffff)
        let f = b.buildPlainFunction(with: .parameters(sig.parameters)) { args in
            let cond = b.compare(b.loadProperty("length", of: args[0]), with: b.loadInt(15), using: .lessThan)
            b.buildIf(cond) {
                b.doReturn(b.randVar())
            }
            var j = Int64(0)
            b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(2), .Add, b.loadInt(1)) { _ in 
                b.storeElement(b.loadInt(0x41), at: Int64(j), of: args[0])
                j += Int64(0x100000)
                j += randomNearMax
            }
        }

        let size = b.loadInt(Int64.random(in: 0...100))
        let constructor = b.reuseOrLoadBuiltin(
            chooseUniform(
            from: ["Array", "Uint8Array", "Int8Array", "Uint16Array", "Int16Array", "Uint32Array", "Int32Array", "Float32Array", "Float64Array", "Uint8ClampedArray", "BigInt64Array", "BigUint64Array"]
            )
        )

        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 
            b.callFunction(f, withArgs: [b.construct(constructor, withArgs: [size])])
        }

    },

    ProgramTemplate("ArrayAccessGen") { b in
        b.build(n: 10)
        let randSize = Int64.random(in: 0...0x100)
        let size = b.loadInt(randSize)
        let constructor = b.reuseOrLoadBuiltin(
            chooseUniform( from: ["Array", "Uint8Array", "Int8Array", "Uint16Array", "Int16Array", "Uint32Array", "Int32Array", "Float32Array", "Float64Array", "Uint8ClampedArray", "BigInt64Array", "BigUint64Array"]
            )
        )
        let typedArray = b.construct(constructor, withArgs: [size])
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 
            let parseInt = b.reuseOrLoadBuiltin("parseInt")
            b.callFunction(parseInt, withArgs: [])
        }
        b.storeElement(b.loadInt(0x41), at: Int64.random(in: 0...randSize), of: typedArray)
        b.storeElement(b.loadInt(0x41), at: Int64.random(in: -0x10000000...0x10000000), of: typedArray)
        
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(0x10), .Add, b.loadInt(1)) { _ in 
            b.storeElement(b.loadInt(0x41), at: Int64.random(in: 0...randSize), of: typedArray)
            b.loadElement(Int64.random(in: 0...randSize), of: typedArray)
            b.storeElement(b.loadInt(0x41), at: Int64.random(in: -0x10000000...0x10000000), of: typedArray)
            b.loadElement(Int64.random(in: -0x10000000...0x10000000), of: typedArray)
        }

    },

    ProgramTemplate("ProtoGen") { b in
        b.build(n: 30)
        let sig = Signature(expects: [.object(), .boolean], returns: .object())

        let f = b.buildPlainFunction(with: .parameters(sig.parameters)) { args in
            b.build(n: 20)
            let cond = b.compare(args[1], with: b.loadBool(true), using: .equal)
            b.buildIf(cond) {
                b.storeProperty(b.loadInt(0x42), as: "p", on: args[0])
                b.storeProperty(b.createObject(with: [:]), as: "__proto__", on: args[0])
            }
            b.storeProperty(b.loadFloat(13.37), as: "p", on: args[0])
            b.doReturn(args[0])
        }

        b.build(n: 20)
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 
            b.callFunction(f, withArgs: [b.createObject(with: [:]), b.loadBool(false)])
        }

        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 
            let res = b.callFunction(f, withArgs: [b.createObject(with: [:]), b.loadBool(true)])
            let eval = b.reuseOrLoadBuiltin("eval")
            let code = b.buildCodeString() {
                b.loadProperty("p", of: res)
            }
            b.callFunction(eval, withArgs: [code])
        }

    },

    ProgramTemplate("ArrayPop") { b in
        b.build(n: 25)

        let arr = b.createArray(with: [b.createObject(with: ["a": b.loadInt(0x41)]), b.createObject(with: ["a": b.loadInt(0x42)]), b.createObject(with: ["a": b.loadInt(0x43)]), b.createObject(with: ["a": b.loadInt(0x44)]), b.createObject(with: ["a": b.loadInt(0x45)])])
        // Generate a larger function and a signature for it
        let f = b.buildPlainFunction(with: .parameters(n: 0)) { _ in
            b.build(n: 20)
            let cond = b.compare(b.loadProperty("length", of: arr), with: b.loadInt(0), using: .equal)
            b.buildIf(cond) {
                b.storeElement(b.createObject(with: ["a": b.loadInt(0x45)]), at: 3, of: arr)
            }
            let tmp = b.callMethod("pop", on: arr, withArgs: [])
            b.loadProperty("a", of: tmp)
            b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in }

        }
        let p = b.createObject(with: [:])
        b.storeProperty(b.createArray(with: [b.createObject(with: ["a" : b.loadInt(0x40)]), b.createObject(with: ["a" : b.loadInt(0x41)]), b.createObject(with: ["a" : b.loadInt(0x42)])]), as: "__proto__", on: p)

        b.storeElement(b.loadFloat(-1.8629373288622089e-06), at: 0, of: p)

        b.storeProperty(p, as: "__proto__", on: arr)
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(1000), .Add, b.loadInt(1)) { _ in 
            b.callFunction(f, withArgs: [])
        }
    },

    ProgramTemplate("LICMGen") { b in
        
        b.build(n: 10)

        let sig = Signature(expects: [.boolean], returns: .anything)

        let f = b.buildPlainFunction(with: .parameters(sig.parameters)) { args in
            b.build(n: 20)
            b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(100), .Add, b.loadInt(1)) { _ in }
            let cond = b.compare(args[0], with: b.loadBool(false), using: .equal)
            b.buildIf(cond) {
                b.storeProperty(b.loadInt(1), as: "length", on: b.reuseOrLoadBuiltin("arguments"))
            }
            
            b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(10), .Add, b.loadInt(1)) { _ in 
                b.buildForOfLoop(b.reuseOrLoadBuiltin("arguments")) { v in
                    let v18 = b.createObject(with: ["a": b.loadInt(0x4141)])
                    b.buildWith(v18) {

                    }
                }
            }
            b.build(n: 20)
        }
        b.build(n: 10)
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(100), .Add, b.loadInt(1)) { _ in
            b.callFunction(f, withArgs: [b.loadBool(false)])
        }

        b.callFunction(f, withArgs: [b.loadBool(true)])
        b.build(n: 10)
    },
    ProgramTemplate("LICMGen1") { b in
        
        b.build(n: 10)

        let a = b.createArray(with: [b.loadInt(0)])
        let f = b.buildPlainFunction(with: .parameters(n: 0)) { args in
            b.buildForOfLoop(a) { v in
                b.buildForOfLoop(a) { v1 in
                    b.buildWith(b.loadInt(0)) {
                        b.reuseOrLoadBuiltin("Object")
                    }
                }
            }
            
            b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(100), .Add, b.loadInt(1)) { _ in }
        }
        b.callFunction(f, withArgs: [])
        b.build(n: 10)
    },

    ProgramTemplate("LICMGen2") { b in
        
        b.build(n: 10)
        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(10), .Add, b.loadInt(1)) { _ in }

        b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(10), .Add, b.loadInt(1)) { _ in 
            let f = b.buildPlainFunction(with: .parameters(n: 0)) { _ in
                b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(3), .Add, b.loadString("asdf")) { _ in 
                    let cond = b.compare(b.reuseOrLoadBuiltin("Error"), with: b.reuseOrLoadBuiltin("Error"), using: .equal)
                    b.buildIf(cond) {
                        b.loadElement(0, of: b.loadInt(42))
                    }
                    let sig = Signature(expects: [.object()], returns: .anything)
                    let f1 = b.buildPlainFunction(with: .parameters(sig.parameters)) { args1 in
                        b.storeProperty(b.loadInt(42), as: "baz", on: args1[0])
                        b.doReturn(b.loadProperty("baz", of: args1[0]))
                    }
                    b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(10), .Add, b.loadInt(1)) { _ in 
                        b.callFunction(f1, withArgs: [b.createObject(with: [:]), b.reuseOrLoadBuiltin("arguments")], spreading: [false, true])
                    }
                }
            
                b.buildForLoop(b.loadInt(0), .lessThan , b.loadInt(10000), .Add, b.loadInt(1)) { _ in }
            }

            b.callFunction(f, withArgs: [])
        }
        b.build(n: 10)
    },
    
    // Edit here

    ProgramTemplate("JIT1Function") { b in
        let genSize = 3

        // Generate random function signatures as our helpers
        var functionSignatures = ProgramTemplate.generateRandomFunctionSignatures(forFuzzer: b.fuzzer, n: 2)

        ProgramTemplate.generateRandomPropertyTypes(forBuilder: b)
        ProgramTemplate.generateRandomMethodTypes(forBuilder: b, n: 2)

        b.build(n: genSize)

        // Generate some small functions
        for signature in functionSignatures {
            b.buildPlainFunction(with: .signature(signature)) { args in
                b.build(n: genSize)
            }
        }

        // Generate a larger function
        let signature = ProgramTemplate.generateSignature(forFuzzer: b.fuzzer, n: 4)
        let f = b.buildPlainFunction(with: .signature(signature)) { args in
            // Generate (larger) function body
            b.build(n: 30)
        }

        // Generate some random instructions now
        b.build(n: genSize)

        // trigger JIT
        b.buildForLoop(b.loadInt(0), .lessThan, b.loadInt(100), .Add, b.loadInt(1)) { args in
            b.callFunction(f, withArgs: b.generateCallArguments(for: signature))
        }

        // more random instructions
        b.build(n: genSize)
        b.callFunction(f, withArgs: b.generateCallArguments(for: signature))

        // maybe trigger recompilation
        b.buildForLoop(b.loadInt(0), .lessThan, b.loadInt(100), .Add, b.loadInt(1)) { args in
            b.callFunction(f, withArgs: b.generateCallArguments(for: signature))
        }

        // more random instructions
        b.build(n: genSize)

        b.callFunction(f, withArgs: b.generateCallArguments(for: signature))
    },

    ProgramTemplate("JIT2Functions") { b in
        let genSize = 3

        // Generate random function signatures as our helpers
        var functionSignatures = ProgramTemplate.generateRandomFunctionSignatures(forFuzzer: b.fuzzer, n: 2)

        ProgramTemplate.generateRandomPropertyTypes(forBuilder: b)
        ProgramTemplate.generateRandomMethodTypes(forBuilder: b, n: 2)

        b.build(n: genSize)

        // Generate some small functions
        for signature in functionSignatures {
            b.buildPlainFunction(with: .signature(signature)) { args in
                b.build(n: genSize)
            }
        }

        // Generate a larger function
        let signature1 = ProgramTemplate.generateSignature(forFuzzer: b.fuzzer, n: 4)
        let f1 = b.buildPlainFunction(with: .signature(signature1)) { args in
            // Generate (larger) function body
            b.build(n: 15)
        }

        // Generate a second larger function
        let signature2 = ProgramTemplate.generateSignature(forFuzzer: b.fuzzer, n: 4)
        let f2 = b.buildPlainFunction(with: .signature(signature2)) { args in
            // Generate (larger) function body
            b.build(n: 15)
        }

        // Generate some random instructions now
        b.build(n: genSize)

        // trigger JIT for first function
        b.buildForLoop(b.loadInt(0), .lessThan, b.loadInt(100), .Add, b.loadInt(1)) { args in
            b.callFunction(f1, withArgs: b.generateCallArguments(for: signature1))
        }

        // trigger JIT for second function
        b.buildForLoop(b.loadInt(0), .lessThan, b.loadInt(100), .Add, b.loadInt(1)) { args in
            b.callFunction(f2, withArgs: b.generateCallArguments(for: signature2))
        }

        // more random instructions
        b.build(n: genSize)

        b.callFunction(f2, withArgs: b.generateCallArguments(for: signature2))
        b.callFunction(f1, withArgs: b.generateCallArguments(for: signature1))

        // maybe trigger recompilation
        b.buildForLoop(b.loadInt(0), .lessThan, b.loadInt(100), .Add, b.loadInt(1)) { args in
            b.callFunction(f1, withArgs: b.generateCallArguments(for: signature1))
        }

        // maybe trigger recompilation
        b.buildForLoop(b.loadInt(0), .lessThan, b.loadInt(100), .Add, b.loadInt(1)) { args in
            b.callFunction(f2, withArgs: b.generateCallArguments(for: signature2))
        }

        // more random instructions
        b.build(n: genSize)

        b.callFunction(f1, withArgs: b.generateCallArguments(for: signature1))
        b.callFunction(f2, withArgs: b.generateCallArguments(for: signature2))
    },

    // TODO turn "JITFunctionGenerator" into another template?

    ProgramTemplate("TypeConfusionTemplate") { b in
        // This is mostly the template built by Javier Jimenez
        // (https://sensepost.com/blog/2020/the-hunt-for-chromium-issue-1072171/).
        let signature = ProgramTemplate.generateSignature(forFuzzer: b.fuzzer, n: Int.random(in: 2...5))

        let f = b.buildPlainFunction(with: .signature(signature)) { _ in
            b.build(n: 5)
            let array = b.generateVariable(ofType: .object(ofGroup: "Array"))

            let index = b.genIndex()
            b.loadElement(index, of: array)
            b.doReturn(b.randVar())
        }

        // TODO: check if these are actually different, or if
        // generateCallArguments generates the argument once and the others
        // just use them.
        let initialArgs = b.generateCallArguments(for: signature)
        let optimizationArgs = b.generateCallArguments(for: signature)
        let triggeredArgs = b.generateCallArguments(for: signature)

        b.callFunction(f, withArgs: initialArgs)

        b.buildForLoop(b.loadInt(0), .lessThan, b.loadInt(100), .Add, b.loadInt(1)) { _ in
            b.callFunction(f, withArgs: optimizationArgs)
        }

        b.callFunction(f, withArgs: triggeredArgs)
    },
    
]
