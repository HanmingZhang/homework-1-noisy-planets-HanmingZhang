#version 300 es
precision highp float;
precision mediump int;

//uniform vec4 u_Color; // The color with which to render this instance of geometry.

uniform float u_Timer;

// uniform arraies used in noise3d
uniform vec3 u_Grad3[12];
uniform int  u_Perm[512];

const vec3 a = vec3(0.4, 0.5, 0.8);
const vec3 b = vec3(0.2, 0.4, 0.2);
const vec3 c = vec3(1.0, 1.0, 2.0);
const vec3 d = vec3(0.25, 0.25, 0.0);

const vec3 e = vec3(0.2, 0.5, 0.8);
const vec3 f = vec3(0.2, 0.25, 0.5);
const vec3 g = vec3(1.0, 1.0, 0.1);
const vec3 h = vec3(0.0, 0.8, 0.2);


// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec3 fs_Nor;
in vec4 fs_LightVec;
//in vec4 fs_Col;
in vec4 fs_mPos;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.


vec3 Gradient(float t)
{
    return a + b * cos(6.2831 * (c * t + d));
}

float fade(float t) {
    return t*t*t*(t*(t*6.0 - 15.0) + 10.0);
}

// Classic Perlin noise, 3D version
// refer from paper http://webstaff.itn.liu.se/~stegu/simplexnoise/simplexnoise.pdf
float noise3d(vec3 input_vec3) {
    float x = input_vec3.x;
    float y = input_vec3.y;
    float z = input_vec3.z;

    // Find unit grid cell containing point
    int X = int(floor(x));
    int Y = int(floor(y));
    int Z = int(floor(z));

    // Get relative xyz coordinates of point within that cell
    x = x - float(X);
    y = y - float(Y);
    z = z - float(Z);

    // Wrap the integer cells at 255 (smaller integer period can be introduced here)
    X = X & 255;
    Y = Y & 255;
    Z = Z & 255;

    // Calculate a set of eight hashed gradient indices
    int gi000 = u_Perm[X+u_Perm[Y+u_Perm[Z]]] % 12;
    int gi001 = u_Perm[X+u_Perm[Y+u_Perm[Z+1]]] % 12;
    int gi010 = u_Perm[X+u_Perm[Y+1+u_Perm[Z]]] % 12; 
    int gi011 = u_Perm[X+u_Perm[Y+1+u_Perm[Z+1]]] % 12;
    int gi100 = u_Perm[X+1+u_Perm[Y+u_Perm[Z]]] % 12;
    int gi101 = u_Perm[X+1+u_Perm[Y+u_Perm[Z+1]]] % 12;
    int gi110 = u_Perm[X+1+u_Perm[Y+1+u_Perm[Z]]] % 12;
    int gi111 = u_Perm[X+1+u_Perm[Y+1+u_Perm[Z+1]]] % 12;

    // The gradients of each corner are now:
    // g000 = grad3[gi000];
    // g001 = grad3[gi001];
    // g010 = grad3[gi010];
    // g011 = grad3[gi011];
    // g100 = grad3[gi100];
    // g101 = grad3[gi101];
    // g110 = grad3[gi110];
    // g111 = grad3[gi111];

    // Calculate noise contributions from each of the eight corners
    float n000= dot(u_Grad3[gi000], vec3(x, y, z));
    float n100= dot(u_Grad3[gi100], vec3(x-1.0, y, z));
    float n010= dot(u_Grad3[gi010], vec3(x, y-1.0, z));
    float n110= dot(u_Grad3[gi110], vec3(x-1.0, y-1.0, z));
    float n001= dot(u_Grad3[gi001], vec3(x, y, z-1.0));
    float n101= dot(u_Grad3[gi101], vec3(x-1.0, y, z-1.0));
    float n011= dot(u_Grad3[gi011], vec3(x, y-1.0, z-1.0));
    float n111= dot(u_Grad3[gi111], vec3(x-1.0, y-1.0, z-1.0));

    // Compute the fade curve value for each of x, y, z
    float u = fade(x);
    float v = fade(y);
    float w = fade(z);

    // Interpolate along x the contributions from each of the corners
    float nx00 = mix(n000, n100, u);
    float nx01 = mix(n001, n101, u);
    float nx10 = mix(n010, n110, u);
    float nx11 = mix(n011, n111, u);

    // Interpolate the four results along y
    float nxy0 = mix(nx00, nx10, v);
    float nxy1 = mix(nx01, nx11, v);

    // Interpolate the two last results along z
    float nxyz = mix(nxy0, nxy1, w);
    return nxyz;
}




