"""This is a module docstring."""

def _parse_libs_json(content):
    data = json.decode(content)
    packages = []
    overrides = []

    for lib_info in data.get("libs", []):
        lib_name = lib_info.get("name")
        lib_version = lib_info.get("version")
        if lib_name:
            packages.append((lib_name, lib_version))

            if lib_version:
                overrides.append({
                    "name": lib_name,
                    "version": lib_version
                })

    return packages, overrides

def _load_vcpkg_dependencies_impl(repository_ctx):
    vcpkg_root = repository_ctx.os.environ.get("VCPKG_ROOT")
    if not vcpkg_root:
        fail("VCPKG_ROOT environment variable must be set")

    arch = repository_ctx.attr.arch.name
    update_baseline = repository_ctx.attr.update_baseline
    timeout = repository_ctx.attr.timeout

    repo_root = repository_ctx.path("")
    vcpkg_exe = repository_ctx.path("{}/vcpkg".format(vcpkg_root))
    
    project_dir = repo_root.get_child("_vcpkg_project")
    repository_ctx.execute([
        "mkdir", "-p", 
        str(project_dir),
        str(project_dir.get_child("installed"))
    ])

    libs_json_path = repository_ctx.path(repository_ctx.attr.libs_path)
    libs_json_content = repository_ctx.read(libs_json_path)
    packages, overrides = _parse_libs_json(libs_json_content)

    print("Project dir: {}".format(project_dir))

    print("Arch: {}".format(arch))

    if update_baseline:
        vcpkg_json = {
            "dependencies": [name for (name, _) in packages],
            #"builtin-baseline": "74ec888e385d189b42d6b398d0bbaa6f1b1d3b0e",
            "overrides": overrides
        }

        repository_ctx.file(
            project_dir.get_child("vcpkg.json"),
            json.encode_indent(vcpkg_json)
        )

        result = repository_ctx.execute([
            "bash", "-c",
            "cd {project_dir} && {vcpkg_exe} x-update-baseline --add-initial-baseline".format(
                project_dir = str(project_dir),
                vcpkg_exe = str(vcpkg_exe)
            )
        ], timeout = timeout)
        
        if result.return_code != 0:
            fail("Failed to update baseline:\nSTDOUT:\n{}\nSTDERR:\n{}".format(
                result.stdout, result.stderr
            ))

        baseline_content = repository_ctx.read(project_dir.get_child("vcpkg.json"))
        print("New baseline: {}".format(json.decode(baseline_content)["builtin-baseline"]))
    else:
        vcpkg_json = {
            "dependencies": [name for (name, _) in packages],
            "builtin-baseline": "74ec888e385d189b42d6b398d0bbaa6f1b1d3b0e",
            "overrides": overrides
        }

        repository_ctx.file(
            project_dir.get_child("vcpkg.json"),
            json.encode_indent(vcpkg_json)
        )

    print("Installing packages")

    install_args = [
        str(vcpkg_exe),
        "install",
        "--triplet={}".format(arch),
        "--x-manifest-root={}".format(str(project_dir)),
        "--x-install-root={}".format(str(project_dir.get_child("installed")))
    ]

    result = repository_ctx.execute(
        install_args,
        environment = {
            "VCPKG_ROOT": str(vcpkg_root),
            "VCPKG_DOWNLOADS": str(project_dir.get_child("downloads"))
        },
        quiet = False,
        timeout = timeout
    )
    
    if result.return_code != 0:
        fail("vcpkg install failed:\n" + result.stderr)
        return
    
    build_file_content = ""
    for (package, _) in packages:
        print("Processing package: {}".format(package))

        include_path = "{}/installed/{}/include".format(project_dir, arch)
        libs_path = "{}/installed/{}/lib".format(project_dir, arch)

        rel_include_path = "vcpkg_deps/{name}_{arch}_include".format(name = package, arch = arch.replace("-", "_"))
        rel_lib_path = "vcpkg_deps/{name}_{arch}_lib".format(name = package, arch = arch.replace("-", "_"))
        
        repository_ctx.symlink(include_path, repository_ctx.path(rel_include_path))
        repository_ctx.symlink(libs_path, repository_ctx.path(rel_lib_path))

        build_file_content += """
cc_library(
name = "{name}",
hdrs = glob(["{rel_include_path}/**"]),
includes = ["{rel_include_path}"],
srcs = glob(["{rel_lib_path}/*.a"]),
visibility = ["//visibility:public"],
linkstatic = True,
)
""".format(name = package, rel_include_path = rel_include_path, rel_lib_path = rel_lib_path)

    repository_ctx.file("BUILD.bazel", build_file_content)

load_vcpkg_dependencies = repository_rule(
    implementation = _load_vcpkg_dependencies_impl,
    attrs = {
        "libs_path": attr.label(mandatory = True, allow_single_file = True),
        "arch": attr.label(mandatory = True),
        "update_baseline": attr.bool(default = False),
        "timeout": attr.int(default = 1800)
    },
    environ = ["VCPKG_ROOT"],
)
