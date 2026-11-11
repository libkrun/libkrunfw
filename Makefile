ABI_VERSION = 5
FULL_VERSION = 5.6.4
TIMESTAMP = "Wed Nov 11 04:20:12 PM CET 2026"

KERNEL_VERSION = 6.12.115
KERNEL_REMOTE = https://github.com/libkrun/linux/archive/refs/tags/v$(FULL_VERSION)-$(KERNEL_VERSION).tar.gz
KERNEL_TARBALL = tarballs/v$(FULL_VERSION)-$(KERNEL_VERSION).tar.gz
KERNEL_SOURCES = linux-$(FULL_VERSION)-$(KERNEL_VERSION)
KERNEL_C_BUNDLE = kernel.c

KERNEL_FLAGS = KBUILD_BUILD_TIMESTAMP=$(TIMESTAMP)
KERNEL_FLAGS += KBUILD_BUILD_USER=root
KERNEL_FLAGS += KBUILD_BUILD_HOST=libkrunfw

ifeq ($(origin OS),command line)
    # Use the explicit OS value from command line (e.g. make OS=Windows)
else
    OS := $(shell uname -s)
endif
ifeq ($(OS),Darwin)
    ifeq ($(origin MACOS_BUILDER),command line)
        # Use the explicit MACOS_BUILDER value from command line (e.g. MACOS_BUILDER=native)
    else
        MACOS_BUILDER := krunvm
    endif
endif

ifeq ($(SEV),1)
    VARIANT = -sev
endif
ifeq ($(TDX),1)
    VARIANT = -tdx
endif

HOSTARCH = $(shell uname -m)
ifeq ($(ARCH),)
	GUESTARCH := $(HOSTARCH)
ifeq ($(OS),Darwin)
ifeq ($(HOSTARCH),arm64)
	GUESTARCH := aarch64
endif
endif
	STRIP := strip
else ifeq ($(ARCH),arm64)
	GUESTARCH := aarch64
	CC := $(CROSS_COMPILE)gcc
	STRIP := $(CROSS_COMPILE)strip
else ifeq ($(ARCH),riscv)
	GUESTARCH := riscv64
	CC := $(CROSS_COMPILE)gcc
	STRIP := $(CROSS_COMPILE)strip
else
	GUESTARCH := $(ARCH)
	CC := $(CROSS_COMPILE)gcc
	STRIP := $(CROSS_COMPILE)strip
endif

ifeq ($(OS),Windows)
    CC := x86_64-w64-mingw32-gcc
    VARIANT := -windows
endif

KBUNDLE_TYPE_x86_64 = vmlinux
KBUNDLE_TYPE_aarch64 = Image
KBUNDLE_TYPE_riscv64 = Image

KERNEL_BINARY_x86_64 = $(KERNEL_SOURCES)/vmlinux
KERNEL_BINARY_aarch64 = $(KERNEL_SOURCES)/arch/arm64/boot/Image
KERNEL_BINARY_riscv64 = $(KERNEL_SOURCES)/arch/riscv/boot/Image

KRUNFW_BINARY_Linux = libkrunfw$(VARIANT).so.$(FULL_VERSION)
KRUNFW_SONAME_Linux = libkrunfw$(VARIANT).so.$(ABI_VERSION)
KRUNFW_BASE_Linux = libkrunfw$(VARIANT).so
SONAME_Linux = -Wl,-soname,$(KRUNFW_SONAME_Linux)

KRUNFW_BINARY_Darwin = libkrunfw.$(ABI_VERSION).dylib
KRUNFW_SONAME_Darwin = libkrunfw.$(ABI_VERSION).dylib
KRUNFW_BASE_Darwin = libkrunfw.dylib
SONAME_Darwin =

KRUNFW_BINARY_Windows = libkrunfw.dll
KRUNFW_SONAME_Windows = libkrunfw.dll
KRUNFW_BASE_Windows = libkrunfw.dll
SONAME_Windows =

LIBDIR_Linux = $(shell if [ -e /etc/debian_version ]; then echo 'lib/$(HOSTARCH)-linux-gnu'; else echo lib64; fi)
LIBDIR_Darwin = lib
LIBDIR_Windows = bin

