/*-------------------------------------
 * STRUCTS
 *-----------------------------------*/

cbuffer cbConstants : register(b1) {
    float eyeX;
    float eyeZ;
    float heading;
    float time;
};

struct PS_INPUT {
    float4 pos       : POSITION0;
    float4 screenPos : SV_POSITION;
    float2 texCoord  : TEXCOORD0;
};

struct PS_OUTPUT {
    float4 color : SV_TARGET;
};

static const float PI = 3.1415926535897932;
static const float4 BG_COL = float4(1.0, 1.0, 1.0, 0.0);

static const float T_NEAR = 0.01;
static const float T_FAR  = 99999.0;

static const int NUM_LIGHT_SAMPLES = 16;

static const int MAT_AMBIENT    = 0;
static const int MAT_DIFFUSE    = 1;
static const int MAT_REFLECTIVE = 2;
static const int MAT_REFRACTIVE = 3;
static const int MAT_SPECULAR   = 4;

struct lightT {
    float  i; // Intensity
    float3 p; // Position
    float  r; // Radius

    static lightT create(float3 p, float i, float r) {
        lightT light;

        light.i = i;
        light.p = p;
        light.r = r;

        return light;
    }
};

static const int NUM_LIGHTS = 4;
static const lightT lights[NUM_LIGHTS] = {
    lightT::create(float3(-0.4+cos(time*1.11), 0.5, -0.2+sin(time*1.11)), 0.22, 0.1),
    lightT::create(float3( 0.8, 0.1, 0.4), 0.22, 0.1),
    lightT::create(float3( -0.2, 0.6, 0.1), 0.22, 0.1),
    lightT::create(float3( 0.2, 0.4, -0.5), 0.22, 0.1)
};

float rand(float2 x) {
    return frac(sin(dot(x, float2(12.9898, 78.233)))*43758.5453);
}

struct materialT {
    float3 a; // Ambient
    float3 d; // Diffuse
    float3 s; // Specular
    float  k; // Shininess
    float  r; // Reflectiveness;
    int    t; // Type.
};

struct intersectionT {
    materialT m;
    float3    n;    // Normal
    float3    p;    // Position
    float     t0;   // Near
    float     t1;   // Far
};

struct rayT {
    float3 d; // Direction
    float3 o; // Origin

    static rayT create(float3 o, float3 d) {
        rayT ray;

        ray.d = normalize(d);
        ray.o = o;

        return ray;
    }
};

float3 calcColorNoRecurse(rayT r, intersectionT x);

intersectionT trace(rayT r);
intersectionT traceNoRefractive(rayT r);

struct ambientMaterialT {
    static float3 calcColor(rayT r, intersectionT x) {
        return x.m.a;
    }

    static materialT create(float ar, float ag, float ab) {
        materialT material;

        material.a = float3(ar, ag, ab);
        material.d = float3(0.0, 0.0, 0.0);
        material.s = float3(0.0, 0.0, 0.0);
        material.k = 0.0;
        material.r = 0.0;
        material.t = MAT_AMBIENT;

        return material;
    }
};

struct diffuseMaterialT {
    static float3 calcColor(rayT r, intersectionT x) {
        float d = 0.0; // Diffuse intensity

        for (int i = 0; i < NUM_LIGHTS; i++) {
            lightT light = lights[i];

            for (int j = 1; j <= NUM_LIGHT_SAMPLES; j++) {
                float3 q = 2.0*float3(rand(j*r.d.xy), rand(j*r.o.xy), rand(j*r.d.xy + r.o.xy)) - 1.0;
                float3 l = light.p - x.p + q*light.r;
                rayT rShadow = rayT::create(x.p, l);
                intersectionT xShadow = trace(rShadow);

                if (xShadow.t0 >= T_NEAR && xShadow.t0 <= length(l)) {
                    continue;
                }

                l = normalize(l);

                d += light.i*max(dot(l, x.n), 0.0);
            }
        }

        return x.m.a + d*x.m.d/NUM_LIGHT_SAMPLES;
    }

    static materialT create(float ar, float ag, float ab,
                            float dr, float dg, float db)
    {
        materialT material;

        material.a = float3(ar, ag, ab);
        material.d = float3(dr, dg, db);
        material.s = float3(0.0, 0.0, 0.0);
        material.k = 0.0;
        material.r = 0.0;
        material.t = MAT_DIFFUSE;

        return material;
    }
};

