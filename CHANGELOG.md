# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Composite action that installs IVPM, restores/saves its content-addressed
  cache, and runs `ivpm update`.
- Inputs: `version`, `python-version`, `installer` (`auto`/`pip`/`uv`),
  `run-update`, `dep-set`, `project-dir`, `jobs`, `args`, `cache`, `cache-dir`,
  `cache-key-prefix`, `cache-dependency-path`, `cache-python`, `token`.
- Outputs: `cache-hit`, `ivpm-version`, `cache-dir`.
- Sphinx documentation published to GitHub Pages.
- CI: actionlint + shellcheck; integration self-tests across the installer
  matrix and cache lifecycle.