ifeq ($(PREFIX),)
    PREFIX := /usr/local
endif

ifeq ($(OS),Darwin)
ifeq ($(MACOS_BUILDER),native)
    # Native macOS kernel build tools (override on the make command line).
    KERNEL_MAKE ?= gmake
    KERNEL_CC ?= clang
    KERNEL_LD ?= ld.lld
    KERNEL_AR ?= llvm-ar
    KERNEL_NM ?= llvm-nm
    KERNEL_OBJCOPY ?= llvm-objcopy
    KERNEL_OBJDUMP ?= llvm-objdump
    KERNEL_STRIP ?= llvm-strip
    KERNEL_READELF ?= llvm-readelf
    KERNEL_HOSTCC ?= $(KERNEL_CC)

    KERNEL_KBUILD_FLAGS = LLVM=1 ARCH=arm64 \
        CC=$(KERNEL_CC) LD=$(KERNEL_LD) AR=$(KERNEL_AR) NM=$(KERNEL_NM) \
        OBJCOPY=$(KERNEL_OBJCOPY) OBJDUMP=$(KERNEL_OBJDUMP) STRIP=$(KERNEL_STRIP) \
        READELF=$(KERNEL_READELF) HOSTCC=$(KERNEL_HOSTCC) \
        $(KERNEL_FLAGS)
    MACOS_HOST_INCLUDE = $(CURDIR)/include/macos-host
    KERNEL_HOSTFLAGS = HOSTCFLAGS="-I$(MACOS_HOST_INCLUDE) -D_UUID_T -D__GETHOSTUUID_H"
endif
endif

ifeq ($(SEV),1)
    QBOOT_BINARY = qboot/sev/bios.bin
    QBOOT_C_BUNDLE = qboot.c
    INITRD_BINARY = initrd/initrd.gz
    INITRD_C_BUNDLE = initrd.c
endif
ifeq ($(TDX),1)
    QBOOT_BINARY = qboot/tdx/bios.bin
    QBOOT_C_BUNDLE = qboot.c
    INITRD_BINARY = initrd/initrd.gz
    INITRD_C_BUNDLE = initrd.c
endif

.PHONY: all install clean

all: $(KRUNFW_BINARY_$(OS))

$(KERNEL_TARBALL):
	@mkdir -p tarballs
	curl -L $(KERNEL_REMOTE) -o $(KERNEL_TARBALL)

$(KERNEL_SOURCES): $(KERNEL_TARBALL)
	tar xf $(KERNEL_TARBALL)
	cp config-libkrunfw$(VARIANT)_$(GUESTARCH) $(KERNEL_SOURCES)/.config
ifeq ($(OS),Darwin)
ifeq ($(MACOS_BUILDER),native)
	cd $(KERNEL_SOURCES) && $(KERNEL_MAKE) $(KERNEL_KBUILD_FLAGS) $(KERNEL_HOSTFLAGS) olddefconfig
else
	cd $(KERNEL_SOURCES) ; $(MAKE) olddefconfig
endif
else
	cd $(KERNEL_SOURCES) ; $(MAKE) olddefconfig
endif

$(KERNEL_BINARY_$(GUESTARCH)): $(KERNEL_SOURCES)
ifeq ($(OS),Darwin)
ifeq ($(MACOS_BUILDER),native)
	cd $(KERNEL_SOURCES) && rm -f .version && $(KERNEL_MAKE) $(MAKEFLAGS) $(KERNEL_KBUILD_FLAGS) $(KERNEL_HOSTFLAGS)
else
	cd $(KERNEL_SOURCES) ; rm -f .version ; $(MAKE) $(MAKEFLAGS) $(KERNEL_FLAGS)
endif
else
	cd $(KERNEL_SOURCES) ; rm -f .version ; $(MAKE) $(MAKEFLAGS) $(KERNEL_FLAGS)
endif

ifeq ($(OS),Darwin)
ifeq ($(MACOS_BUILDER),krunvm)
$(KERNEL_C_BUNDLE):
	@echo "Building on macOS using krunvm (./build_on_krunvm.sh)"
	./build_on_krunvm.sh
