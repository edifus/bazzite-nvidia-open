# bazzite-nvidia-open:42.20250529.2
ARG BUILD_DIGEST=sha256:c0acc49e89f45cc353383cb6947b462920d4db34699e5e09b6674ffa588d2122

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build /

# Base Image
FROM ghcr.io/ublue-os/bazzite-nvidia-open@${BUILD_DIGEST} AS bazzite-nvidia-open
COPY rootfs /

RUN \
  --mount=type=bind,from=ctx,source=/,target=/ctx \
  --mount=type=cache,dst=/var/cache \
  --mount=type=cache,dst=/var/log \
  --mount=type=tmpfs,dst=/tmp \
  mkdir -p /var/roothome && \
  /ctx/build.sh && \
  /ctx/fix-opt.sh && \
  /ctx/initramfs.sh && \
  /ctx/cleanup.sh && \
  ostree container commit

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
