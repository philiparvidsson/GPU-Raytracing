// HLSL is somewhat limited, so the order of constructs (i.e. functions,
// structs etc.) is a bit weird in this file. This serves a purpose since the
// compiler does not handle forward-references very well.
//     I've tried to make as much sense of the order as possible and I've also
// used commenting where necessary to provide a clear understanding of intent.
//
// - Philip Arvidsson
//  December 1, 2016


/*-------------------------------------
 * CONSTANTS
 *-----------------------------------*/

// These are passed into the shader through a constant buffer by the program.
cbuffer cbConstants : register(b1) {
    float eyeX;
    float eyeZ;
    float heading;
    float time;
};

// Pi is nice! :-)
static const float PI = 3.1415926535897932;

// Background color to return when a ray has no intersection.
static const float4 BG_COL = float4(1.0, 1.0, 1.0, 0.0);

// Near clip distance. There's no real unit to it, but we can imagine
// every measurement in meters to get a more intuitive understanding.
//     Any surface closer to the 'eye' than T_NEAR will be ignored.
static const float T_NEAR = 0.01;

// Far clip distance. Any surface farther from the 'eye' than T_FAR will be
// ignored.
static const float T_FAR  = 99999.0;

// Number of samples per light. Since the light sources have volumes, light
// sampling is needed to provide a good rendering of the penumbras (the part of
// the shadow which is not completely dark nor completely lit).
//     Lowering this increases performance linearly, but reduces the rendering
// quality of the penumbra.
//     This raytracer uses Monte Carlo integration for penumbras.
static const int NUM_LIGHT_SAMPLES = 16;

// Material type constants. Only used for the shader to figure out how to
// calculate final pixel colors.
static const int MAT_AMBIENT    = 0;
static const int MAT_DIFFUSE    = 1;
static const int MAT_FOG        = 2;
static const int MAT_REFLECTIVE = 3;
static const int MAT_REFRACTIVE = 4;
static const int MAT_SPECULAR   = 5;

// If you change these, you also need to change the number of created lights,
// planes or spheres in their respective constants for the shader to compile.
static const int NUM_LIGHTS  = 4;
static const int NUM_PLANES  = 6;
static const int NUM_SPHERES = 6;

/*-------------------------------------
 * CORE STUFF
 *-----------------------------------*/

// Since there are no abstract classes (for our intent, at least) in HLSL, we
// create a common struct containing everything needed for every kind of
// material. Although this wastes a bit of memory, it simplifies the pixel color
// calculation functions greatly.
struct materialT {
    float3 a; // Ambient
    float3 d; // Diffuse
    float3 s; // Specular
    float  k; // Shininess
    float  r; // Reflectiveness;
    int    t; // Material type (e.g. MAT_AMBIENT or MAT_DIFFUSE, etc.).
};

// Represents a single intersection between a ray and a surface.
struct intersectionT {
    materialT m;    // Surface material.
    float3    n;    // Surface normal
    float3    p;    // Position of intersection in world frame-of-reference.
    float     t0;   // Near intersection for quadratics.
    float     t1;   // Far intersection for quadratics (otherwise == t0)
};

// A ray cast by the raytracer, to be intersected with surfaces.
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

/*-------------------------------------
 * DECLARATIONS
 *-----------------------------------*/

// Some declarations are needed for the compiler to get the forward-references.

float3 calcColorNoRecurse(rayT r, intersectionT x);
float rand(float2 x);
intersectionT trace(rayT r);
intersectionT traceNoRefractive(rayT r);

/*-------------------------------------
 * STRUCTS
 *-----------------------------------*/

struct PS_INPUT {
    float4 pos       : POSITION0;
    float4 screenPos : SV_POSITION;
    float2 texCoord  : TEXCOORD0;
};

struct PS_OUTPUT {
    float4 color : SV_TARGET;
};

// A volume (box shaped) light source.
struct lightT {
    float  i; // Intensity as real multiple
    float3 p; // Light position in world space
    float  r; // Size of light box (width, height and depth)

