################################################################################
#
# apr
#
################################################################################

APR_VERSION = 1.7.5
APR_SOURCE = apr-$(APR_VERSION).tar.bz2
APR_SITE = https://archive.apache.org/dist/apr
APR_LICENSE = Apache-2.0
APR_LICENSE_FILES = LICENSE
APR_CPE_ID_VENDOR = apache
APR_CPE_ID_PRODUCT = portable_runtime
APR_INSTALL_STAGING = YES
# We have a patch touching configure.in and Makefile.in,
# so we need to autoreconf:
APR_AUTORECONF = YES

APR_CONF_OPTS = --disable-sctp

# avoid apr_hints.m4 by setting apr_preload_done=yes and set
# the needed CFLAGS on our own (avoids '-D_REENTRANT' in case
# not supported by toolchain and subsequent configure failure)
APR_CFLAGS = $(TARGET_CFLAGS) -DLINUX -D_GNU_SOURCE
ifeq ($(BR2_TOOLCHAIN_HAS_THREADS),y)
APR_CFLAGS += -D_REENTRANT
endif

APR_CONF_ENV = \
	CC_FOR_BUILD="$(HOSTCC)" \
	CFLAGS_FOR_BUILD="$(HOST_CFLAGS)" \
	CFLAGS="$(APR_CFLAGS)" \
	ac_cv_file__dev_zero=yes \
	ac_cv_mmap__dev_zero=yes \
	ac_cv_func_setpgrp_void=yes \
	apr_cv_process_shared_works=yes \
	apr_cv_mutex_robust_shared=no \
	apr_cv_tcp_nodelay_with_cork=yes \
	ac_cv_sizeof_struct_iovec=8 \
	ac_cv_sizeof_pid_t=4 \
	ac_cv_struct_rlimit=yes \
	ac_cv_strerror_r_rc_int=$(if $(BR2_TOOLCHAIN_USES_MUSL),yes,no) \
	ac_cv_o_nonblock_inherited=no \
	apr_cv_mutex_recursive=yes \
	apr_cv_epoll=yes \
	apr_cv_epoll_create1=yes \
	apr_cv_dup3=yes \
	apr_cv_sock_cloexec=yes \
	apr_cv_accept4=yes \
	apr_preload_done=yes
APR_CONFIG_SCRIPTS = apr-1-config

# Doesn't even try to guess when cross compiling
ifeq ($(BR2_TOOLCHAIN_HAS_THREADS),y)
APR_CONF_ENV += apr_cv_pthreads_lib="-lpthread"
endif

# Fix lfs detection when cross compiling
APR_CONF_ENV += apr_cv_use_lfs64=yes

# Use non-portable atomics when available. We have to override
# ap_cv_atomic_builtins because the test used to  check for atomic
# builtins uses AC_TRY_RUN, which doesn't work when cross-compiling.
ifeq ($(BR2_TOOLCHAIN_HAS_SYNC_8),y)
APR_CONF_OPTS += --enable-nonportable-atomics
APR_CONF_ENV += ap_cv_atomic_builtins=yes
else
APR_CONF_OPTS += --disable-nonportable-atomics
endif

ifeq ($(BR2_PACKAGE_UTIL_LINUX_LIBUUID),y)
APR_DEPENDENCIES += util-linux
endif

define APR_CLEANUP_UNNEEDED_FILES
	$(RM) -rf $(TARGET_DIR)/usr/build-1/
endef

APR_POST_INSTALL_TARGET_HOOKS += APR_CLEANUP_UNNEEDED_FILES

define APR_FIXUP_RULES_MK
	$(SED) 's%apr_builddir=%apr_builddir=$(STAGING_DIR)%' \
		$(STAGING_DIR)/usr/build-1/apr_rules.mk
	$(SED) 's%apr_builders=%apr_builders=$(STAGING_DIR)%' \
		$(STAGING_DIR)/usr/build-1/apr_rules.mk
	$(SED) 's%top_builddir=%top_builddir=$(STAGING_DIR)%' \
		$(STAGING_DIR)/usr/build-1/apr_rules.mk
endef

APR_POST_INSTALL_STAGING_HOOKS += APR_FIXUP_RULES_MK

$(eval $(autotools-package))
