# arch2code containers

Dockerfiles for the arch2code development image, `arch2code/a2c-dev`. The image provides the
compilers, simulators and libraries that arch2code projects build against. Project images
(see `docker/Dockerfile` in arch2code) are built on top of it.

## Images

| Make target     | Dockerfile            | Image tag                          | Purpose |
| :-------------- | :-------------------- | :--------------------------------- | :------ |
| `prod-build`    | `Dockerfile`          | `arch2code/a2c-dev:<TAGNAME>`      | Release image |
| `test-build`    | `Dockerfile`          | `arch2code/a2c-dev-test:<TAGNAME>` | Release image plus a non-root user matching the caller, for local checks |
| `prod-build-vg` | `Dockerfile-valgrind` | `arch2code/a2c-dev-vg:<TAGNAME>`   | Release image plus valgrind, with SystemC built for debugging |
| `test-build-vg` | `Dockerfile-valgrind` | `arch2code/a2c-dev-vg-test:<TAGNAME>` | Valgrind image plus a non-root user |

```sh
make prod-build TAGNAME=3.0                     # docker
make prod-build TAGNAME=3.0 DOCKER_PRE_SH=sudo  # rootful podman / docker via sudo
```

`TAGNAME` defaults to `wip`. It is also written into the image as the marker file `/a2c-dev:<TAGNAME>`.

## Contents (3.0)

| Component | Version | Source |
| :-------- | :------ | :----- |
| Base OS | Ubuntu 24.04 | `ubuntu:24.04` |
| GCC / G++ | 13.2.0, pinned (`gcc`, `g++`, `cc`, `c++` link to it) | Ubuntu 24.04 release pocket |
| Clang, clang-format, clangd | 20 (`clang`, `clang++`, `clangd` link to it) | apt.llvm.org |
| Boost | 1.74 by default | Ubuntu (`libboost<ver>-all-dev`) |
| SystemC | 2.3.4 | built from source |
| Verilator | 5.052 | built from source |
| fmt | 10.2.1 | built from source |
| yaml-cpp | 0.8 | Ubuntu |
| Python | 3.12, with ruamel.yaml, colorama, graphviz, jinja2, pyyaml | Ubuntu, pip |
| Node.js / Antora | 24 / 3.1 | nvm, npm |
| Graphviz | 2.43 | Ubuntu |
| Tools | gdb, lldb, ccache, mold, z3, jq, ripgrep, gh, Java 21 | Ubuntu, GitHub CLI repository |

Environment variables set in the image: `SC_BASE`, `SYSTEMC_INCLUDE`, `SYSTEMC_LIBDIR`,
`BOOST_INCLUDE`, `LD_BOOST`, `NVM_DIR` and `PIP_BREAK_SYSTEM_PACKAGES=1`.

### Build arguments

- `GCC_VERSION` (default `13.2.0-23ubuntu4`): Ubuntu package version GCC 13 is pinned to.
  13.2.0 matches the GCC used by the farm simulator (VCS) flows, which sets the compatibility
  baseline; Clang uses this GCC's libstdc++ headers.
- `BOOST_VERSION` (default `1.74`): Boost release to install. 1.74 matches the Boost headers used
  on the RHEL farm flows. Pass `--build-arg BOOST_VERSION=1.83` for Ubuntu 24.04's default.

### Notes

- **pip:** Ubuntu 24.04 marks the system Python as externally managed (PEP 668). The image sets
  `PIP_BREAK_SYSTEM_PACKAGES=1`, so `pip3 install -r requirements.txt` works as it did on 22.04.
- **Default `ubuntu` user:** the `test-build` stages remove the user and group that 24.04 ships
  with UID/GID 1000, so a caller with that UID can be created.
- **Unpinned inputs:** apt packages other than GCC 13, the Node.js 24 minor release and `gh`
  resolve to their latest versions at build time. Shared runtime libraries such as `libstdc++6`
  come from the Ubuntu 24.04 archive.

## Changes from 2.0

- **Base OS:** Ubuntu 22.04 to 24.04; Python 3.10 to 3.12.
- **Versions:** Verilator 5.038 to 5.052; Node.js 20 to 24.
- **GCC:** 13.1 from the ubuntu-toolchain-r test PPA to 13.2.0 from the Ubuntu archive, pinned to
  match the farm simulator toolchain. The PPA is no longer used, so its pre-release runtime
  libraries (`libstdc++6`, `libgcc-s1` and others) are no longer installed.
- **Boost:** 1.74, now selectable with `BOOST_VERSION`.
- **Added:** clangd, jq, ripgrep and the GitHub CLI; `cc`/`c++` links to GCC 13.
- **Path fixes:** `SYSTEMC_LIBDIR` (was `/urs/lib`) and `LD_BOOST` (was `/lib64`).
- **Git:** no longer disables TLS certificate verification (`http.sslverify false`).
