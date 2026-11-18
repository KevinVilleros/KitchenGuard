# FFmpeg third-party notice

The Windows test package includes FFmpeg as a separate executable and its
shared libraries. This component is not part of CocinaP and is not covered by
the CocinaP commercial license.

- Upstream: [FFmpeg](https://ffmpeg.org/)
- Windows build: [FFmpeg-Builds](https://github.com/FFmpeg-Builds/FFmpeg-Builds)
- Build archive: `ffmpeg-n9.0-latest-win64-lgpl-shared-9.0.zip`
- Archive SHA-256:
  `da743e1a461aa35ee3f49cf3ae9d325a1e7c59fc3d70e35a2df0243a39248040`
- FFmpeg version reported by the build: `n9.0.2-57-gd838f9f9ae-20261117`
- FFmpeg source revision:
  [d838f9f9ae](https://github.com/FFmpeg/FFmpeg/commit/d838f9f9ae)
- License: GNU Lesser General Public License, version 3 or later. The included
  `LICENSE.txt` contains the license text.

The build enables OpenH264 and disables `libx264`. OpenH264 is used by the
cloud publisher in this test build. FFmpeg and its shared libraries are
distributed under their respective upstream licenses; see the included
`LICENSE.txt` and the upstream build project for source and licensing details.
The FFmpeg source is available from the source revision linked above.
