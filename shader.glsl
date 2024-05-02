// Inspiration and reference from https://www.youtube.com/watch?v=Qz0KTGYJtUk

const int MAX_BOUNCES = 5;
const int RAYS_PER_PIXEL = 200;
const vec3 AMBIENT_LIGHTING = vec3(0,0,.01);
const float PI = 3.14159265;

struct Emission {
    vec3 color;
    float strength;
};

struct Material {
    vec3 color;
    Emission emission;
    float roughness;
};


// Sphere (p-pos)^2 = r^2
struct Sphere {
    vec3 pos;
    float r;
    Material mat;
};

// implicit plane equation n*p-D=0
struct Plane {
    vec3 n;
    float D;
    Material mat;
};

struct Ray {
    vec3 origin;
    vec3 dir;
};

struct Hit {
    int type;
    float dist;
    vec3 normal;
    vec3 point;
    Material mat;
};

struct PointLight {
    vec3 pos;
    vec3 color;
    float strength;
};

struct World {
    Sphere[3] spheres;
    Plane[6] planes;
};


World world = World(
    Sphere[3](
        Sphere(vec3(-.5, .2, .3), 0.3, Material(vec3(1), Emission(vec3(0), 0.), 0.)),      // Moving sphere
        Sphere(vec3(.5, -.5, .2), 0.2, Material(vec3(1), Emission(vec3(1,1,0), 1.), 1.)), // Glowing sphere
        Sphere(vec3(.2, .6, 0.18), .18, Material(vec3(1), Emission(vec3(1), 0.), .65))     // Metal sphere
    ),
    Plane[6](
        Plane(normalize(vec3(.0, .0, 1.)), .0, Material(vec3(1), Emission(vec3(0), 0.), 1.)),       // Floor
        Plane(normalize(vec3(.0, .0, -1.)), -1., Material(vec3(1), Emission(vec3(1), .5), 1.)),     // Ceiling
        Plane(normalize(vec3(1., .0, .0)), -1., Material(vec3(0,1,0), Emission(vec3(0), 0.), 1.)),  // Right wall
        Plane(normalize(vec3(-1., .0, .0)), -1., Material(vec3(1,0,0), Emission(vec3(0), 0.), .5)), // Left wall
        Plane(normalize(vec3(.0, 1., .0)), -1., Material(vec3(1), Emission(vec3(0), 0.), .0)),      // Back wall
        Plane(normalize(vec3(.0, -1., .0)), -1., Material(vec3(0,0,1), Emission(vec3(0), 0.), 1.))  // Front wall
    )
);


PointLight pointLight = PointLight(
    vec3(0,0,.9),
    vec3(1),
    .03
);

// test ray against a sphere
float sphere(in Sphere sph, in vec3 ro, in vec3 rd) {
    float t = -1.0;
    ro -= sph.pos;
    float r = sph.r;
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r * r;
    float h = b * b - c;
    if (h >= 0.0)
        t = (-b - sqrt(h));
    if (t < 0.0)
        t = (-b + sqrt(h));
    return t;
}

// test ray against xy plane
float plane(in Plane p, in vec3 ro, in vec3 rd) {
    return (p.D - dot(ro, p.n)) / dot(rd, p.n);
}

// Check for collisions
Hit rayCast(in vec3 ro, in vec3 rd) {
    Hit hit = Hit(-1, 1000.0, vec3(0), vec3(0), Material(vec3(1), Emission(vec3(0), 0.), 1.));

    // Loop through all spheres
    for (int i = 0; i < world.spheres.length(); ++i) {
        float s = sphere(world.spheres[i], ro, rd);
        if (s > 0.0 && s < hit.dist) {
            hit.dist = s;
            hit.type = 1;
            hit.normal = normalize((ro + hit.dist * rd)-world.spheres[i].pos);
            hit.point = ro + rd * hit.dist;
            hit.mat = world.spheres[i].mat;
        }
    }

    // Loop through all planes
    for (int i = 0; i < world.planes.length(); ++i) {
        float p = plane(world.planes[i], ro, rd);
        if (p > 0.0 && p < hit.dist && dot(rd, world.planes[i].n) < 0.) {
            hit.type = 2;
            hit.dist = p;
            hit.normal = normalize(world.planes[i].n);
            hit.point = ro + rd * hit.dist;
            hit.mat = world.planes[i].mat;
        }
    }

    return hit;
}

// Add percentage of an offset to a min value with a specified speed
float animate(float minValue, float maxOffset, float speed) {
    return minValue + maxOffset * ((cos(iTime*speed)+1.)/2.);
}

// PCG (permuted congruential generator)
// www.pcg-random.org and www.shadertoy.com/view/XlGcRh
float randNum(inout uint seed) {
    seed = seed * uint(747796405) + uint(2891336453);
    uint result = ((seed >> ((seed >> 28) + uint(4))) ^ seed) * uint(277803737);
    result = (result >> 22) ^ result;
    return float(result) / 4294967295.;
}

