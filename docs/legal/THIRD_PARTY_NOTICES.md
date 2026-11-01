# Third-party notices — preliminary review

This is a preliminary inventory of the native video-player dependency in
CocinaP mobile version `1.0.8+8`. It is not legal advice or a completed
software bill of materials. Recheck the resolved versions and native artifacts
for every release.

## media_kit and native playback libraries

The Dart packages `media_kit_libs_video` `1.0.7`,
`media_kit_libs_android_video` `1.3.8` and
`media_kit_libs_ios_video` `1.1.4` are resolved in
`cocinap_mobile/pubspec.lock`. Their package source identifies the wrapper
projects as MIT-licensed.

The Android plugin's Gradle script downloads the `default-*.jar` artifacts
from `media-kit/libmpv-android-video-build` release `v1.1.7`. The upstream
build repository labels its `default` and `full` flavors MIT, and its separate
`encoders-gpl` flavor GPL-3.0-or-later. The resolved Android plugin selects
the `default` artifacts, not `encoders-gpl`.

The iOS plugin's Makefile downloads the `video-default` artifact from
`media-kit/libmpv-darwin-build` release `v0.6.0`, pinned by SHA-256 in that
Makefile. The upstream project describes its builds as supporting commercial
use for playback and distinguishes GPL builds for encoding.

## Required before commercial distribution

- Preserve the applicable MIT copyright and license notices for the packages
  and selected native builds.
- Obtain and review the exact third-party component/license notices and build
  configuration shipped inside the Android JARs and iOS frameworks, including
  FFmpeg and codecs. The upstream flavor summary alone does not establish
  compliance for every included component.
- Generate and review a complete, release-specific software bill of materials
  and license notices for the actual Android and iOS artifacts.
- Have the final notice set and distribution obligations reviewed for the
  intended jurisdictions and use.

This review is therefore still open; do not treat it as legal clearance to
publish.

## Sources

- [media_kit_libs_video package](https://pub.dev/packages/media_kit_libs_video/versions/1.0.7)
- [Android native-library build and flavor licensing](https://github.com/media-kit/libmpv-android-video-build/tree/v1.1.7)
- [iOS/macOS native-library build project](https://github.com/media-kit/libmpv-darwin-build)
