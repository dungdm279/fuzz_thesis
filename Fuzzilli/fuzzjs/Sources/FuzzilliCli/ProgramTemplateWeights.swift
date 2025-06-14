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

import Fuzzilli

/// Assigned weights for the builtin program templates.
let programTemplateWeights = [
    // Edit here
    "JIT1Function":          2,
    "JIT2Functions":         2,
    "TypeConfusionTemplate": 1,
    "LICMGen":  0,
    "LICMGen1": 3,
    "LICMGen2": 0,
    "ArrayPop": 1,
    "ProtoGen": 1,
    "ArrayAccessGen": 1,
    "BoundCheckGen" : 1,
    "DFGLICM": 3,
    "ObjectAllocationSinking": 1,
    "CFGSimplification": 2,
    "VarargsForwarding": 1,
    "B3InferSwitches": 1,
    
]
