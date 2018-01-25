#version 300 es
precision highp float;

uniform vec2 u_Dimensions;
uniform float u_Timer;

uniform int u_GridSize;

in vec2 fs_UV;

out vec4 out_Col; 

uniform sampler2D u_RenderedTexture;

const vec3 a = vec3(0.4, 0.5, 0.8);
const vec3 b = vec3(0.2, 0.4, 0.2);
const vec3 c = vec3(1.0, 1.0, 2.0);
const vec3 d = vec3(0.25, 0.25, 0.0);

const vec3 e = vec3(0.2, 0.5, 0.8);
const vec3 f = vec3(0.2, 0.25, 0.5);
const vec3 g = vec3(1.0, 1.0, 0.1);
const vec3 h = vec3(0.0, 0.8, 0.2);

// Return a random direction in a circle
vec2 random2( vec2 p ) {
    return normalize(2.0 * fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453) - 1.0);
}

vec3 Gradient(float t)
{
    return a + b * cos(6.2831 * (c * t + d));
}

vec3 Gradient2(float t)
{
    return e + f * cos(6.2831 * (g * t + h));
}

float surflet(vec2 P, vec2 gridPoint)
{
    // Compute falloff function by converting linear distance to a polynomial
    float distX = abs(P.x - gridPoint.x);
    float distY = abs(P.y - gridPoint.y);
    float tX = 1.0 - 6.0 * pow(distX, 5.0) + 15.0 * pow(distX, 4.0) - 10.0 * pow(distX, 3.0);
    float tY = 1.0 - 6.0 * pow(distY, 5.0) + 15.0 * pow(distY, 4.0) - 10.0 * pow(distY, 3.0);

    // Get the random vector for the grid point
    vec2 gradient = random2(gridPoint);
    // Get the vector from the grid point to P
    vec2 diff = P - gridPoint;
    // Get the value of our height field by dotting grid->P with our gradient
    float height = dot(diff, gradient);
    // Scale our height field (i.e. reduce it) by our polynomial falloff function
    return height * tX * tY;
}

float PerlinNoise(vec2 uv)
{
    // Tile the space
    vec2 uvXLYL = floor(uv);
    vec2 uvXHYL = uvXLYL + vec2(1,0);
    vec2 uvXHYH = uvXLYL + vec2(1,1);
    vec2 uvXLYH = uvXLYL + vec2(0,1);

    return surflet(uv, uvXLYL) + surflet(uv, uvXHYL) + surflet(uv, uvXHYH) + surflet(uv, uvXLYH);
}

vec2 PixelToGrid(vec2 pixel, float size)
{
    vec2 uv = pixel.xy / u_Dimensions.xy;
    // Account for aspect ratio
    uv.x = uv.x * float(u_Dimensions.x) / float(u_Dimensions.y);
    // Determine number of cells (NxN)
    uv *= size;

    return uv;
}

void main()
{
//#define BASIC
#define SUMMED
//#define ABSOLUTE
//#define RECURSIVE1
//#define RECURSIVE2

    vec3 color;
    float time = u_Timer * 10.0;

#ifdef BASIC
    // Basic Perlin noise
    //vec2 uv = PixelToGrid(gl_FragCoord.xy, 4.0);
    vec2 uv = PixelToGrid(fs_UV, 4.0);

    float perlin = PerlinNoise(uv);
    color = vec3((perlin + 1.0) * 0.5);
    color.r += step(0.98, fract(uv.x)) + step(0.98, fract(uv.y));
#endif

#ifdef SUMMED
    float summedNoise = 0.0;
    float amplitude = 0.5;
    for(int i = 2; i <= 32; i *= 2) {
        // vec2 uv = PixelToGrid(gl_FragCoord.xy, float(i));
        vec2 uv = PixelToGrid(fs_UV, float(i));

        uv = vec2(cos(3.14159/3.0 * float(i)) * uv.x - sin(3.14159/3.0 * float(i)) * uv.y, sin(3.14159/3.0 * float(i)) * uv.x + cos(3.14159/3.0 * float(i)) * uv.y);
        float perlin = abs(PerlinNoise(uv));// * amplitude;
        summedNoise += perlin * amplitude;
        amplitude *= 0.5;
    }
    color = vec3(summedNoise);//vec3((summedNoise + 1) * 0.5);
#endif

#ifdef ABSOLUTE
    //vec2 uv = PixelToGrid(gl_FragCoord.xy, 10.0);
    vec2 uv = PixelToGrid(fs_UV, 10.0);

    float perlin = PerlinNoise(uv);
    color = vec3(1.0) - vec3(abs(perlin));
//    color.r += step(0.98, fract(uv.x)) + step(0.98, fract(uv.y));
#endif

#ifdef RECURSIVE1
    vec2 planet = vec2(cos(time * 0.01 * 3.14159), sin(time * 0.01 * 3.14159)) * 2.0 + vec2(4.0);
    //vec2 uv = PixelToGrid(gl_FragCoord.xy, 10.0);
    vec2 uv = PixelToGrid(fs_UV, 10.0);

    vec2 planetDiff = planet - uv;
    float len = length(planetDiff);
    vec2 offset = vec2(PerlinNoise(uv + time * 0.01), PerlinNoise(uv + vec2(5.2, 1.3)));
    if(len < 1.0) {
        offset += planetDiff * (1.0 - len);
    }
    float perlin = PerlinNoise(uv + offset);
    color = vec3((perlin + 1.0) * 0.5);
#endif

#ifdef RECURSIVE2
    // Recursive Perlin noise (2 levels)
    // vec2 uv = PixelToGrid(gl_FragCoord.xy, 10.0);
    vec2 uv = PixelToGrid(fs_UV, 10.0);

    vec2 offset1 = vec2(PerlinNoise(uv + cos(time * 3.14159 * 0.01)), PerlinNoise(uv + vec2(5.2, 1.3)));
    vec2 offset2 = vec2(PerlinNoise(uv + offset1 + vec2(1.7, 9.2)), PerlinNoise(uv + sin(time * 3.14159 * 0.01) + offset1 + vec2(8.3, 2.8)));
    float perlin = PerlinNoise(uv + offset2);
    vec3 baseGradient = Gradient(perlin);
    baseGradient = mix(baseGradient, vec3(perlin), length(offset1));
//    baseGradient = mix(baseGradient, Gradient2(perlin), offset2.y);
    color = baseGradient;


//    color = vec3((perlin + 1) * 0.5);
#endif
   out_Col = vec4(color, 1.0);
   //out_Col = vec4(fs_UV, 0.0, 1.0);
}
