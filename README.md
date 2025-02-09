# bazel_vcpkg

This is a simple bazel rule to use vcpkg with bazel. 

## Requirements
1. Vcpkg installed and in your PATH
2. VCPKG_ROOT enviroment defined

## Use

Create a file libs.json and put your dependencies

```json
{
    "libs": [ 
        { "name": "protobuf", "version": "4.25.1#1" }
    ]
}
```

In your WORKSPACE file add:
```
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "vcpkg_deps_repo",
    strip_prefix = "bazel_vcpkg-main",
    urls = ["https://github.com/aelxtpt/bazel_vcpkg/archive/refs/heads/main.zip"],
)

load("@vcpkg_deps_repo//:vcpkg_repository.bzl", "load_vcpkg_dependencies")

load_vcpkg_dependencies(
    name = "vcpkg",
    libs_path = "//:libs.json",
    arch = "arm64-linux", # VCPKG triplet
    update_baseline = True # If you want use the last commit from vcpkg repository or use a predefined commit
)
```

## Limitations
- This rule will link all installed libraries statically to your binary, so install only what you really need.