// // Return a random direction in a circle
// vec2 random2( vec2 p ) 
// {
//     return normalize(2.0 * fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453) - 1.0);
// }

// vec3 Gradient(float t)
// {
//     return a + b * cos(6.2831 * (c * t + d));
// }

// vec3 Gradient2(float t)
// {
//     return e + f * cos(6.2831 * (g * t + h));
// }

// float surflet(vec2 P, vec2 gridPoint)
// {
//     // Compute falloff function by converting linear distance to a polynomial
//     float distX = abs(P.x - gridPoint.x);
//     float distY = abs(P.y - gridPoint.y);
//     float tX = 1.0 - 6.0 * pow(distX, 5.0) + 15.0 * pow(distX, 4.0) - 10.0 * pow(distX, 3.0);
//     float tY = 1.0 - 6.0 * pow(distY, 5.0) + 15.0 * pow(distY, 4.0) - 10.0 * pow(distY, 3.0);

//     // Get the random vector for the grid point
//     vec2 gradient = random2(gridPoint);
//     // Get the vector from the grid point to P
//     vec2 diff = P - gridPoint;
//     // Get the value of our height field by dotting grid->P with our gradient
//     float height = dot(diff, gradient);
//     // Scale our height field (i.e. reduce it) by our polynomial falloff function
//     return height * tX * tY;
// }

// float PerlinNoise(vec2 uv)
// {
//     // Tile the space
//     vec2 uvXLYL = floor(uv);
//     vec2 uvXHYL = uvXLYL + vec2(1,0);
//     vec2 uvXHYH = uvXLYL + vec2(1,1);
//     vec2 uvXLYH = uvXLYL + vec2(0,1);

//     return surflet(uv, uvXLYL) + surflet(uv, uvXHYL) + surflet(uv, uvXHYH) + surflet(uv, uvXLYH);
// }

// vec2 PixelToGrid(vec2 pixel, float size)
// {
//     vec2 uv = pixel.xy / u_Dimensions.xy;
//     // Account for aspect ratio
//     uv.x = uv.x * float(u_Dimensions.x) / float(u_Dimensions.y);
//     // Determine number of cells (NxN)
//     uv *= size;

//     return uv;
// }



void main()
{
    // Material base color (before shading)
    //vec4 diffuseColor = u_Color;

    vec3 inputVec3 = 5.0 * fs_mPos.xyz;

    vec3 offset1 = vec3(noise3d(inputVec3 + vec3(cos(u_Timer * 3.14159 * 0.01))), noise3d(inputVec3 + vec3(5.2, 1.3, 2.8)), noise3d(inputVec3 + vec3(sin(u_Timer * 3.14159 * 0.01))));
    vec3 offset2 = vec3(noise3d(inputVec3 + vec3(1.7, 9.2, 5.6)), noise3d(inputVec3 + vec3(sin(u_Timer * 3.14159 * 0.1)) + vec3(8.3, 1.2, 2.8)), noise3d(inputVec3));
    float perlin = noise3d(offset1 + offset2);
    vec3 baseGradient = Gradient(perlin);
    baseGradient = mix(baseGradient, vec3(perlin), length(offset1));
    vec3 color = baseGradient;
    color.r += 0.25 + 1.52 * noise3d(vec3(offset1.x, offset2.y, offset1.z));
    color.g *= 0.06;
    color.b *= 0.2 * sin(u_Timer * 3.0);


    // Calculate the diffuse term for Lambert shading
    // vec3 X = dFdx(fs_mPos.xyz);
    // vec3 Y = dFdy(fs_mPos.xyz);
    // vec3 normal=normalize(cross(X,Y));

    float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec.xyz));
    
    // Avoid negative lighting values
    diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);

    float ambientTerm = 0.06;

    float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                        //to simulate ambient lighting. This ensures that faces that are not
                                                        //lit by our point light are not completely black.




    out_Col = vec4(color * lightIntensity, 1.0);
    //out_Col = vec4(vec3(0.8, 0.1, 0.1) * lightIntensity, 1.0);
}
