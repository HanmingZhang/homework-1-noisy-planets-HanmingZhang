#version 300 es
precision highp float;
precision mediump int;

// uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform float u_Timer;

// uniform arraies used in noise3d
uniform vec3 u_Grad3[12];
uniform int u_Perm[512];

const vec3 eyePosition = vec3(0.0, 0.0, 5.0);


// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec3 fs_Nor;
in vec4 fs_LightVec;
//in vec4 fs_Col;
in vec4 fs_mPos;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.



float fade(float t) {
    return t*t*t*(t*(t*6.0 - 15.0) + 10.0);
}

//    Faster than Perlin Quintic.  Not quite as good shape.
//    7x^3-7x^4+x^7
float Interpolation_C2_Fast( float x ) { float x3 = x*x*x; return ( 7.0 + ( x3 - 7.0 ) * x ) * x3; }


// Classic Perlin noise, 3D version
// refer from paper http://webstaff.itn.liu.se/~stegu/simplexnoise/simplexnoise.pdf
float noise3d(float x, float y, float z) {
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

void main()
{
    // Material base color (before shading)
    //vec4 diffuseColor = u_Color;

    // Calculate the diffuse term for Lambert shading
    // vec3 X = dFdx(fs_mPos.xyz);
    // vec3 Y = dFdy(fs_mPos.xyz);
    // vec3 normal=normalize(cross(X,Y));

    float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec.xyz));
    // Avoid negative lighting values
    diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);

    float ambientTerm = 0.2;

    float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                        //to simulate ambient lighting. This ensures that faces that are not
                                                        //lit by our point light are not completely black.


    // calculate specular ter
    float specularTerm = 0.0;
    vec3 refDir = reflect(normalize(eyePosition - fs_mPos.xyz), normalize(fs_Nor.xyz));

    if(dot(normalize(fs_Nor.xyz), normalize(fs_LightVec.xyz)) > 0.0){
        float specularPower = 8.0;
        specularTerm = pow(dot(refDir, normalize(fs_LightVec.xyz)), specularPower);
    }

    float perlin = noise3d(3.0 * abs(sin(u_Timer * 5.0))* refDir.x, 2.6 * refDir.y, 3.7 * refDir.z);

    // use absolute style perlin here
    vec3 color = vec3(1.0) - vec3(abs(perlin));

    float alpha = color.r;
    if(alpha < 0.164){
        alpha = 0.01;
    }

    out_Col = vec4(vec3(0.7 * specularTerm)  + vec3(1.2 * color.r, 0.215 - 0.1 * cos(u_Timer), 0.3312) * lightIntensity, 1.0);
}
