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
COPY --from=ghcr.io/projectbluefin/common:latest@sha256:be5dc61c44afa86cbc5167b36591fc64966bb68bf0d0a113122495c7c3abce54 /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest@sha256:48be52bde586f6637ce83f128bf9ba1580b7e4de4d093fed94bec587082850ce /system_files /oci/brew

# Copy from submodule.  We put it under /oci for convenience
COPY tr-osforge/reusable_scripting /oci/tr-osforge

# Base Image stage
FROM quay.io/almalinuxorg/atomic-desktop-gnome:latest@sha256:d086674f677642aebf1ccd8b5bfeced3bab0bd63aea3291a7c61a3ce26361765


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
