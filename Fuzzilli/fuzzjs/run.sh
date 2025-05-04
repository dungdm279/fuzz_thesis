
#swift build -c debug -Xlinker='-lrt' -Xlinker='-lhiredis'
swift run -c debug -Xlinker='-lrt' -Xlinker='-lhiredis' FuzzilliCli --jobs=10 --profile=jsc --overwrite --storagePath=./out --engine=multi /mnt/c/Users/piers/Documents/fuzzJS/webkit/WebKitBuild/Debug/bin/jsc