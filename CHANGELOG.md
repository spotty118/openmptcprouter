# Changelog

All notable changes to OpenMPTCProuter Optimized will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Network download retry logic with exponential backoff in easy-install.sh
- Input validation for build parameters (OMR_KERNEL, OMR_PACKAGES) in build.sh
- Reusable `omr_download_with_retry()` and `omr_fetch_url()` helpers in omr-lib.sh
- Better error messages for VPN software installation in omr-vps-install.sh
- Service startup verification with actionable troubleshooting hints
- CHANGELOG.md for release tracking

### Changed
- Service restarts in client-auto-setup.sh now run sequentially with status reporting
- Improved Shadowsocks service management with verification
- Updated BBR2 patch condition to remove duplicate check

### Fixed
- Duplicate kernel version check `5.4 || 5.4` in build.sh line 556
- Background service restarts without verification in client-auto-setup.sh
- Missing retry logic for network downloads causing silent failures

### Security
- All credential files now created with restrictive permissions (umask 077)
- Input validation prevents invalid environment variables from causing build issues

## [Previous Releases]

For release history before this changelog was introduced, see:
- [GitHub Releases](https://github.com/spotty118/openmptcprouter/releases)
- Git tags: `git tag -l`

---

## Release Process

When preparing a new release:

1. Update version numbers in relevant files
2. Add changes to this CHANGELOG under `[Unreleased]`
3. Create a new version section when releasing
4. Tag the release: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
5. Push tags: `git push origin --tags`

### Version Format
- MAJOR: Breaking changes or major features
- MINOR: New features, backward compatible
- PATCH: Bug fixes, backward compatible
