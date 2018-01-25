#version 300 es
precision highp float;
precision mediump int;

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself
uniform float u_Timer;
uniform float u_TimeScale;
uniform float u_FinalNoiseScale;

// uniform arraies used in noise3d
uniform vec3 u_Grad3[12];
uniform int u_Perm[512];


in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.

out vec4 fs_mPos;           // vertex model space (world space) position


const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.




float fade(float t) {
    return t*t*t*(t*(t*6.0 - 15.0) + 10.0);
}

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



//    Cubic Hermine Curve.  Same as SmoothStep().  As used by Perlin in Original Noise.
//    3x^2-2x^3
float Interpolation_C1( float x ) { return x * x * (3.0 - 2.0 * x); }

//    Quintic Hermite Curve.  As used by Perlin in Improved Noise.  http://mrl.nyu.edu/~perlin/paper445.pdf
//    6x^5-15x^4+10x^3
float Interpolation_C2( float x ) { return x * x * x * (x * (x * 6.0 - 15.0) + 10.0); }

//    Faster than Perlin Quintic.  Not quite as good shape.
//    7x^3-7x^4+x^7
float Interpolation_C2_Fast( float x ) { float x3 = x*x*x; return ( 7.0 + ( x3 - 7.0 ) * x ) * x3; }
 
//    C3 Interpolation function.  If anyone ever needs it... : )
//    25x^4-48x^5+25x^6-x^10
float Interpolation_C3( float x ) { float xsq = x*x; float xsqsq = xsq*xsq; return xsqsq * ( 25.0 - 48.0 * x + xsq * ( 25.0 - xsqsq ) ); }


// ( 1.0 - x*x )^2 ( Used by Humus for lighting falloff in Just Cause 2. GPUPro 1 )
float Falloff_Xsq_C1( float xsq ) { xsq = 1.0 - xsq; return xsq*xsq; }
// ( 1.0 - x*x )^3. NOTE: 2nd derivative is 0.0 at x=1.0, but non-zero at x=0.0
float Falloff_Xsq_C2( float xsq ) { xsq = 1.0 - xsq; return xsq*xsq*xsq; }
 



void main()
{
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.

    

    // Generate 3d perlin noise
    float noiseScale = 0.5;

    float summedNoise = 0.0;
    float amplitude = 0.6;
    for(int i = 2; i <= 16; i *= 2) {

        vec3 xyz = float(i) * vs_Pos.xyz;

        xyz = vec3(cos(3.14159/3.0 * float(i)) * xyz.x - sin(3.14159/3.0 * float(i)) * xyz.y + cos(3.14159/3.0 * float(i)) * xyz.z, 
                   sin(3.14159/3.0 * float(i)) * xyz.x + cos(3.14159/3.0 * float(i)) * xyz.y - sin(3.14159/3.0 * float(i)) * xyz.z,
                   sin(3.14159/3.0 * float(i)) * xyz.x - sin(3.14159/3.0 * float(i)) * xyz.y + sin(3.14159/3.0 * float(i)) * xyz.z);
        
        // float timeScale = 0.0;
        float timeOffset = cos(u_Timer * 3.14159 * u_TimeScale);
        
        float perlin3d = abs(noise3d(noiseScale * xyz.x + timeOffset, 
                                     noiseScale * xyz.y + timeOffset, 
                                     noiseScale * xyz.z + timeOffset));
        summedNoise += perlin3d * amplitude;
        amplitude *= 0.5;
    }

    // summedNoise = Interpolation_C3(summedNoise);

    vec4 modelposition = u_Model * (vs_Pos + u_FinalNoiseScale * summedNoise * vs_Nor);   // Temporarily store the transformed vertex positions for use below

    fs_mPos = modelposition;

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
