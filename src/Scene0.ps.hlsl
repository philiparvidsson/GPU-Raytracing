/*-------------------------------------
 * STRUCTS
 *-----------------------------------*/

struct PS_INPUT {
  float4 pos      : POSITION0;
  float4 screenPos: SV_POSITION;
  float2 texCoord : TEXCOORD0;
};

struct PS_OUTPUT {
  float4 color: SV_TARGET;
};

struct MATERIAL {
  float3 a; // Ambient
  float3 d; // Diffuse
  float3 s; // Specular
  float  k; // Shininess
};

struct ISECT {
  int id;

  float3 p;
  float3 n;
  float t;

  MATERIAL m;
};

struct RAY {
  float3 o;
  float3 d;
};

/*-------------------------------------
 * GLOBALS/CONSTANTS
 *-----------------------------------*/

SamplerState TextureSampler {
  AddressU = Wrap;
  AddressV = Wrap;
  Filter   = MIN_MAG_MIP_LINEAR;
};

static const float PosInf = 1.0 / 0.0;

cbuffer cbConstants: register(b1) {
  float EyeX;
  float EyeZ;
  float EyeTheta;

  float Time;
}

tbuffer tbTextures {
  Texture2D Textures[1];
}

static const int num_lights = 3;
static const int num_samples_per_light = 4;

// w coordinate is radius
static float4 lights[] = {
  float4(1.2*sin(Time*0.7), 0.2, 1.2*cos(Time*0.7), 0.2),
  float4(1.4*sin(-Time*1.3), 0.0, 1.6*cos(-Time*1.3), 0.3),
  float4(cos(Time), 0.5+0.4*sin(2.0*Time), 1.1, 0.2),
};

MATERIAL material(in float ar, in float ag, in float ab,
                  in float dr, in float dg, in float db,
                  in float sr, in float sg, in float sb,
                  in float k);

static const MATERIAL red = material(0.1, 0.0, 0.1,
                                     0.4, 0.0, 0.1,
                                     1.0, 1.0, 1.0,
                                     600.0);

static const MATERIAL green = material(0.0, 0.1, 0.15,
                                       0.0, 0.4, 0.1,
                                       1.0, 1.0, 1.0,
                                       100.0);

static const MATERIAL yellow = material(0.3, 0.1, 0.0,
                                        0.7, 0.3, 0.1,
                                        0.3, 0.3, 0.5,
                                        3.0);

static const MATERIAL white = material(0.0, 0.0, 0.0,
                                       0.7, 0.7, 0.7,
                                       0.0, 0.0, 0.0,
                                       100.0);

static const MATERIAL glow = material(0.8, 0.6, 0.4,
                                      0.2, 0.4, 0.6,
                                      0.0, 0.0, 0.0,
                                      100.0);

/*-------------------------------------
 * FUNCTIONS
 *-----------------------------------*/

float noise(in float2 x) {
  return frac(sin(dot(x, float2(12.9898, 78.233))) * 43758.5453);
}

void trace(in int id, in float3 o, in float3 d, out RAY ray, out ISECT isect);

float4 calcColor(in RAY ray, in ISECT isect) {
  MATERIAL m = isect.m;

  float3 p = isect.p;
  float3 n = isect.n;
  float3 v = normalize(p - ray.o);

  float3 color = m.a;

  RAY shadowray;
  ISECT shadowisect;

  for (int i = 0; i < num_lights; i++) {
    for (int j = 0; j < num_samples_per_light; j++) {
      float a = noise(float2(j/567.0, j/345.0) + p.xy + ray.d)*2.0*3.141592654;
      float b = noise(float2(j/123.0, j/456.0) + p.yx + ray.d)*2.0*3.141592654;
      float3 q = lights[i].w * float3(sin(a)*cos(b), sin(a)*sin(b), cos(a));
      float3 l = lights[i].xyz - p + q;

      trace(isect.id, p, l, shadowray, shadowisect);
      if (shadowisect.t > 0.0 && shadowisect.t < length(l)) {
        continue;
      }

      l = normalize(l);

      float3 r = reflect(l, n);

      float d = max(dot(l, n), 0.0);
      float s = max(dot(r, v), 0.0);

      color += (m.d*d + m.s*pow(s, m.k)) / num_samples_per_light;
    }
  }

  return float4(color, 1.0);
}

MATERIAL material(in float ar, in float ag, in float ab,
                  in float dr, in float dg, in float db,
                  in float sr, in float sg, in float sb,
                  in float k)
{
  MATERIAL m;

  m.a = float3(ar, ag, ab);
  m.d = float3(dr, dg, db);
  m.s = float3(sr, sg, sb);
  m.k = k;

  return m;
}