struct specularMaterialT {
    static float3 calcColor(rayT r, intersectionT x) {
        float d = 0.0; // Diffuse intensity
        float s = 0.0; // Specular intensity

        float3 n = x.n;
        float3 p = x.p;
        float3 v = normalize(x.p - r.o);

        for (int i = 0; i < NUM_LIGHTS; i++) {
            lightT light = lights[i];

            for (int j = 1; j <= NUM_LIGHT_SAMPLES; j++) {
                float3 q = 2.0*float3(rand(j*r.d.xy), rand(j*r.o.xy), rand(j*r.d.xy + r.o.xy)) - 1.0;
                float3 l = light.p - p + q*light.r;
                rayT rShadow = rayT::create(p, l);
                intersectionT xShadow = trace(rShadow);
                if (xShadow.t0 >= T_NEAR && xShadow.t0 <= length(l)) {
                    continue;
                }

                l = normalize(l);
                float3 lr = reflect(l, n);

                d += light.i*max(dot(l, n), 0.0);
                s += light.i*pow(max(dot(lr, v), 0.0), x.m.k);
            }
        }

        return x.m.a + (d*x.m.d + s*x.m.s)/NUM_LIGHT_SAMPLES;
    }

    static materialT create(float ar, float ag, float ab,
                            float dr, float dg, float db,
                            float sr, float sg, float sb,
                            float k)
    {
        materialT material;

        material.a = float3(ar, ag, ab);
        material.d = float3(dr, dg, db);
        material.s = float3(sr, sg, sb);
        material.k = k;
        material.r = 0.0;
        material.t = MAT_SPECULAR;

        return material;
    }
};


struct reflectiveMaterialT {
    static float3 calcColor(rayT r, intersectionT x) {
        float3 v = normalize(x.p - r.o);
        rayT rReflect = rayT::create(x.p, reflect(v, x.n));
        intersectionT xReflect = trace(rReflect);

        float3 a = calcColorNoRecurse(rReflect, xReflect);
        float3 b = specularMaterialT::calcColor(r, x);
        float  d = 0.8;

        return pow(a, 1.2) + b;
    }

    static materialT create(float ar, float ag, float ab,
                            float dr, float dg, float db,
                            float sr, float sg, float sb,
                            float k, float r)
    {
        materialT material;

        material.a = float3(ar, ag, ab);
        material.d = float3(dr, dg, db);
        material.s = float3(sr, sg, sb);
        material.k = k;
        material.r = r;
        material.t = MAT_REFLECTIVE;

        return material;
    }
};

struct refractiveMaterialT {
    static float3 calcColor(rayT r, intersectionT x) {
        float3 n = x.n;

        float cosI = dot(r.d, n);
        float n1, n2;

        if (cosI > 0.0) {
            n1 = 1.33;
            n2 = 1.0;

            n = -n;
        }
        else {
            n1 = 1.0;
            n2 = 1.33;

            cosI = -cosI;
        }

        float cosT = 1.0 - pow(n1/n2, 2.0)*(1.0 - pow(cosI, 2.0));

        if (cosT < 0.0) {
            return reflectiveMaterialT::calcColor(r, x) + specularMaterialT::calcColor(r, x);
        }

        cosT = sqrt(cosT);

        float R = pow((n1*cosI - n2*cosT)/(n1*cosI + n2*cosT), 2.0) + pow((n2*cosI - n1*cosT)/(n1*cosT + n2*cosI), 2.0);

        float3 d = r.d*(n1/n2) + x.n*((n1/n2)*cosI - cosT);
        rayT rRefract = rayT::create(x.p, d);
        intersectionT xRefract = traceNoRefractive(rRefract);

        return 0.8*calcColorNoRecurse(rRefract, xRefract) + 0.2*reflectiveMaterialT::calcColor(r, x) + specularMaterialT::calcColor(r, x);
    }

    static materialT create(float ar, float ag, float ab,
                            float dr, float dg, float db,
                            float sr, float sg, float sb,
                            float k, float r)
    {
        materialT material;

        material.a = float3(ar, ag, ab);
        material.d = float3(dr, dg, db);
        material.s = float3(sr, sg, sb);
        material.k = k;
        material.r = r;
        material.t = MAT_REFRACTIVE;

        return material;
    }
};

