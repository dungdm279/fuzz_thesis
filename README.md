# FuzzJS

## 1.Compile Clang

Download [LLVM source code](https://releases.llvm.org/download.html).

Replace ```llvm/lib/Transforms/Instrumentation/SanitizerCoverage.cpp``` with ```llvm-14/SanitizerCoverage.cpp``` in this repository. 

Modify the path of ```sancov.txt``` in ```llvm-14/SanitizerCoverage.cpp```.

Compile LLVM with ```llvm-14/run.sh```.

## 2.Build JavaScriptCore
Build JSC with modified ```webkit/jsc.cpp```, specify the clang path to the path compiled earlier.  
Build JSC arguments:  
```./Tools/Scripts/build-jsc --jsc-only --debug --cmakeargs="-DENABLE_STATIC_JSC=ON -DCMAKE_C_COMPILER='/mnt/e/llvm14/llvm-project-14.0.1.src/build/bin/clang' -DCMAKE_CXX_COMPILER='/mnt/e/llvm14/llvm-project-14.0.1.src/build/bin/clang++' -DCMAKE_CXX_FLAGS='-fsanitize-coverage=trace-pc-guard -O3 -lrt'"```

## 3.Build Fuzzer

Build:
```
swift build -c debug -Xlinker='-lrt' -Xlinker='-lhiredis'
```
Run:
```
swift run -c debug -Xlinker='-lrt' -Xlinker='-lhiredis' FuzzilliCli --jobs=10 --profile=jsc --overwrite --storagePath=./out --engine=multi /mnt/c/Users/piers/Documents/fuzzJS/webkit/WebKitBuild/Debug/bin/jsc
```
