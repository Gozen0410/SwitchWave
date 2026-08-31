FROM devkitpro/devkita64:20260215

SHELL ["/bin/bash", "-c"]

ARG GIMP_VERSION=2

RUN if [ "$GIMP_VERSION" = "3" ]; then \
        echo 'deb http://deb.debian.org/debian trixie main' > /etc/apt/sources.list.d/trixie.list \
        && printf 'Package: *\nPin: release n=trixie\nPin-Priority: 100\n' > /etc/apt/preferences.d/trixie; \
    fi \
    && apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake libtool \
    bison flex \
    python3-pip ninja-build \
    wget ca-certificates \
    && if [ "$GIMP_VERSION" = "3" ]; then \
        apt-get install -y -t trixie --no-install-recommends gimp python3-mako; \
    else \
        apt-get install -y --no-install-recommends gimp python3-mako; \
    fi \
    && pip3 install --break-system-packages meson \
    && rm -rf /var/lib/apt/lists/*

ENV DEVKITPRO=/opt/devkitpro
ENV PORTLIBS_PREFIX=${DEVKITPRO}/portlibs/switch

RUN dkp-pacman -Syu --noconfirm switch-ntfs-3g switch-lwext4

# Build the user's libusbhsfs fork with GPL support. Apply the small GCC-16
# compatibility fix from the build environment to upstream v0.2.10 code.
RUN git clone --depth 1 https://github.com/Gozen0410/libusbhsfs.git /tmp/libusbhsfs \
    && cd /tmp/libusbhsfs \
    && sed -i '/max_burst++;/s/^[[:space:]]*//' source/usbhsfs_drive.c \
    && sed -i '/max_burst++;/a\        (void)max_burst;' source/usbhsfs_drive.c \
    && source ${DEVKITPRO}/switchvars.sh \
    && make clean \
    && make BUILD_TYPE=GPL \
    && test -s lib/libusbhsfs.a \
    && ar t lib/libusbhsfs.a | grep -Eq '^(ntfs(_dev|_disk_io)?|ext(_dev|_disk_io)?)\\.o$' \
    && make BUILD_TYPE=GPL install \
    && rm -rf /tmp/libusbhsfs

RUN git clone --depth 1 https://github.com/sahlberg/libsmb2.git /tmp/libsmb2 \
    && cd /tmp/libsmb2 \
    && make -f Makefile.platform switch_install \
    && rm -rf /tmp/libsmb2

COPY misc/libnfs/switch.patch /tmp/libnfs-switch.patch
RUN wget -qO- https://github.com/sahlberg/libnfs/archive/refs/tags/libnfs-5.0.2.tar.gz | tar xz -C /tmp \
    && cd /tmp/libnfs-libnfs-5.0.2 \
    && patch -Np1 -i /tmp/libnfs-switch.patch \
    && source ${DEVKITPRO}/switchvars.sh \
    && ./bootstrap \
    && ./configure --prefix="${PORTLIBS_PREFIX}" --host=aarch64-none-elf \
        --disable-shared --enable-static --disable-werror --disable-utils --disable-examples \
    && make && make install \
    && rm -rf /tmp/libnfs-libnfs-5.0.2 /tmp/libnfs-switch.patch

WORKDIR /mnt