static const materialT blue = diffuseMaterialT::create(0.2, 0.5, 0.7,
                                                       0.1, 0.5, 1.0);

static const materialT green = specularMaterialT::create(0.2, 0.4, 0.3,
                                                         0.1, 0.7, 0.4,
                                                         1.0, 1.0, 1.0,
                                                         50.0);

static const materialT reflective = reflectiveMaterialT::create(0.0, 0.0, 0.0,
                                                                0.0, 0.0, 0.0,
                                                                5.0, 5.0, 5.0,
                                                                500.0,
                                                                0.5);

static const materialT refractive = refractiveMaterialT::create(0.0, 0.0, 0.0,
                                                                0.0, 0.0, 0.0,
                                                                5.0, 5.0, 5.0,
                                                                300.0,
                                                                0.5);

static const materialT violet = diffuseMaterialT::create(0.15, 0.1, 0.2,
                                                         0.3, 0.3, 0.3);

static const materialT white = specularMaterialT::create(0.4, 0.4, 0.6,
                                                         1.0, 1.0, 1.0,
                                                         1.0, 1.0, 1.0,
                                                         100.0);

static const materialT yellow = diffuseMaterialT::create(0.7, 0.4, 0.2,
                                                         1.0, 0.6, 0.1);

struct planeT {
    materialT m;
    float3    n; // Normal
    float3    p; // Position

    static planeT create(float3 p, float3 n, materialT m) {
        planeT plane;

        plane.m = m;
        plane.n = n;
        plane.p = p;

        return plane;
    }

    void intersect(rayT r, inout intersectionT x) {
        // (o - p + d*t) . n = 0
        // (o.x - p.x + d.x*t) * n.x + (o.y - p.y + d.y*t) * n.y + (o.z - p.z + d.z*t) * n.z = 0
        // n.x*o.x - n.x*p.x + n.x*d.x*t + n.y*o.y - n.y*p.y + n.y*d.y*t + n.z*o.z - n.z*p.z + n.z*d.z*t = 0
        // n.x*o.x + n.x*d.x*t + n.y*o.y + n.y*d.y*t + n.z*o.z + n.z*d.z*t = n.x*p.x + n.y*p.y + n.z*p.z
        // n.x*d.x*t + n.y*d.y*t + n.z*d.z*t = n.x*p.x + n.y*p.y + n.z*p.z - n.x*o.x - n.y*o.y - n.z*o.z
        // t*(n.x*d.x + n.y*d.y + n.z*d.z) = n.x*p.x + n.y*p.y + n.z*p.z - n.x*o.x - n.y*o.y - n.z*o.z
        // t = (n.x*p.x + n.y*p.y + n.z*p.z - n.x*o.x - n.y*o.y - n.z*o.z)/(n.x*d.x + n.y*d.y + n.z*d.z)
        // t = (n . p - n . o)/(n . d)
        float t = (dot(n, p) - dot(n, r.o)) / dot(n, r.d);

        if (t <= T_NEAR || t >= x.t0) {
            return;
        }

        x.m  = m;
        x.n  = n;
        x.p  = r.o + r.d*t;
        x.t0 = t;
        x.t1 = t;
    }
};

struct sphereT {
    materialT m;
    float3    p; // Position
    float     r; // Radius

    static sphereT create(float3 p, float r, materialT m) {
        sphereT sphere;

        sphere.m = m;
        sphere.p = p;
        sphere.r = r;

        return sphere;
    }

    void intersect(rayT r, inout intersectionT x) {
        float3 d = r.d;
        float3 o = r.o;
        float  a = dot(d, d);
        float  b = dot(d, o) - dot(d, p);
        float  c = dot(o, o) + dot(p, p) - 2.0*dot(o, p) - this.r*this.r;
        float  i = -b/a;
        float  j = -c/a + i*i;

        if (j < 0.0) {
            // No solution -> no intersection.
            return;
        }

        j = sqrt(j);

        float t0 = i - j;
        float t1 = i + j;

        if (t0 <= T_NEAR || t0 >= x.t0) {
            return;
        }

        x.m  = m;
        x.p  = o + d*t0;
        x.n  = normalize(x.p - p);
        x.t0 = t0;
        x.t1 = t1;
    }
};

