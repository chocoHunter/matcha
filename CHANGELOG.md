# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

- Added battery-mode recovery using stored `pmset` snapshots instead of fixed restore values.
- Added startup self-healing and clearer recovery behavior for battery-mode power overrides.
- Added lid-close display sleep handling for battery mode to better match closed-lid background use.
- Added unit tests for `pmset` parsing, restore planning, and lid-close display-sleep transitions.
- Added a release build script for generating and validating `.app` and `.dmg` artifacts.
- Added CI, open-source readiness docs, and repository metadata files.
- Improved README and README-CN with clearer mode explanations, recovery guidance, and build steps.

## 1.0.0

- Initial public project structure and menu bar sleep-prevention modes.