else
$(KERNEL_C_BUNDLE): $(KERNEL_BINARY_$(GUESTARCH))
	@echo "Generating $(KERNEL_C_BUNDLE) from $(KERNEL_BINARY_$(GUESTARCH))..."
	@python3 bin2cbundle.py --os $(OS) -t $(KBUNDLE_TYPE_$(GUESTARCH)) $(KERNEL_BINARY_$(GUESTARCH)) kernel.c
endif
else
$(KERNEL_C_BUNDLE): $(KERNEL_BINARY_$(GUESTARCH))
	@echo "Generating $(KERNEL_C_BUNDLE) from $(KERNEL_BINARY_$(GUESTARCH))..."
	@python3 bin2cbundle.py --os $(OS) -t $(KBUNDLE_TYPE_$(GUESTARCH)) $(KERNEL_BINARY_$(GUESTARCH)) kernel.c
endif

ifeq ($(SEV),1)
$(QBOOT_C_BUNDLE): $(QBOOT_BINARY)
	@echo "Generating $(QBOOT_C_BUNDLE) from $(QBOOT_BINARY)..."
	@python3 bin2cbundle.py -t qboot $(QBOOT_BINARY) qboot.c

$(INITRD_C_BUNDLE): $(INITRD_BINARY)
	@echo "Generating $(INITRD_C_BUNDLE) from $(INITRD_BINARY)..."
	@python3 bin2cbundle.py -t initrd $(INITRD_BINARY) initrd.c
endif

ifeq ($(TDX),1)
$(QBOOT_C_BUNDLE): $(QBOOT_BINARY)
	@echo "Generating $(QBOOT_C_BUNDLE) from $(QBOOT_BINARY)..."
	@python3 bin2cbundle.py -t qboot $(QBOOT_BINARY) qboot.c

$(INITRD_C_BUNDLE): $(INITRD_BINARY)
	@echo "Generating $(INITRD_C_BUNDLE) from $(INITRD_BINARY)..."
	@python3 bin2cbundle.py -t initrd $(INITRD_BINARY) initrd.c
endif

$(KRUNFW_BINARY_$(OS)): $(KERNEL_C_BUNDLE) $(QBOOT_C_BUNDLE) $(INITRD_C_BUNDLE)
ifeq ($(OS),Windows)
	$(CC) -shared -DABI_VERSION=$(ABI_VERSION) -O2 -o $@ $(KERNEL_C_BUNDLE) $(QBOOT_C_BUNDLE) $(INITRD_C_BUNDLE) -Wl,--kill-at -Wl,--nxcompat
else
	$(CC) -fPIC -DABI_VERSION=$(ABI_VERSION) -shared $(SONAME_$(OS)) -o $@ $(KERNEL_C_BUNDLE) $(QBOOT_C_BUNDLE) $(INITRD_C_BUNDLE)
ifeq ($(OS),Linux)
	$(STRIP) $(KRUNFW_BINARY_$(OS))
endif
endif

install:
	install -d $(DESTDIR)$(PREFIX)/$(LIBDIR_$(OS))/
	install -m 755 $(KRUNFW_BINARY_$(OS)) $(DESTDIR)$(PREFIX)/$(LIBDIR_$(OS))/
ifeq ($(OS),Darwin)
	cd $(DESTDIR)$(PREFIX)/$(LIBDIR_$(OS))/ ; ln -sf $(KRUNFW_BINARY_$(OS)) $(KRUNFW_BASE_$(OS))
else ifeq ($(OS),Windows)
	# Windows doesn't need soname symlinks
else
	cd $(DESTDIR)$(PREFIX)/$(LIBDIR_$(OS))/ ; ln -sf $(KRUNFW_BINARY_$(OS)) $(KRUNFW_SONAME_$(OS)) ; ln -sf $(KRUNFW_SONAME_$(OS)) $(KRUNFW_BASE_$(OS))
endif

clean:
	rm -fr $(KERNEL_SOURCES) $(KERNEL_C_BUNDLE) $(QBOOT_C_BUNDLE) $(INITRD_C_BUNDLE) $(KRUNFW_BINARY_$(OS))