static const int NUM_PLANES = 6;
static const planeT planes[NUM_PLANES] = {
    planeT::create(float3( 0.0, 0.0,  0.0), float3( 0.0,  1.0,  0.0), violet),
    planeT::create(float3( 0.0, 2.0,  0.0), float3( 0.0, -1.0,  0.0), violet),
    planeT::create(float3(-2.0, 0.0,  0.0), float3( 1.0,  0.0,  0.0), violet),
    planeT::create(float3( 2.0, 0.0,  0.0), float3(-1.0,  0.0,  0.0), violet),
    planeT::create(float3( 0.0, 0.0, -2.0), float3( 0.0,  0.0,  1.0), violet),
    planeT::create(float3( 0.0, 0.0,  2.0), float3( 0.0,  0.0, -1.0), violet)
};

static const int NUM_SPHERES = 6;
static const sphereT spheres[NUM_SPHERES] = {
    sphereT::create(float3(0.0, 0.8, 0.0), 0.2, reflective),
    sphereT::create(float3(0.65, 0.5, 0.65), 0.15, refractive),
    sphereT::create(float3(0.7*cos(time*1.3), 0.4, 0.7*sin(time*1.3)), 0.1, white),
    sphereT::create(float3(0.95*cos(time*0.8), 0.3, 0.95*sin(time*0.8)), 0.07, blue),
    sphereT::create(float3(1.15*cos(time*1.5), 0.6, 1.15*sin(time*1.5)), 0.09, yellow),
    sphereT::create(float3(1.35*cos(time*1.4), 0.5, 1.35*sin(time*1.4)), 0.09, green)
};

float3 calcColor(rayT r, intersectionT x) {
    if (x.t0 >= T_FAR) {
        return BG_COL;
    }

    switch (x.m.t) {
    case MAT_AMBIENT: return ambientMaterialT::calcColor(r, x);
    case MAT_DIFFUSE: return diffuseMaterialT::calcColor(r, x);
    case MAT_REFLECTIVE: return reflectiveMaterialT::calcColor(r, x);
    case MAT_REFRACTIVE: return refractiveMaterialT::calcColor(r, x);
    case MAT_SPECULAR: return specularMaterialT::calcColor(r, x);
    }

    return float3(1.0, 0.0, 1.0);
}

float3 calcColorNoRecurse(rayT r, intersectionT x) {
    if (x.t0 >= T_FAR) {
        return BG_COL;
    }

    if (x.m.t == MAT_AMBIENT) return ambientMaterialT::calcColor(r, x);
    if (x.m.t == MAT_DIFFUSE) return diffuseMaterialT::calcColor(r, x);
    if (x.m.t == MAT_SPECULAR) return specularMaterialT::calcColor(r, x);

    // Some kind of recursion is really needed here but HLSL does not allow it,
    // so return the ambient color of the walls.
    return violet.a;
}

intersectionT traceNoRefractive(rayT r) {
    intersectionT x;

    x.t0 = T_FAR;

    for (int i = 0; i < NUM_PLANES; i++) {
        planes[i].intersect(r, x);
    }

    for (int i = 0; i < NUM_SPHERES; i++) {
        if (spheres[i].m.t == MAT_REFRACTIVE) {
            continue;
        }

        spheres[i].intersect(r, x);
    }

    return x;
}

intersectionT trace(rayT r) {
    intersectionT x;

    x.t0 = T_FAR;

    for (int i = 0; i < NUM_PLANES; i++) {
        planes[i].intersect(r, x);
    }

    for (int i = 0; i < NUM_SPHERES; i++) {
        spheres[i].intersect(r, x);
    }

    return x;
}

void main(in PS_INPUT psIn, out PS_OUTPUT psOut) {
    float3 eye = float3(eyeX, 0.5, eyeZ);
    float a = 3.141592654 / 2.0;
    float theta = heading + a;
    float dx = cos(theta) + psIn.pos.x*cos(heading);
    float dy = psIn.pos.y;
    float dz = sin(theta) + psIn.pos.x*sin(heading);
    float3 d = float3(dx, dy, dz);

    rayT r = rayT::create(eye, d);

    intersectionT x = trace(r);
    psOut.color = float4(calcColor(r, x), 0.0);
}
