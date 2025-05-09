################################################################################
#
# optee-os
#
################################################################################

OPTEE_OS_VERSION = $(call qstrip,$(BR2_TARGET_OPTEE_OS_VERSION))
OPTEE_OS_LICENSE = BSD-2-Clause
ifeq ($(BR2_TARGET_OPTEE_OS_LATEST),y)
OPTEE_OS_LICENSE_FILES = LICENSE
endif

OPTEE_OS_CPE_ID_PREFIX = cpe:2.3:o
OPTEE_OS_CPE_ID_VENDOR = linaro
OPTEE_OS_CPE_ID_PRODUCT = op-tee

OPTEE_OS_INSTALL_STAGING = YES
OPTEE_OS_INSTALL_IMAGES = YES

ifeq ($(BR2_TARGET_OPTEE_OS_CUSTOM_TARBALL),y)
OPTEE_OS_TARBALL = $(call qstrip,$(BR2_TARGET_OPTEE_OS_CUSTOM_TARBALL_LOCATION))
OPTEE_OS_SITE = $(patsubst %/,%,$(dir $(OPTEE_OS_TARBALL)))
OPTEE_OS_SOURCE = $(notdir $(OPTEE_OS_TARBALL))
else ifeq ($(BR2_TARGET_OPTEE_OS_CUSTOM_GIT),y)
OPTEE_OS_SITE = $(call qstrip,$(BR2_TARGET_OPTEE_OS_CUSTOM_REPO_URL))
OPTEE_OS_SITE_METHOD = git
else
OPTEE_OS_SITE = $(call github,OP-TEE,optee_os,$(OPTEE_OS_VERSION))
endif

ifeq ($(BR2_TARGET_OPTEE_OS):$(BR2_TARGET_OPTEE_OS_LATEST),y:)
BR_NO_CHECK_HASH_FOR += $(OPTEE_OS_SOURCE)
endif

OPTEE_OS_DEPENDENCIES = host-openssl host-python3 host-python-pyelftools

ifeq ($(BR2_TARGET_OPTEE_OS_NEEDS_PYTHON_CRYPTOGRAPHY),y)
OPTEE_OS_DEPENDENCIES += host-python-cryptography
else
OPTEE_OS_DEPENDENCIES += host-python-pycryptodomex
endif

ifeq ($(BR2_TARGET_OPTEE_OS_NEEDS_DTC),y)
OPTEE_OS_DEPENDENCIES += host-dtc
endif

# On 64bit targets, OP-TEE OS can be built in 32bit mode, or
# can be built in 64bit mode and support 32bit and 64bit
# trusted applications. Since buildroot currently references
# a single cross compiler, build exclusively in 32bit
# or 64bit mode.
OPTEE_OS_MAKE_OPTS = \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	CROSS_COMPILE_core="$(TARGET_CROSS)" \
	CROSS_COMPILE_ta_arm64="$(TARGET_CROSS)" \
	CROSS_COMPILE_ta_arm32="$(TARGET_CROSS)" \
	PYTHON3="$(HOST_DIR)/bin/python3"

ifeq ($(BR2_aarch64),y)
OPTEE_OS_MAKE_OPTS += \
	CFG_ARM64_core=y \
	CFG_USER_TA_TARGETS=ta_arm64
else
OPTEE_OS_MAKE_OPTS += \
	CFG_ARM32_core=y
endif

# Get mandatory PLATFORM and optional PLATFORM_FLAVOR and additional
# variables
OPTEE_OS_MAKE_OPTS += PLATFORM=$(call qstrip,$(BR2_TARGET_OPTEE_OS_PLATFORM))
ifneq ($(call qstrip,$(BR2_TARGET_OPTEE_OS_PLATFORM_FLAVOR)),)
OPTEE_OS_MAKE_OPTS += PLATFORM_FLAVOR=$(call qstrip,$(BR2_TARGET_OPTEE_OS_PLATFORM_FLAVOR))
endif
OPTEE_OS_MAKE_OPTS += $(call qstrip,$(BR2_TARGET_OPTEE_OS_ADDITIONAL_VARIABLES))

# Requests OP-TEE OS to build from subdirectory out/ of its sourcetree
# root path otherwise the output directory path depends on the target
# platform name.
OPTEE_OS_BUILDDIR_OUT = out
ifeq ($(BR2_aarch64),y)
OPTEE_OS_LOCAL_SDK = $(OPTEE_OS_BUILDDIR_OUT)/export-ta_arm64
OPTEE_OS_SDK = $(STAGING_DIR)/lib/optee/export-ta_arm64
endif
ifeq ($(BR2_arm),y)
OPTEE_OS_LOCAL_SDK = $(OPTEE_OS_BUILDDIR_OUT)/export-ta_arm32
OPTEE_OS_SDK = $(STAGING_DIR)/lib/optee/export-ta_arm32
endif

