FROM ubuntu:24.04 AS prod-build

ARG TAGNAME=null

RUN apt-get -y update --fix-missing
RUN apt-get -y upgrade
RUN apt-get -y install make cmake git curl gnupg --no-install-recommends
RUN apt-get -y install ca-certificates
RUN apt-get -y install jq ripgrep --no-install-recommends

###########################################
# GCC 13 repository setup in 24.04
###########################################
# 1- Add the APT repository key
RUN mkdir -p /etc/apt/keyrings
RUN curl -sS "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2c277a0a352154e5" >> /etc/apt/keyrings/ubuntu-toolchain.asc
RUN curl -sS "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x1e9377a2ba9ef27f" >> /etc/apt/keyrings/ubuntu-toolchain.asc
# 2- Add the repository for PPA ubuntu toolchain to apt sources
RUN echo "deb [signed-by=/etc/apt/keyrings/ubuntu-toolchain.asc] http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu noble main" > /etc/apt/sources.list.d/ubuntu-toolchain.list

###########################################
# LLVM 20 repository setup in 24.04
###########################################
# 1- Add the APT repository key
RUN mkdir -p /etc/apt/keyrings
RUN curl -o /etc/apt/keyrings/llvm.asc https://apt.llvm.org/llvm-snapshot.gpg.key
# 2- Add the repository for llvm 20 to apt sources
RUN echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/llvm.asc] http://apt.llvm.org/noble/ llvm-toolchain-noble-20 main" > /etc/apt/sources.list.d/llvm20.list

# Update package lists
RUN apt-get -y update

# Install Clang 20 and related tools
RUN apt-get -y install clang-20 clang-format-20 clangd-20 --no-install-recommends
RUN cd /usr/bin && ln -s ../lib/llvm-20/bin/clang clang
RUN cd /usr/bin && ln -s ../lib/llvm-20/bin/clang++ clang++
RUN cd /usr/bin && ln -s ../lib/llvm-20/bin/clangd clangd
RUN DEBIAN_FRONTEND=noninteractive apt-get -qq install default-jre --no-install-recommends
RUN apt-get -y install python3 python3-pip --no-install-recommends
RUN apt-get -y install graphviz --no-install-recommends
RUN apt-get -y install libstdc++-13-dev --no-install-recommends

# c++ yaml parser library
RUN apt-get -y install libyaml-cpp-dev --no-install-recommends

# Boost 1.74 matches the farm's site Boost headers; 24.04's default is 1.83 (--build-arg BOOST_VERSION=1.83)
ARG BOOST_VERSION=1.74
# the -qq is very quiet and implies -y, used to avoid geographic questions during build
RUN DEBIAN_FRONTEND=noninteractive apt-get -qq install libboost${BOOST_VERSION}-all-dev --no-install-recommends
RUN pip3 install ruamel.yaml colorama graphviz jinja2 pyyaml --break-system-packages

# making ENV and calling nvm.sh and installing
#   source https://stackoverflow.com/a/62838796/8980882
#   last step ie the npm command is to install antora 3.0
# certificates used by nvm, pip3, and probably more
ENV XDG_CONFIG_HOME=/usr/local
RUN mkdir -p ${XDG_CONFIG_HOME}
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
ENV NVM_DIR=/usr/local/nvm
RUN . $NVM_DIR/nvm.sh && nvm install 24 --alias=default && npm install -g @antora/cli@3.1 @antora/site-generator@3.1
# make path to $NVM_BIN resilient to nvm release version updates
RUN . $NVM_DIR/nvm.sh && ln -s `dirname $NVM_BIN` `nvm_version_dir`/default
ENV PATH=$NVM_DIR/versions/node/default/bin:$PATH

# enables color terminal by default
ENV TERM=xterm-256color

# Compile fmt library
RUN git clone https://github.com/fmtlib/fmt.git --depth 1 --branch 10.2.1 /usr/local/src/fmt
RUN mkdir -p /usr/local/src/fmt/build
WORKDIR /usr/local/src/fmt/build
RUN cmake --install-prefix=/usr -DBUILD_SHARED_LIBS=TRUE ..
RUN make fmt install/fast clean

WORKDIR /

# These are needed for systemc compilation
RUN apt-get -y install build-essential lldb gdb # try without lld
RUN apt-get -y install libtool libltdl-dev


RUN git clone https://github.com/accellera-official/systemc.git --depth 1 --branch 2.3.4 /usr/local/src/systemc
WORKDIR /usr/local/src/systemc
RUN autoupdate
RUN aclocal && automake --add-missing
RUN autoreconf
RUN mkdir -p objdir
WORKDIR /usr/local/src/systemc/objdir
RUN ../configure --prefix=/usr --with-unix-layout CXXFLAGS="-std=c++17 -DSC_CPLUSPLUS=201703L -DSC_DISABLE_COPYRIGHT_MESSAGE"
RUN make -j `nproc`
RUN make install clean

WORKDIR /

# Set environment variables for SystemC and boost
ENV SC_BASE=/usr
ENV SYSTEMC_INCLUDE=/usr/include
ENV SYSTEMC_LIBDIR=/usr/lib
ENV BOOST_INCLUDE=/usr/include/boost
ENV LD_BOOST=/usr/lib/x86_64-linux-gnu

# purge libs for systemc install
RUN apt-get -y purge build-essential
RUN apt-get -y purge libtool libltdl-dev
RUN apt-get -y purge gcc g++

# Now install verilator
RUN apt-get -y install help2man flex bison ccache mold z3 --no-install-recommends
RUN apt-get -y install libfl-dev libgoogle-perftools-dev numactl --no-install-recommends

RUN git clone https://github.com/verilator/verilator --depth 1 --branch v5.052 /usr/local/src/verilator

# Every time you need to build:
RUN unset VERILATOR_ROOT
WORKDIR /usr/local/src/verilator

RUN autoconf
RUN ./configure
RUN make -j `nproc`
RUN make install clean

# Install GitHub CLI
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get -y install gh --no-install-recommends

# Install GCC 13
RUN apt-get -y install gcc-13 g++-13
RUN cd /usr/bin && ln -s gcc-13 gcc
RUN cd /usr/bin && ln -s g++-13 g++
RUN cd /usr/bin && ln -s gcc-13 cc
RUN cd /usr/bin && ln -s g++-13 c++

# Once complete try to remove autoconf, flex and bison, and certs
#RUN apt-get -y purge autoconf flex bison
RUN apt-get clean
#RUN apt -y autoremove # <- this unfortunatley removes boost libraries so we can't do that

WORKDIR /

RUN rm -rf /var/lib/apt/lists/*

# Ubuntu 24.04 marks the system Python as externally managed (PEP 668); let plain `pip3 install`
# (CI, derived images) install into it as it did on 22.04
ENV PIP_BREAK_SYSTEM_PACKAGES=1

RUN touch /a2c-dev:${TAGNAME}

# test build target (for validation of the prod-build image on CI instance)
FROM prod-build AS test-build

ARG USERNAME=
ARG USER_UID=
ARG USER_GID=

# Remove the default ubuntu user/group shipped with 24.04 (UID/GID 1000) if present
RUN if id ubuntu >/dev/null 2>&1; then touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu; fi
RUN if getent group ubuntu >/dev/null 2>&1; then groupdel ubuntu; fi

# Create container test user (non-root)
RUN groupadd -f -g ${USER_GID} ${USERNAME}
RUN useradd ${USERNAME} -m -d /home/${USERNAME} -u ${USER_UID} -g ${USER_GID} -s /bin/bash
RUN passwd -de ${USERNAME}

USER ${USERNAME}