void plane(in int id, in RAY ray, inout ISECT isect, in float3 p, in float3 n, in MATERIAL m) {
  if (isect.id == id) {
    return;
  }

  // solve o-p+d*t . n = 0
  // (o.x - p.x + d.x*t)*n.x + (o.y - p.y + d.y*t)*n.y + (o.z - o.z + d.z*t)*n.z = 0
  // (n.x*o.x - n.x*p.x + n.x*d.x*t) + (n.y*o.y - n.y*p.y + n.y*d.y*t) + (n.z*o.z - n.z*p.z + n.y*d.z*t) = 0
  // n.x*o.x + n.x*d.x*t + n.y*o.y + n.y*d.y*t + n.z*o.z + n.y*d.z*t = n.x*p.x + n.y*p.y + n.z*p.z
  // n.x*d.x*t + n.y*d.y*t + n.z*d.z*t = n.x*p.x + n.y*p.y + n.z*p.z - n.x*o.x - n.y*o.y - n.z*o.z
  // t * (n.x*d.x + n.y*d.y + n.z*d.z) = n.x*p.x + n.y*p.y + n.z*p.z - n.x*o.x - n.y*o.y - n.z*o.z
  // t  = (n.x*p.x + n.y*p.y + n.z*p.z - n.x*o.x - n.y*o.y - n.z*o.z) / (n.x*d.x + n.y*d.y + n.z*d.z)
  float3 d = ray.d;
  float3 o = ray.o;
  float t = (dot(n, p) - dot(n, o)) / dot(n, d);

  if (t < 0.0 || t > isect.t) {
    // Already intersected with a closer object or behind camera.
    return;
  }

  isect.id = id;
  isect.t  = t;
  isect.p  = o + d*t;
  isect.n  = n;
  isect.m  = m;
}

void sphere(in int id, in RAY ray, inout ISECT isect, in float3 p, in float r, in MATERIAL m) {
  if (isect.id == id) {
    return;
  }

  float3 d = ray.d;
  float3 o = ray.o;

  float a = dot(d, d);
  float b = dot(d, o) - dot(d, p);
  float c = dot(o, o) + dot(p, p) - 2.0 * dot(o, p) - r*r;

  float i = -b/a;
  float j = -c/a + i*i;

  if (j < 0.0) {
    // No solution -> no intersection.
    return;
  }

  j = sqrt(j);

  float t0 = i + j;
  float t1 = i - j;
  float t  = min(t0, t1);

  if (t < 0.0 || t > isect.t) {
    // Already intersected with a closer object or behind camera.
    return;
  }

  isect.id = id;
  isect.t  = t;
  isect.p  = o + d*t;
  isect.n  = normalize(isect.p - p);
  isect.m  = m;
}

void trace(in int id, in float3 o, in float3 d, out RAY ray, out ISECT isect) {
  ray.o = o;
  ray.d = normalize(d);

  isect.id = id;
  isect.t  = PosInf;
  isect.n = 0.0;
  isect.p = 0.0;
  isect.m = (MATERIAL)0;

  float theta = 0.15*Time;

  float3x3 rot = {
    cos(theta), 0.0, sin(theta),
    0.0, 1.0, 0.0,
    -sin(theta), 0.0, cos(theta)
  };

  plane (1, ray, isect, float3(0.0, -0.4, 0.0), float3(0.0, 1.0, 0.0), white);
  sphere(2, ray, isect, mul(rot, float3(-0.5, 0.3, 0.0)), 0.4, red);
  sphere(3, ray, isect, mul(rot, float3( 0.5, 0.0, 0.0)),  0.4, green);
  sphere(4, ray, isect, mul(rot, float3( 0.1, -0.1, 0.8)), 0.2, yellow);

  sphere(5, ray, isect, lights[0].xyz, 0.35*lights[0].w, glow);
  sphere(6, ray, isect, lights[1].xyz, 0.35*lights[1].w, glow);
  sphere(7, ray, isect, lights[2].xyz, 0.35*lights[2].w, glow);
}


float4 traceAA(in float3 o, in float3 d) {
  RAY ray;
  ISECT isect;

  const float a = 1.0/(320.0);

  float4 color = 0.0;
  float4 prev_color = 0.0;

  /*for (int x = -k; x <= k; x++) {
    for (int y = -k; y <= k; y++) {
      trace(0, o, d + float3(a*float2(x, y), 0.0), ray, isect);

      if (!isinf(isect.t)) {
        color += calcColor(ray, isect);
      }
    }
    }*/

  int n = 1;
  float theta = 0.0;

  float4 color_sum = 0.0;
  float3 q = d;
  while (n < 8) {
    prev_color = color;

    theta += 3.141592654 * (7.0/8.0);
    q = float3(cos(theta), sin(theta), 0.0);
    trace(0, o, d + q*a, ray, isect);
    if (!isinf(isect.t)) {
      color_sum += calcColor(ray, isect);
    }

    color = color_sum/n;

    float4 qq = color - prev_color;
    float dif = dot(qq.xyz, qq.xyz);
    if (dif < 0.000001) {
      break;
    }

    n++;
  }

  return pow(color, 0.8);
  //return float4(n/16.0, 0.0, 0.0, 1.0);
}

float4 traceAperture(in float3 o, in float3 p) {
  const float a = 0.2;
  const int k = 4;

  float4 color = 0.0;

  float theta = 2.0f*3.141592654*noise(p);
  for (int i = 0; i < k; i++) {
    theta += 2.0*3.141592654 / (k-1);

    float3 ro = o + float3(a*cos(theta), a*sin(theta), 0.0);

    float3 d = p - ro;
    color += traceAA(ro, d);
  }

  return color / k;
}

void main(in PS_INPUT psIn, out PS_OUTPUT psOut) {
  float3 eye = float3(EyeX, 0.0, EyeZ);
  float a = 3.141592654 / 2.0;
  float theta = EyeTheta + a;
  float dx = cos(theta) + psIn.pos.x*cos(EyeTheta);
  float dy = psIn.pos.y;
  float dz = sin(theta) + psIn.pos.x*sin(EyeTheta);
  float3 d = float3(dx, dy, dz);
  psOut.color = traceAA(eye, d);
}
