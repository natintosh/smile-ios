## 10.0.0-beta08 (unreleased)

### Removed
- `filename` property from `PrepUploadRequest`


## 10.0.0-beta07

### Changed
- Declare `jobType` property of `PartnerParams` as optional

## 10.0.0-beta06

### Changed
- Declare `jobType` property of `AuthenticationRequest` as optional

## 10.0.0-beta05

### Changed
- Expose `sourceSdk` and `sourceSdkVersion` initializers and properties

## 10.0.0-beta04

### Changed
- Expose `AuthenticationRequest` and `AuthenticationResponse` initializers and properties

## 10.0.0-beta03

### Changed
- Set default value for config param on `initialize` method
- Expose initializers for `PartnerParams` and `EnhancedKycAsycResponse` models

## 10.0.0-beta02

### Added

- Enhanced KYC Async API endpoint

### Changed
- Point Podspec to public repo
- Point Pacakge.swift to the Resource directory
- Rename ImageType enums to drop PNG support
- Add a `SmileID.version` constant

### Fixed

- Fix bug where reenroll is enabled on every job

## 10.0.0-beta01

### Added
- Initial release 🎉
- SmartSelfie™ Authentication and Enrollment
- Theming
- Networking

### Dependencies
- Zip