#version 300 es
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform vec2 resolution;
uniform float time;
uniform vec4 date;

const float _cloudscale = 1.1;
const float _speed = 0.02;
const float _clouddark = 0.5;
const float _cloudlight = 0.3;
const float _cloudcover = 0.2;
const float _cloudalpha = 8.0;
const float _skytint = 0.5;
const vec3 _skycolour1 = vec3(0.2, 0.4, 0.6);
const vec3 _skycolour2 = vec3(0.4, 0.7, 1.0);

const mat2 m = mat2(1.6, 1.2, -1.2, 1.6);

vec2 hash22(vec2 p) {
  p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
  return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float simplexNoise(in vec2 p) {
  const float K1 = 0.366025404; // (sqrt(3)-1)/2;
  const float K2 = 0.211324865; // (3-sqrt(3))/6;
  vec2 i = floor(p + (p.x + p.y) * K1);
  vec2 a = p - i + (i.x + i.y) * K2;
  vec2 o =
      (a.x > a.y)
          ? vec2(1.0, 0.0)
          : vec2(
                0.0,
                1.0); // vec2 of = 0.5 + 0.5*vec2(sign(a.x-a.y), sign(a.y-a.x));
  vec2 b = a - o + K2;
  vec2 col = a - 1.0 + 2.0 * K2;
  vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(col, col)), 0.0);
  vec3 n = h * h * h * h *
           vec3(dot(a, hash22(i + 0.0)), dot(b, hash22(i + o)),
                dot(col, hash22(i + 1.0)));
  return dot(n, vec3(70.0));
}

float fbm(vec2 n) {
  float total = 0.0, amplitude = 0.1;
  for (int i = 0; i < 7; i++) {
    total += simplexNoise(n) * amplitude;
    n = m * n;
    amplitude *= 0.4;
  }
  return total;
}

// -----------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv0 = fragCoord.xy / resolution.xy;
  vec2 uv = fragCoord.xy / resolution.xy;
  uv.x *= resolution.x / resolution.y;
  float Time = time * _speed;
  float fbmValue = fbm(uv * _cloudscale * 0.5);

  // ridged noise shape    (0.8x0.7x0.7)
  float ridgedShape = 0.0;
  vec2 uv1 = uv;
  uv1 *= _cloudscale;
  uv1 -= fbmValue - Time;
  float weight = 0.8;
  for (int i = 0; i < 8; i++) {
    ridgedShape += abs(weight * simplexNoise(uv1));
    uv1 = m * uv1 + Time;
    weight *= 0.7;
  }
  // noise shape   (0.7x0.6x0.6)
  float shape = 0.0;
  vec2 uv2 = uv;
  uv2 *= _cloudscale;
  uv2 -= fbmValue - Time;
  weight = 0.7;
  for (int i = 0; i < 8; i++) {
    shape += weight * simplexNoise(uv2);
    uv2 = m * uv2 + Time;
    weight *= 0.6;
  }

  shape *= ridgedShape + shape;

  // noise colour  (x2)
  float col = 0.0;
  Time = time * _speed * 2.0;
  vec2 uv3 = uv;
  uv3 *= _cloudscale * 2.0;
  uv3 -= fbmValue - Time;
  weight = 0.4;
  for (int i = 0; i < 7; i++) {
    col += weight * simplexNoise(uv3);
    uv3 = m * uv3 + Time;
    weight *= 0.6;
  }
  // noise ridge colour    (x3)
  float ridgeCol = 0.0;
  Time = time * _speed * 3.0;
  vec2 uv4 = uv;
  uv4 *= _cloudscale * 3.0;
  uv4 -= fbmValue - Time;
  weight = 0.4;
  for (int i = 0; i < 7; i++) {
    ridgeCol += abs(weight * simplexNoise(uv4));
    uv4 = m * uv4 + Time;
    weight *= 0.6;
  }

  col += ridgeCol;

  vec3 skyCol = mix(_skycolour2, _skycolour1, uv0.y);
  vec3 cloudCol =
      vec3(1.1, 1.1, 0.9) * clamp((_clouddark + _cloudlight * col), 0.0, 1.0);

  shape = _cloudcover + _cloudalpha * shape * ridgedShape;

  vec3 res = mix(skyCol, clamp(_skytint * skyCol + cloudCol, 0.0, 1.0),
                 clamp(shape + col, 0.0, 1.0));
  fragColor = vec4(res, 1.0);
}

out vec4 fragColour;
void main() { mainImage(fragColour, gl_FragCoord.xy); }