    static lightT create(float3 p, float i, float r) {
        lightT light;

        light.i = i;
        light.p = p;
        light.r = r;

        return light;
    }
};

/*-------------------------------------
 * LIGHTS
 *-----------------------------------*/

static const lightT lights[NUM_LIGHTS] = {
    lightT::create(float3(-0.4+cos(time*1.11), 0.5, -0.2+sin(time*1.11)), 0.22, 0.1),
    lightT::create(float3( 0.8               , 0.1,  0.4               ), 0.22, 0.1),
    lightT::create(float3(-0.2               , 0.6,  0.1               ), 0.22, 0.1),
    lightT::create(float3( 0.2               , 0.4, -0.5               ), 0.22, 0.1)
};

/*-------------------------------------
 * MATERIALS
 *-----------------------------------*/

// Surfaces with ambient materials have no real shading, but are rather self
// illuminating.
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

// Diffuse surfaces have shading, but no specular highlight. Think of diffuse
// materials as matte surfaces, such as wood or rubber.
struct diffuseMaterialT {
    static float3 calcColor(rayT r, intersectionT x) {
        float d = 0.0; // Diffuse intensity

        for (int i = 0; i < NUM_LIGHTS; i++) {
            lightT light = lights[i];

            for (int j = 1; j <= NUM_LIGHT_SAMPLES; j++) {
                // The vector q is a random displacement for volume light sampling.
                float3 q = 2.0*float3(rand(j*r.d.xy), rand(j*r.o.xy), rand(j*r.d.xy + r.o.xy)) - 1.0;
                float3 l = light.p - x.p + q*light.r;

                // We need to trace a ray to each light source to make sure it's
                // not blocked by another surface. If it is, we're in a shadow.

                rayT rShadow = rayT::create(x.p, l);
                intersectionT xShadow = trace(rShadow);

                if (xShadow.t0 >= T_NEAR && xShadow.t0 <= length(l)) {
                    continue;
                }

                d += light.i*max(dot(normalize(l), x.n), 0.0);
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

// Provides a fog-like material. The model I've implemented has no basis in
// physical reality, but is rather a result of experimenting and having fun. It
// looks ok but could probably be improved upon.
//     It basically measures the thickness of the material in the ray direction
// and calculates color transparency from it.
struct fogMaterialT {
    static float3 calcColor(rayT r, intersectionT x) {
        float d = 0.0; // Diffuse intensity

        rayT rPassthrough = rayT::create(r.o + r.d*x.t1, r.d);
        intersectionT xPassthrough = trace(rPassthrough);

        for (int i = 0; i < NUM_LIGHTS; i++) {
            lightT light = lights[i];

            for (int j = 1; j <= NUM_LIGHT_SAMPLES; j++) {
                // The vector q is a random displacement for volume light sampling.
                float3 q = 2.0*float3(rand(j*r.d.xy), rand(j*r.o.xy), rand(j*r.d.xy + r.o.xy)) - 1.0;
                float3 l = light.p - x.p + q*light.r;

                // We need to trace a ray to each light source to make sure it's
                // not blocked by another surface. If it is, we're in a shadow.

                rayT rShadow = rayT::create(x.p, l);
                intersectionT xShadow = trace(rShadow);

                if (xShadow.t0 >= T_NEAR && xShadow.t0 <= length(l)) {
                    continue;
                }

                d += light.i;
            }
        }

        float a = 1.0 - pow(tanh(10.0*(x.t1 - x.t0)), 8.0);
        return a*calcColorNoRecurse(rPassthrough, xPassthrough) + (1.0 - a)*(x.m.a + d*x.m.d)/NUM_LIGHT_SAMPLES;
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
        material.t = MAT_FOG;

        return material;
    }
};

// Specular materials provide a diffuse base material plus a specular highlight
// component. Think of specular materials as glass or metal.
//     The specular material below implements the Phong shading model.
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
                // The vector q is a random displacement for volume light sampling.
                float3 q = 2.0*float3(rand(j*r.d.xy), rand(j*r.o.xy), rand(j*r.d.xy + r.o.xy)) - 1.0;
                float3 l = light.p - p + q*light.r;

                // Check for shadows.
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

// The reflective material is a mix of a specular material and a reflection of
// the surface environment (tracing a second ray to sample its environment).
//     A mirror is a perfect example of a reflective material.
struct reflectiveMaterialT {
    static float3 calcColor(rayT r, intersectionT x) {
        float3 v = normalize(x.p - r.o);
        rayT rReflect = rayT::create(x.p, reflect(v, x.n));
        intersectionT xReflect = trace(rReflect);

        float3 a = calcColorNoRecurse(rReflect, xReflect);
        float3 b = specularMaterialT::calcColor(r, x);
        float  d = 0.8; // Wanted x.m.r here, but compiler dies. Compiler bug.

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

// Refractive surfaces allow light to pass through, but refracts light rays
// depending on the difference in refractive index between the two mediums.
//     Water is a perfect example of a refractive material.
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

// Go ahead and play with the material definitions below!

static const materialT blue = diffuseMaterialT::create(0.2, 0.5, 0.7,
                                                       0.1, 0.5, 1.0);

static const materialT green = specularMaterialT::create(0.2, 0.4, 0.3,
                                                         0.1, 0.7, 0.4,
                                                         1.0, 1.0, 1.0,
                                                         50.0);

static const materialT reflective = reflectiveMaterialT::create(0.0, 0.0, 0.0,
                                                                0.0, 0.0, 0.0,
                                                                5.0, 5.0, 5.0,
                                                                300.0,
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

static const materialT yellow = fogMaterialT::create(0.8, 0.4, 0.1,
                                                     1.0, 0.6, 0.1);
/*-------------------------------------
 * SURFACES
 *-----------------------------------*/

// A plane consists of a position and a normal. It is also infinite, meaning the
// position and normal define an infinite spanning plane in 3-space.
struct planeT {
    materialT m; // Material
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
        // We need to solve the following: (o - p + d*) . n = 0
        // Rewriting with vector components:
        // (o.x - p.x + d.x*t) * n.x + (o.y - p.y + d.y*t) * n.y + (o.z - p.z + d.z*t) * n.z = 0
        // n.x*o.x - n.x*p.x + n.x*d.x*t + n.y*o.y - n.y*p.y + n.y*d.y*t + n.z*o.z - n.z*p.z + n.z*d.z*t = 0
        // n.x*o.x + n.x*d.x*t + n.y*o.y + n.y*d.y*t + n.z*o.z + n.z*d.z*t = n.x*p.x + n.y*p.y + n.z*p.z
        // n.x*d.x*t + n.y*d.y*t + n.z*d.z*t = n.x*p.x + n.y*p.y + n.z*p.z - n.x*o.x - n.y*o.y - n.z*o.z
        // t*(n.x*d.x + n.y*d.y + n.z*d.z) = n.x*p.x + n.y*p.y + n.z*p.z - n.x*o.x - n.y*o.y - n.z*o.z
        // t = (n.x*p.x + n.y*p.y + n.z*p.z - n.x*o.x - n.y*o.y - n.z*o.z)/(n.x*d.x + n.y*d.y + n.z*d.z)
        // So we get the following solution:
        // t = (n . p - n . o)/(n . d)
        float t = (dot(n, p) - dot(n, r.o)) / dot(n, r.d);

        if (t <= T_NEAR || t >= x.t0) {
            return;
        }

        x.m  = m;
        x.n  = n;
        x.p  = r.o + r.d*t;
        x.t0 = t;
        x.t1 = t; // Planes have no thickness, so t1=t0.
    }
};

// A sphere consists of a position and radius.
struct sphereT {
    materialT m; // Material
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
            // No solution means no intersection.
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

// You can change the scene by modifying the placement of surfaces below.

static const planeT planes[NUM_PLANES] = {
    planeT::create(float3( 0.0, 0.0,  0.0), float3( 0.0,  1.0,  0.0), violet),
    planeT::create(float3( 0.0, 2.0,  0.0), float3( 0.0, -1.0,  0.0), violet),
    planeT::create(float3(-2.0, 0.0,  0.0), float3( 1.0,  0.0,  0.0), violet),
    planeT::create(float3( 2.0, 0.0,  0.0), float3(-1.0,  0.0,  0.0), violet),
    planeT::create(float3( 0.0, 0.0, -2.0), float3( 0.0,  0.0,  1.0), violet),
    planeT::create(float3( 0.0, 0.0,  2.0), float3( 0.0,  0.0, -1.0), violet)
};

static const sphereT spheres[NUM_SPHERES] = {
    sphereT::create(float3(0.0               , 0.8, 0.0               ), 0.2 , reflective),
    sphereT::create(float3(0.65              , 0.5, 0.65              ), 0.15, refractive),
    sphereT::create(float3(0.7*cos(time*1.3) , 0.4, 0.7*sin(time*1.3) ), 0.1 , white     ),
    sphereT::create(float3(0.95*cos(time*0.8), 0.3, 0.95*sin(time*0.8)), 0.07, blue      ),
    sphereT::create(float3(1.15*cos(time*1.5), 0.6, 1.15*sin(time*1.5)), 0.09, yellow    ),
    sphereT::create(float3(1.35*cos(time*1.4), 0.5, 1.35*sin(time*1.4)), 0.09, green     )
};

/*-------------------------------------
 * FUNCTIONS
 *-----------------------------------*/

// One liner for pseudo-random numbers in HLSL shaders.
float rand(float2 x) {
    return frac(sin(dot(x, float2(12.9898, 78.233)))*43758.5453);
}

// Calculates the final color of a ray and its intersection with a surface.
float3 calcColor(rayT r, intersectionT x) {
    if (x.t0 >= T_FAR) {
        return BG_COL;
    }

    switch (x.m.t) {
    case MAT_AMBIENT    : return ambientMaterialT::calcColor(r, x);
    case MAT_DIFFUSE    : return diffuseMaterialT::calcColor(r, x);
    case MAT_FOG        : return fogMaterialT::calcColor(r, x);
    case MAT_REFLECTIVE : return reflectiveMaterialT::calcColor(r, x);
    case MAT_REFRACTIVE : return refractiveMaterialT::calcColor(r, x);
    case MAT_SPECULAR   : return specularMaterialT::calcColor(r, x);
    }

    // This should never happen unless we encounter an unknown material.
    return float3(1.0, 0.0, 1.0);
}

// Calculates the final color of a ray and its intersection with a surface.
float3 calcColorNoRecurse(rayT r, intersectionT x) {
    if (x.t0 >= T_FAR) {
        return BG_COL;
    }

    // Using a switch statement fails here. Seems to be a compiler bug.
    if (x.m.t == MAT_AMBIENT ) return ambientMaterialT::calcColor(r, x);
    if (x.m.t == MAT_DIFFUSE ) return diffuseMaterialT::calcColor(r, x);
    if (x.m.t == MAT_SPECULAR) return specularMaterialT::calcColor(r, x);

    // Some kind of recursion is really needed here but HLSL does not allow it,
    // so return the ambient color of the walls.
    return violet.a;
}

// Traces a single ray and finds the nearest intersection.
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

// Traces a single ray and finds the nearest intersection. Ignores refractive
// surfaces. Again a hack to avoid recursion.
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

void main(in PS_INPUT psIn, out PS_OUTPUT psOut) {
    // The direction to point the eye in, given by the C# program.
    float theta = heading + PI/2.0;

    // Calculating the direction in Cartesian coordinates here.
    float dx = cos(theta) + psIn.pos.x*cos(heading);
    float dy = psIn.pos.y;
    float dz = sin(theta) + psIn.pos.x*sin(heading);

    // Trace the race...
    rayT r = rayT::create(float3(eyeX, 0.5, eyeZ), float3(dx, dy, dz));
    intersectionT x = trace(r);

    // ...and we're done! (with one pixel..! :-) )
    psOut.color = float4(calcColor(r, x), 0.0);
}
