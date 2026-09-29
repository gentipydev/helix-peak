#version 460 core

// A drawn clip frame packed as NV12, for `Nv12Packer`
// (lib/shared/share/nv12_packer.dart).
//
// The output is (W/4) x (3H/2) pixels of four bytes each. Read back row by
// row it is one NV12 frame: W x H of luma, then W x H/2 of Cb and Cr
// interleaved, each taken from a 2x2 block. BT.709, limited range, through
// the same integer coefficients `VideoEncoderChannel.kt` uses on RGBA
// (docs/video-encoding-spike.md), so both paths give the same bytes.
//
// Every channel, alpha included, carries a byte, so the pass is drawn with
// BlendMode.src and is never composited.

precision highp float;

#include <flutter/runtime_effect.glsl>

// The frame's size in pixels.
uniform vec2 uSize;
uniform sampler2D uFrame;

out vec4 fragColor;

// The frame's pixel at [pixel] as 0 to 255.
vec3 rgbAt(vec2 pixel) {
  vec2 uv = (pixel + 0.5) / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  // A texture Impeller drew on GLES is stored bottom up.
  uv.y = 1.0 - uv.y;
#endif
  return floor(texture(uFrame, uv).rgb * 255.0 + 0.5);
}

// y = 16 + ((47r + 157g + 16b + 128) >> 8)
float luma(vec3 c) {
  return 16.0 + floor((47.0 * c.r + 157.0 * c.g + 16.0 * c.b + 128.0) / 256.0);
}

// The 2x2 block from [corner], each channel (a + b + c + d + 2) >> 2.
vec3 block(vec2 corner) {
  vec3 sum = rgbAt(corner) + rgbAt(corner + vec2(1.0, 0.0)) +
             rgbAt(corner + vec2(0.0, 1.0)) + rgbAt(corner + vec2(1.0, 1.0));
  return floor((sum + 2.0) / 4.0);
}

// u = 128 + ((-26r - 86g + 112b + 128) >> 8)
// v = 128 + ((112r - 102g - 10b + 128) >> 8)
vec2 chroma(vec3 c) {
  return vec2(
      128.0 + floor((-26.0 * c.r - 86.0 * c.g + 112.0 * c.b + 128.0) / 256.0),
      128.0 + floor((112.0 * c.r - 102.0 * c.g - 10.0 * c.b + 128.0) / 256.0));
}

void main() {
  vec2 at = floor(FlutterFragCoord().xy);
  float x = at.x * 4.0;
  if (at.y < uSize.y) {
    fragColor = vec4(luma(rgbAt(vec2(x, at.y))),
                     luma(rgbAt(vec2(x + 1.0, at.y))),
                     luma(rgbAt(vec2(x + 2.0, at.y))),
                     luma(rgbAt(vec2(x + 3.0, at.y)))) /
                255.0;
  } else {
    float y = (at.y - uSize.y) * 2.0;
    fragColor = vec4(chroma(block(vec2(x, y))),
                     chroma(block(vec2(x + 2.0, y)))) /
                255.0;
  }
}
