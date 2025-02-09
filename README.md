# bazel_vcpkg

This is a simple bazel rule to use vcpkg with bazel. 

## Use

In your WORKSPACE file add:
```
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "meu_vcpkg_rules",
    strip_prefix = "vcpk_deps",
    urls = ["https://github.com/aelxtpt/bazel_vcpkg/archive/main.zip"],
)

load("@meu_vcpkg_rules//:vcpkg_deps.bzl", "load_vcpkg_dependencies")

load_vcpkg_dependencies(
    name = "vcpkg_dependencies",
    libs_path = "//:libs.json",
    arch = "arm64-linux", # VCPKG Triplet
)
```

## Limitations
- This rule will link all 