OPTEE_OS_IMAGE_FILES = $(call qstrip,$(BR2_TARGET_OPTEE_OS_CORE_IMAGES))

OPTEE_OS_CUSTOM_DTS_PATH = $(call qstrip,$(BR2_TARGET_OPTEE_OS_CUSTOM_DTS_PATH))

ifeq ($(BR2_TARGET_OPTEE_OS_CORE),y)
define OPTEE_OS_BUILD_CORE
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) O=$(OPTEE_OS_BUILDDIR_OUT) \
		$(TARGET_CONFIGURE_OPTS) $(OPTEE_OS_MAKE_OPTS) all
endef
define OPTEE_OS_INSTALL_IMAGES_CORE
	mkdir -p $(BINARIES_DIR)
	$(foreach f,$(OPTEE_OS_IMAGE_FILES), \
		cp -dpf $(wildcard $(@D)/$(OPTEE_OS_BUILDDIR_OUT)/core/$(f)) $(BINARIES_DIR)/
	)
endef
endif # BR2_TARGET_OPTEE_OS_CORE

ifeq ($(BR2_TARGET_OPTEE_OS_SERVICES),y)
define OPTEE_OS_INSTALL_TARGET_CMDS
	$(if $(wildcard $(@D)/$(OPTEE_OS_BUILDDIR_OUT)/ta/*/*.ta),
		$(INSTALL) -D -m 444 -t $(TARGET_DIR)/lib/optee_armtz \
			$(@D)/$(OPTEE_OS_BUILDDIR_OUT)/ta/*/*.ta)
	$(if $(wildcard $(@D)/$(OPTEE_OS_LOCAL_SDK)/lib/*.ta),
		$(INSTALL) -D -m 444 -t $(TARGET_DIR)/lib/optee_armtz \
			$(@D)/$(OPTEE_OS_LOCAL_SDK)/lib/*.ta)
endef
endif # BR2_TARGET_OPTEE_OS_SERVICES

ifeq ($(BR2_TARGET_OPTEE_OS_SDK),y)
define OPTEE_OS_BUILD_SDK
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) O=$(OPTEE_OS_BUILDDIR_OUT) \
		 $(TARGET_CONFIGURE_OPTS) $(OPTEE_OS_MAKE_OPTS) ta_dev_kit
endef
define OPTEE_OS_INSTALL_STAGING_CMDS
	mkdir -p $(OPTEE_OS_SDK)
	cp -ardpf $(@D)/$(OPTEE_OS_LOCAL_SDK)/* $(OPTEE_OS_SDK)
endef
endif # BR2_TARGET_OPTEE_OS_SDK

define OPTEE_OS_BUILD_CMDS
	$(if $(OPTEE_OS_CUSTOM_DTS_PATH),
		cp -f $(OPTEE_OS_CUSTOM_DTS_PATH) $(@D)/core/arch/arm/dts/
	)
	$(OPTEE_OS_BUILD_CORE)
	$(OPTEE_OS_BUILD_SDK)
endef

define OPTEE_OS_INSTALL_IMAGES_CMDS
	$(OPTEE_OS_INSTALL_IMAGES_CORE)
	$(OPTEE_OS_INSTALL_IMAGES_SERVICES)
endef

ifeq ($(BR2_TARGET_OPTEE_OS)$(BR_BUILDING),yy)
ifeq ($(call qstrip,$(BR2_TARGET_OPTEE_OS_PLATFORM)),)
$(error No OP-TEE OS platform set. Check your BR2_TARGET_OPTEE_OS_PLATFORM setting)
endif

ifeq ($(BR2_TARGET_OPTEE_OS_CUSTOM_TARBALL),y)
ifeq ($(call qstrip,$(BR2_TARGET_OPTEE_OS_CUSTOM_TARBALL_LOCATION)),)
$(error No tarball location specified. Please check BR2_TARGET_OPTEE_OS_CUSTOM_TARBALL_LOCATION)
endif
endif

ifeq ($(BR2_TARGET_OPTEE_OS_CUSTOM_GIT),y)
ifeq ($(call qstrip,$(BR2_TARGET_OPTEE_OS_CUSTOM_REPO_URL)),)
$(error No repository specified. Please check BR2_TARGET_OPTEE_OS_CUSTOM_REPO_URL)
endif
endif

endif # BR2_TARGET_OPTEE_OS && BR2_BUILDING

$(eval $(generic-package))
