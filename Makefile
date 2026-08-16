PACKAGE_IDENTIFIER = com.pxx917144686.flex
PACKAGE_NAME = FLEX++
PACKAGE_VERSION = 1.0.0
PACKAGE_ARCHITECTURE = arm64
PACKAGE_REVISION = 1
PACKAGE_SECTION = Tweaks
PACKAGE_DEPENDS = firmware (>= 9.0)
PACKAGE_DESCRIPTION = FLEX调试工具

define Package/com.pxx917144686.flex
  Package: com.pxx917144686.flex
  Name: FLEX++
  Version: 1.0.0
  Architecture: arm64
  Author: FLEX Team & pxx917144686修改
  Section: Tweaks
  Depends: firmware (>= 9.0)
  Description: FLEX调试工具
endef

TARGET = iphone:clang:latest:13.0
ARCHS = arm64 arm64e

LIBRARY_NAME = FLEX_pp
LIBRARY_TYPE = dynamic

export THEOS_PACKAGE_SCHEME = rootless
THEOS_PACKAGE_INSTALL_PREFIX = /var/jb

export THEOS_PACKAGE_DIR = $(CURDIR)/packages

FLEX_pp_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

# 包含所有源文件（排除FLEX原版和重复文件）
FLEX_pp_FILES = $(shell find . \( -name '*.m' -o -name '*.mm' -o -name '*.c' \) | \
    grep -v "^./FLEX/" | \
    grep -v "x/retdec/" | \
    grep -v "x/retdec-build/" | \
    grep -v "x/Shared/FLEXKeychain.m" | \
    grep -v "x/Shared/FLEXKeychainQuery.m" | \
    grep -v "x/capstone/")

# Capstone核心文件（只包含ARM/ARM64架构）
CAPSTONE_CORE = $(shell find x/capstone -maxdepth 1 -name "*.c")
CAPSTONE_ARCH = $(shell find x/capstone/arch/AArch64 -name "*.c")
FLEX_pp_FILES += $(CAPSTONE_CORE) $(CAPSTONE_ARCH)

FLEX_pp_FRAMEWORKS = Foundation UIKit CoreGraphics CoreFoundation
FLEX_pp_LIBRARIES = system xml2

FLEX_pp_LDFLAGS += -Wl,-no_warn_inits,-search_paths_first,-headerpad_max_install_names
FLEX_pp_CFLAGS = -fobjc-arc -include flex_fishhook.h \
                 -DFLEX_LIVE_OBJECTS_CONTROLLER_IS_VIEW_CONTROLLER=1 \
                 -DFLEX_LIVE_OBJECTS_VIEW_CONTROLLER=FLEXLiveObjectsController \
                 -Wno-unsupported-availability-guard \
                 -Wno-unused-but-set-variable \
                 -Wno-unguarded-availability-new \
                 -Wno-incompatible-pointer-types \
                 -Wno-deprecated-declarations \
                 -Wno-nullability-completeness \
                 -Wno-arc-retain-cycles \
                 -Wno-objc-missing-property-synthesis \
                 -Wno-unused-variable \
                 -Wno-unused-function \
                 -Wno-objc-protocol-method-implementation \
                 -Wno-implicit-function-declaration \
                 -Wno-nonnull \
                 -Wno-format \
                 -Wno-shift-op-parentheses \
                 -DCAPSTONE_HAS_AARCH64 \
                 -DCAPSTONE_USE_SYS_DYN_MEM \
                 -I./x \
                 -I./x/capstone/include

FLEX_pp_CCFLAGS = -std=c++17 -Wno-unused-function -Wno-objc-missing-property-synthesis
FLEX_pp_OBJCFLAGS = -fobjc-arc
FLEX_pp_CFLAGS += -miphoneos-version-min=9.0

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk

after-package::
	@mkdir -p packages
	@if [ -f ".theos/obj/FLEX_pp.dylib" ]; then \
		cp -f ".theos/obj/FLEX_pp.dylib" packages/FLEX++.dylib; \
		cp -f ".theos/obj/FLEX_pp.dylib" packages/FLEX++_1.0.0.dylib; \
	fi

