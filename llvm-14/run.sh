mkdir build 
cd build
cmake -DCMAKE_BUILD_TYPE=Release '-DLLVM_ENABLE_PROJECTS=clang' -DLLVM_ENABLE_RUNTIMES='compiler-rt' ../llvm
make -j 30


# /home/piers/llvm-project-14.0.1.src/llvm/lib/Transforms/Instrumentation