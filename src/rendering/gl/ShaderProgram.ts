import {vec2, vec3, vec4, mat4} from 'gl-matrix';
import Drawable from './Drawable';
import {gl} from '../../globals';

var activeProgram: WebGLProgram = null;

var p : Array<number> = [
    151,160,137,91,90,15,
    131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
    190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
    88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
    77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
    102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
    135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
    5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
    223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
    129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
    251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
    49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
    138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
];

// var grad3 : Array<vec3> = [
//   vec3.fromValues(1,1,0),vec3.fromValues(-1,1,0),vec3.fromValues(1,-1,0),vec3.fromValues(-1,-1,0),
//   vec3.fromValues(1,0,1),vec3.fromValues(-1,0,1),vec3.fromValues(1,0,-1),vec3.fromValues(-1,0,-1),
//   vec3.fromValues(0,1,1),vec3.fromValues(0,-1,1),vec3.fromValues(0,1,-1),vec3.fromValues(0,-1,-1)
// ];

var grad3 : Array<number> = [
  1.0,1.0,0.0, -1.0,1.0,0.0, 1.0,-1.0,0.0, -1.0,-1.0,0.0,
  1.0,0.0,1.0, -1.0,0.0,1.0, 1.0,0.0,-1.0, -1.0,0.0,-1.0,
  0.0,1.0,1.0, 0.0,-1.0,1.0, 0.0,1.0,-1.0, 0.0,-1.0,-1.0
];


export class Shader {
  shader: WebGLShader;

  constructor(type: number, source: string) {
    this.shader = gl.createShader(type);
    gl.shaderSource(this.shader, source);
    gl.compileShader(this.shader);

    if (!gl.getShaderParameter(this.shader, gl.COMPILE_STATUS)) {
      throw gl.getShaderInfoLog(this.shader);
    }
  }
};

class ShaderProgram {
  prog: WebGLProgram;

  attrPos: number;
  attrNor: number;
  attrCol: number;

  unifModel: WebGLUniformLocation;
  unifModelInvTr: WebGLUniformLocation;
  unifViewProj: WebGLUniformLocation;
  unifColor: WebGLUniformLocation;
  unifTimer: WebGLUniformLocation;
  unifDimensions: WebGLUniformLocation;

  unifPermArray: WebGLUniformLocation;
  unifGradArray: WebGLUniformLocation;

  unifTimeScale: WebGLUniformLocation;
  unifFinalNoiseScale: WebGLUniformLocation;

  constructor(shaders: Array<Shader>) {
    this.prog = gl.createProgram();

    for (let shader of shaders) {
      gl.attachShader(this.prog, shader.shader);
    }
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(this.prog);
    }

    this.attrPos = gl.getAttribLocation(this.prog, "vs_Pos");
    this.attrNor = gl.getAttribLocation(this.prog, "vs_Nor");
    this.attrCol = gl.getAttribLocation(this.prog, "vs_Col");
    this.unifModel      = gl.getUniformLocation(this.prog, "u_Model");
    this.unifModelInvTr = gl.getUniformLocation(this.prog, "u_ModelInvTr");
    this.unifViewProj   = gl.getUniformLocation(this.prog, "u_ViewProj");
    this.unifColor      = gl.getUniformLocation(this.prog, "u_Color");
    this.unifTimer      = gl.getUniformLocation(this.prog, "u_Timer");
    this.unifDimensions = gl.getUniformLocation(this.prog, "u_Dimensions");

    this.unifPermArray  = gl.getUniformLocation(this.prog, "u_Perm");
    this.unifGradArray  = gl.getUniformLocation(this.prog, "u_Grad3");
    this.unifTimeScale  = gl.getUniformLocation(this.prog, "u_TimeScale");
    this.unifFinalNoiseScale = gl.getUniformLocation(this.prog, "u_FinalNoiseScale");
  }

  use() {
    if (activeProgram !== this.prog) {
      gl.useProgram(this.prog);
      activeProgram = this.prog;
    }
  }

  setModelMatrix(model: mat4) {
    this.use();
    if (this.unifModel !== -1) {
      gl.uniformMatrix4fv(this.unifModel, false, model);
    }

    if (this.unifModelInvTr !== -1) {
      let modelinvtr: mat4 = mat4.create();
      mat4.transpose(modelinvtr, model);
      mat4.invert(modelinvtr, modelinvtr);
      gl.uniformMatrix4fv(this.unifModelInvTr, false, modelinvtr);
    }
  }

  setViewProjMatrix(vp: mat4) {
    this.use();
    if (this.unifViewProj !== -1) {
      gl.uniformMatrix4fv(this.unifViewProj, false, vp);
    }
  }

  setGeometryColor(color: vec4) {
    this.use();
    if (this.unifColor !== -1) {
      gl.uniform4fv(this.unifColor, color);
    }
  }

  setTimer(timer: number) {
    this.use();
    if (this.unifTimer !== -1) {
      gl.uniform1f(this.unifTimer, timer);
    }
  }

  setDimensions(dimensions: vec2) {
    this.use();
    if (this.unifDimensions !== -1) {
      gl.uniform2fv(this.unifDimensions, dimensions);
    }
  }
  
  setNoise3d(timeScale: number, finalNoiseScale: number){
    this.use();

    if(this.unifTimeScale !== -1){
      gl.uniform1f(this.unifTimeScale, timeScale);
    }

    if(this.unifFinalNoiseScale !== -1){
      gl.uniform1f(this.unifFinalNoiseScale, finalNoiseScale);
    }

    if(this.unifPermArray !== -1){
      var perm : number[];
      perm = [];
      for(let i = 0; i < 512; i ++) { perm[i] = p[i & 255]; }
      gl.uniform1iv(this.unifPermArray, perm, 0, 512);
    }

    if(this.unifGradArray !== -1){
      gl.uniform3fv(this.unifGradArray, grad3, 0, 36);
    }
    
  }

  setNoiseScale(scale: number){
    this.use();
    
    if(this.unifFinalNoiseScale !== -1){
      gl.uniform1f(this.unifFinalNoiseScale, scale);
    }
  }

  setTimeScale(scale: number){
    this.use();

    if(this.unifTimeScale !== -1){
      gl.uniform1f(this.unifTimeScale, scale);
    }
  }



  draw(d: Drawable) {
    this.use();

    if (this.attrPos != -1 && d.bindPos()) {
      gl.enableVertexAttribArray(this.attrPos);
      gl.vertexAttribPointer(this.attrPos, 4, gl.FLOAT, false, 0, 0);
    }

    if (this.attrNor != -1 && d.bindNor()) {
      gl.enableVertexAttribArray(this.attrNor);
      gl.vertexAttribPointer(this.attrNor, 4, gl.FLOAT, false, 0, 0);
    }

    d.bindIdx();
    gl.drawElements(d.drawMode(), d.elemCount(), gl.UNSIGNED_INT, 0);

    if (this.attrPos != -1) gl.disableVertexAttribArray(this.attrPos);
    if (this.attrNor != -1) gl.disableVertexAttribArray(this.attrNor);
  }
};

export default ShaderProgram;
