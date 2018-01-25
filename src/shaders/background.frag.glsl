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

// rendering params
const float sphsize=.3; // planet size
const float dist=.27; // distance for glow and distortion
const float perturb=.3; // distortion amount of the flow around the planet
//const float displacement=.015; // hot air effect
const float windspeed=.4; // speed of wind flow
const float steps=15.; // number of steps for the volumetric rendering
const float stepsize=.025; 
const float brightness=.43;
//const vec3 planetcolor=vec3(0.55,0.4,0.3);
const float fade=.005; //fade by distance
const float glow=3.5; // glow amount, mainly on hit side
const int iterations=14; 
const float fractparam=.7;
const vec3 offset=vec3(1.5,2.,-1.5);


// -------------------------- Perlin ------------------------------

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


float basic_perlin(){
    // Basic Perlin noise
    vec2 uv = PixelToGrid(fs_UV, 4.0);

    float perlin = PerlinNoise(uv);
    return (perlin + 1.0) * 0.5;
}

float summed_perlin(vec2 input_uv){

    float summedNoise = 0.0;
    float amplitude = 0.5;
    for(int i = 2; i <= 32; i *= 2) {
        vec2 uv = PixelToGrid(input_uv, float(i));

        uv = vec2(cos(3.14159/3.0 * float(i)) * uv.x - sin(3.14159/3.0 * float(i)) * uv.y, sin(3.14159/3.0 * float(i)) * uv.x + cos(3.14159/3.0 * float(i)) * uv.y);
        float perlin = abs(PerlinNoise(uv));// * amplitude;
        summedNoise += perlin * amplitude;
        amplitude *= 0.5;
    }

    return summedNoise;
}

float absolute_perlin(vec2 input_uv){
    vec2 uv = PixelToGrid(input_uv, 10.0);

    float perlin = PerlinNoise(uv);
    return 1.0 - abs(perlin);
}

float recursive1_perlin(){
    float time = u_Timer * 10.0;

    vec2 planet = vec2(cos(time * 0.01 * 3.14159), sin(time * 0.01 * 3.14159)) * 2.0 + vec2(4.0);
    
    vec2 uv = PixelToGrid(fs_UV, 10.0);

    vec2 planetDiff = planet - uv;
    float len = length(planetDiff);
    vec2 offset = vec2(PerlinNoise(uv + time * 0.01), PerlinNoise(uv + vec2(5.2, 1.3)));
    if(len < 1.0) {
        offset += planetDiff * (1.0 - len);
    }
    float perlin = PerlinNoise(uv + offset);
    
    return (perlin + 1.0) * 0.5;
}

// --------------------------------------------------------------

float wind(vec3 p) {
    float iTime = u_Timer;

	float d = max(0., dist-max(0.,length(p)-sphsize)/sphsize)/dist; // for distortion and glow area
	float x = max(0.2, p.x * 2.); // to increase glow on left side
	p.y *= 1.+max(0.,-p.x - sphsize*.25) * 1.5; // left side distortion (cheesy)
	p-=d*normalize(p)*perturb; // spheric distortion of flow
	p+=vec3((iTime/4.0)*windspeed,0.,0.); // flow movement
	p=abs(fract((p+offset)*.1)-.5); // tile folding 
	for (int i=0; i<iterations; i++) {  
		p=abs(p)/dot(p,p)-fractparam; // the magic formula for the hot flow
	}
	return length(p)*(1.+d*glow*x)+d*glow*x; // return the result with glow applied
}


float snow(vec2 uv)
{           
        float iTime = u_Timer;

        vec3 dir=vec3(-uv,1.0);
		//vec3 tex3=vec3(0.0);
        float tex3_fromPerlin = 0.0;

        vec3 from = vec3(0.0,0.0,1.0);

        float v=0., l=-0.0001;
        float t=0.1*windspeed*0.2;

        for (float r=8.0; r<steps; r++) {
            vec3 p=from+r*dir*stepsize;
            v+=min(50.,wind(p))*max(0.,1.-r*fade);
            
            vec2 pol = vec2((p.x+iTime/6.0),(p.y));
            
            //tex3 = vec3(texture(iChannel0, vec2(pol.x,pol.y)*2.5));
            tex3_fromPerlin = absolute_perlin(vec2(pol.x, pol.y) * 2.5);
        }

        v/=steps; v*=brightness;
        
    
        return v*(tex3_fromPerlin*(2.5+sin(iTime)));
}



void main()
{
    vec2 p = 2.0 * fs_UV - vec2(1.0, 1.0);
    float iTime = u_Timer;

     // camera movement	
    float an = 1.5*1.;
	vec3 ro = vec3( 2.5*cos(an), 0., 2.5*sin(an) );
    vec3 ta = vec3( 0.0, 0.0, 0.0 );
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(sin(iTime)/8.,1.0,0.0) ) );
    vec3 vv = normalize( cross(uu,ww));
	// create view ray
	vec3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );

	
    // vec3 tex3 =  vec3(summed_perlin(rd.xy+sin(iTime)));
    // tex3 =  vec3(summed_perlin(vec2(rd.x+(iTime/4.), rd.y)));

	// raytrace-plane
    float t = 1e4;
    //float t = recursive1_perlin();

//  t = RSph(vec3(0.,0.,0.0), 1.40 - ((tex3.r) * 0.05), ro, rd);
//	t = cube(ro, rd, vec3(0.01,0.01,0.1), vec3(1.0,1.0,1.0-tex3.r));

	vec3 nml = normalize(vec3(0.0) - (ro+rd*t));
    
    // shading/lighting	
	vec3 col = vec3(0.0);
	
//	  col = background(iTime, rd) * vec3(0.9, 0.8, 1.0) * 2.6;
//    col -= background(iTime - 2.0, rd - vec3(0,-0.03,0.0)) * vec3(0.9, 0.8, 1.0);
//    col = sqrt( col );
    
    rd = reflect(-rd, nml);
    
   	// get ray dir	
	vec2 uv  = nml.xy;
	vec3 dir = vec3(uv, 1.);
    
    float snoise = (snow(vec2(uv.x,uv.y)));
    
    if((iTime > 30.0)){
    	col.b += snoise * abs(cos(iTime / 15.0)/1.0);
    }
    else{
        col += snoise * abs(sin(iTime / 5.0)/2.5);
    }    
    
    
    if (length(nml.xy) < 0.95)
    {
        if (t > 10.01)
        {
            col = vec3(0.0,0.0,0.0);
        }
    }

    if (t < 10.0+sin(iTime))
    {
    	col.r += snoise;
    }
    
    if (length(nml.xy+vec2(-0.5,0.0)*(snoise/1.0)) < 0.55)
    {
        if (t > 2.71)
        {
            col.r = snoise*2.0;
        }
    }
    
    out_Col = vec4(col, 1.0);

   // out_Col = vec4(vec3(summed_perlin()), 1.0);

   //out_Col = vec4(fs_UV, 0.0, 1.0);
}
