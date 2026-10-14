#version 460 core
#include <flutter/runtime_effect.glsl>

// Living fire on a word: flames rise from the top edges of the letters,
// the air above shimmers, and the letters glow orange to yellow inside.
// uText is the word rendered white on transparent at the canvas size.

uniform vec2 uSize;
uniform float uTime;
uniform sampler2D uText;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p *= 2.03;
    a *= 0.5;
  }
  return v;
}

float mask(vec2 uv) {
  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
  return texture(uText, uv).a;
}

vec3 fireRamp(float t) {
  vec3 ember = vec3(0.45, 0.04, 0.0);
  vec3 orange = vec3(1.0, 0.36, 0.02);
  vec3 yellow = vec3(1.0, 0.82, 0.25);
  vec3 white = vec3(1.0, 0.97, 0.85);
  if (t < 0.4) return mix(ember, orange, t / 0.4);
  if (t < 0.8) return mix(orange, yellow, (t - 0.4) / 0.4);
  return mix(yellow, white, (t - 0.8) / 0.2);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float aspect = uSize.x / uSize.y;
  float t = uTime;

  // Heat shimmer: the air wobbles more the higher it is.
  float shimmer = (noise(vec2(uv.y * 18.0, t * 3.0)) - 0.5) * 0.006 * (1.2 - uv.y);
  vec2 suv = uv + vec2(shimmer, 0.0);

  float letter = mask(suv);

  // Flames: gather the letters below this pixel along a swaying column,
  // weighted by how far the heat has climbed. Jittered samples and a soft
  // sum (not a max) keep the flame smooth instead of stacked copies.
  vec2 flow = vec2(suv.x * aspect * 3.0, suv.y * 3.0 + t * 1.8);
  float turbulence = fbm(flow);
  // A little jitter between samples, smoothed so it reads as flicker,
  // not grain.
  float jitter = 0.5 + 0.35 * (hash(floor(frag / 3.0) + floor(t * 30.0)) - 0.5);
  float heat = 0.0;
  const int N = 28;
  for (int i = 0; i < N; i++) {
    float k = (float(i) + jitter) / float(N);
    float climb = k * 0.55;
    float sway = (noise(vec2(suv.x * aspect * 5.0, (suv.y + climb) * 3.0 + t * 2.4)) - 0.5) * 0.09 * k;
    float m = mask(vec2(suv.x + sway, suv.y + climb));
    heat += m * pow(1.0 - k, 1.15);
  }
  heat = heat / (float(N) * 0.32);
  // Tongues: noise carves the glow into licks that rise and flicker.
  float licks = fbm(vec2(suv.x * aspect * 7.0, suv.y * 5.0 + t * 3.2));
  float flame = smoothstep(0.18, 0.95, heat * (0.45 + 0.9 * licks) + turbulence * 0.08);
  flame *= 0.9 + 0.1 * sin(t * 11.0 + uv.x * 23.0);

  // Inside the letters: a warm gradient that breathes, brighter at the top.
  float glow = 0.55 + 0.35 * (1.0 - uv.y) + 0.12 * sin(t * 2.4 + uv.x * 7.0);
  glow += (fbm(vec2(suv.x * aspect * 5.0, suv.y * 5.0 - t * 0.9)) - 0.5) * 0.25;
  vec3 inside = fireRamp(clamp(glow, 0.0, 1.0));

  vec3 color = fireRamp(clamp(flame * 1.25, 0.0, 1.0));
  float flameAlpha = clamp(flame * 1.6, 0.0, 1.0) * (1.0 - letter);

  vec3 outColor = inside * letter + color * flameAlpha;
  float alpha = clamp(letter + flameAlpha, 0.0, 1.0);
  fragColor = vec4(outColor, alpha);
}