// Generate a normally distributed number
float randNumNormDist(inout uint seed) {
    // Normal Distribution: https://stackoverflow.com/questions/5825680
    float rand = float(randNum(seed));
    float theta = 2. * PI * rand;
    float rho = sqrt(-2. * log(rand));
    return rho * cos(theta);
}

// Get random direction
vec3 randDir(inout uint seed) {
    // Gen random point on sphere: https://math.stackexchange.com/questions/1585975
    return normalize(vec3(
        float(randNumNormDist(seed)),
        float(randNumNormDist(seed)),
        float(randNumNormDist(seed))
    ));
}

vec3 rayTrace(Ray ray, inout uint seed) {
    vec3 totalLighting = vec3(0); // Start with no light
    vec3 rayColor = vec3(1); // Start with all color, ie white
    
    for (int i = 0; i < MAX_BOUNCES; i++) { // Preform multiple bounces
        Hit hit = rayCast(ray.origin, ray.dir); // Check for collisions

        // Ensure an object was a hit
        if (hit.type == -1)
            break; // Didn't hit anything, can't bounce anymore


        // Update ray origin for next ray trace
        ray.origin = hit.point + hit.normal * .00001; // Move out along normal to prevent self collision


        // Handle point lights
        vec3 pointLighting = vec3(0); // Starts with no light
        vec3 pointLightDiff = pointLight.pos - ray.origin;
        float pointLightDist = length(pointLightDiff);
        vec3 pointLightDir = normalize(pointLightDiff);
        Hit pointLightHit = rayCast(ray.origin, pointLightDir);
        
        // Make sure light is not blocked
        if (pointLightHit.type == -1 || pointLightHit.dist > pointLightDist) {
            float lambert = dot(hit.normal, pointLightDir); // Strength of light depends on it's angle
            pointLighting = pointLight.color * pointLight.strength * lambert;
        }
        
        
        // Handle Emission lighting
        vec3 emissionLighting = hit.mat.emission.color * hit.mat.emission.strength;
        
        // Combine all lighting and color
        totalLighting += (emissionLighting + AMBIENT_LIGHTING + pointLighting) * rayColor;


        // Setup ray direction for next ray trace
        
        
        // Get a random reflection direction. Distribution of rays is denser
        // around surface normal to emulate Lambert's cosine law.
        vec3 diffuseDir = normalize(hit.normal + randDir(seed));

        // Calculate the perfect reflection
        vec3 perfectReflectDir = reflect(ray.dir, hit.normal);
        
        // Move towards a perfect reflection depending on roughness
        ray.dir = mix(diffuseDir, perfectReflectDir, 1. - hit.mat.roughness);
        
        rayColor *= hit.mat.color; // Update color for next ray trace
    }
    
    return totalLighting;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    // Screen uv in (-1, 1)
    vec2 uv = fragCoord.xy / iResolution.xy * 2.0 - 1.0;

    // Depth from optical center to image plane
    float d = 1.1;
    vec3 ray_origin = vec3(
        cos(iTime * -0.2) * d,
        sin(iTime * -0.2) * d,
        0.5
    );
    ray_origin.z = animate(.2, .4, .25);
    vec3 target = vec3(0.0, 0.0, 0.25);
    vec3 up = vec3(0.0,0.0,1.0);
    vec3 cam_forward = normalize(target - ray_origin);
    vec3 cam_right = normalize(cross(cam_forward, up));
    vec3 cam_up = normalize(cross(cam_forward, cam_right));
    vec3 ray_direction = normalize(uv.x * (iResolution.x / iResolution.y)
        * cam_right - uv.y * cam_up + 2.0 * cam_forward);

    // Animation
    world.spheres[0].pos.z = animate(.3, .4, 1.);
    //world.spheres[0].pos.x = animate(-.5, 1., .5);
    
    // Use pixel index as random seed so that each ray trace has different seed
    uint randSeed = uint((fragCoord.y * iResolution.x + fragCoord.x) * (iTime + 1.));
    // randSeed = uint(30); // looks cool when using constant seed

    // Average lighting from each ray traced
    vec3 avgLight;
    for (int i = 0; i < RAYS_PER_PIXEL; i++)
        avgLight += rayTrace(Ray(ray_origin, ray_direction), randSeed);
    avgLight /= float(RAYS_PER_PIXEL);
    
    // Set lighting
    fragColor = vec4(avgLight, 1);
    
    // No lighting or materials, just color
    //fragColor = vec4(rayCast(ray_origin, ray_direction).mat.color, 1.);
    
    // Test randNum function
    //fragColor = vec4(
    //    randNum(randSeed),
    //    randNum(randSeed),
    //    randNum(randSeed),
    //    1
    //);
}
