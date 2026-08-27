#
#  flexprobe.mk —— FlexProbe 宿主工程集成文件
#
#  把 FLEX++ 全部源码 + FlexProbe 布局抓取模块并入任意 Theos 工程，
#  宿主打包时即自带「三指双击 → 导出布局快照」能力。
#
#  用法（在宿主 Makefile 中、include tweak.mk 之前）：
#
#      TWEAK_NAME = MyTweak
#      ...
#      # 指向 FLEX fork 仓库在本机的路径
#      FLEXPROBE_DIR ?= $(THEOS_PROJECT_DIR)/../flex-
#      include $(FLEXPROBE_DIR)/flexprobe.mk
#
#      include $(THEOS_MAKE_PATH)/tweak.mk
#
#  前置要求：
#    · 宿主 target 为 ARC（FLEX 源码要求 -fobjc-arc，本文件已自动追加）
#    · 宿主链接 -lz（本文件已自动追加）
#    · 本文件会把宿主全局警告关掉（-w），如宿主需要保留警告请注释最后一行
#

FLEXPROBE_DIR ?= $(THEOS_PROJECT_DIR)/../flex-

# 1) FLEX++ 根目录平铺源码(.m/.mm/.c)+ capstone 反汇编(仅 ARM/AArch64,复用原 Makefile 规则)
FLEXPROBE_CORE_SRCS := $(shell find $(FLEXPROBE_DIR) -maxdepth 1 \( -name '*.m' -o -name '*.mm' -o -name '*.c' \) | grep -v '/theos/')
FLEXPROBE_CAPSTONE_SRCS := $(shell find $(FLEXPROBE_DIR)/x/capstone -maxdepth 1 -name '*.c') $(shell find $(FLEXPROBE_DIR)/x/capstone/arch/AArch64 -name '*.c')
FLEXPROBE_MODULE_SRCS := $(wildcard $(FLEXPROBE_DIR)/FlexProbe/*.m)

# 2) 并入宿主 target
$(TWEAK_NAME)_FILES += $(FLEXPROBE_CORE_SRCS) $(FLEXPROBE_CAPSTONE_SRCS) $(FLEXPROBE_MODULE_SRCS)
$(TWEAK_NAME)_LDFLAGS += -lz
$(TWEAK_NAME)_CFLAGS += -I$(FLEXPROBE_DIR) -I$(FLEXPROBE_DIR)/FlexProbe -I$(FLEXPROBE_DIR)/x -I$(FLEXPROBE_DIR)/x/capstone/include
$(TWEAK_NAME)_CFLAGS += -DCAPSTONE_HAS_AARCH64 -DCAPSTONE_USE_SYS_DYN_MEM
$(TWEAK_NAME)_OBJCFLAGS += -fobjc-arc

# 3) FLEX++ 源码风格宽松，静默编译避免拖垮宿主构建
$(TWEAK_NAME)_CFLAGS += -w
