###############################################################################
# PROJECT NAME CONFIGURATION
###############################################################################
# Name: tr-desktop-almalinux
#
# IMPORTANT: This name should be used consistently throughout the repository in:
#   - Justfile: export image_name := env("IMAGE_NAME", "your-name-here")
#   - README.md: # your-name-here (title)
#   - artifacthub-repo.yml: repositoryID: your-name-here
#   - custom/ujust/README.md: localhost/your-name-here:stable (in bootc switch example)
#
# The project name defined here is the single source of truth for your
# custom image's identity. When changing it, update all references above
# to maintain consistency.
###############################################################################

###############################################################################
# MULTI-STAGE BUILD ARCHITECTURE
###############################################################################
# This Containerfile follows the Bluefin architecture pattern as implemented in
# @projectbluefin/distroless. The architecture layers OCI containers together:
#
# 1. Context Stage (ctx) - Combines resources from:
#    - Local build scripts and custom files
#    - @projectbluefin/common - Desktop configuration shared with Aurora 
#    - @ublue-os/brew - Homebrew integration
#    - @rrenomeron/tr-osforge - Shared build scripting
#
# 2. Base Image Options:
#    - quay.io/almalinuxorg/atomic-desktop-gnome ("Silverblue, but AlmaLinux")
#
# 3. Customizations:
#    - see build/build.sh and custom/*
#
# See: https://docs.projectbluefin.io/contributing/ for architecture diagram
###############################################################################

# Context stage - combine local and imported OCI container resources
FROM scratch AS ctx

COPY build /build
COPY custom /custom
# Copy from OCI containers to distinct subdirectories to avoid conflicts
# Note: Renovate can automatically update these :latest tags to SHA-256 digests for reproducibility
COPY --from=ghcr.io/ublue-os/brew:latest@sha256:de0391c67209703bdf1249079c8d478d44eff864d62e7ec6f12aaa382bdf21df /system_files /oci/brew
COPY --from=ghcr.io/projectbluefin/common:latest@sha256:3097cdd9cb57471b17b8df1e974cd7972865ebb0e876623060ec63a294327297 /system_files /oci/common

# Copy from submodule.  We put it under /oci for convenience
COPY tr-osforge/reusable_scripting /oci/tr-osforge

# Base Image stage
FROM quay.io/almalinuxorg/atomic-desktop-gnome:latest@sha256:eb7d8957143ef8b3fd2ff5215b47ef73df965b90319cb1830638509ebc6c70a1


ARG IMAGE_NAME
ARG TAG

### MODIFICATIONS
## Make modifications desired in your image and install packages by modifying the build scripts.
## The following RUN directive mounts the ctx stage which includes:
##   - Local build scripts from /build
##   - Local custom files from /custom
##   - Files from @projectbluefin/common at /oci/common
##   - Files from @projectbluefin/branding at /oci/branding
##   - Files from @ublue-os/artwork at /oci/artwork
##   - Files from @ublue-os/brew at /oci/brew
##   - Files from @rrenomeron/tr-osforge at /oci/tr-osforge
## See build/build.sh for more details

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=bind,from=ghcr.io/blue-build/modules:latest,src=/modules,dst=/tmp/modules,rw \
    --mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:latest,src=/scripts/,dst=/tmp/scripts/ \
    /ctx/build/build.sh
    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
