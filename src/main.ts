import {vec2, vec3, vec4} from 'gl-matrix';
import * as Stats from 'stats-js';
import * as DAT from 'dat-gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';


// const SQUARE = 'Square';
// const ICOSPHERE = 'Icosphere';
// const CUBE = 'Cube';

// const LAMBERT = 'Lambert';
// const CUSTOM = 'Custom';
// const PERLIN = 'Perlin';
// const PLANET = 'Planet';


// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations : 7,
  speed : 1.0,
  noiseScale : 1.2,
  terrainMove : false,
  isDebugPerlin: false,

  //geometry : ICOSPHERE,
  //'Load Scene': loadScene, // A function pointer, essentially
  //color : [ 255, 0, 0 ], // RGB array
  //shaderProg : PLANET,
};

let icosphere: Icosphere;
let icosphere_out: Icosphere; 
let square: Square;
// let cube : Cube;

let speed: number;
let noiseScale: number;
let isDebugPerlin: boolean;


function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1.5, controls.tesselations);
  icosphere.create();

  icosphere_out = new Icosphere(vec3.fromValues(0, 0, 0), 1.2, controls.tesselations);
  icosphere_out.create();

  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();

  speed = controls.speed;
  noiseScale = controls.noiseScale;
  isDebugPerlin = controls.isDebugPerlin;

  //cube = new Cube(vec3.fromValues(0, 0, 0));
  //cube.create();
}



function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  // Add controls to the gui
  const gui = new DAT.GUI();

  // set which geometry to render
  // var geometryToRender : any;

  // function setGeometry(){
  //   switch(controls.geometry) {
  //     case SQUARE:
  //       geometryToRender = square;
  //       break;
  //     case ICOSPHERE:
  //       geometryToRender = icosphere;
  //       break;
  //     case CUBE:
  //       geometryToRender = cube;
  //       break;
  //   }
  // }
  // setGeometry();

  // set icosphere tesselation degree
  function setTesselation(){
    icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
    icosphere.create();
    icosphere_out = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
    icosphere_out.create();
  }

  function setSpeed(){
      speed = controls.speed;
  }


  // GUI
  gui.add(controls, 'tesselations', 0, 8).step(1).onChange(setTesselation);
  gui.add(controls, 'speed', 1, 4).step(1).onChange(setSpeed);

  //gui.add(controls, 'geometry', [SQUARE, ICOSPHERE, CUBE]).onChange(setGeometry);
  //gui.add(controls, 'Load Scene');


  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  // Open GL Renderer
  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.2, 0.2, 0.2, 1);
  gl.enable(gl.DEPTH_TEST);

  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

  // // setup lambert shader
  // const lambert = new ShaderProgram([
  //   new Shader(gl.VERTEX_SHADER, require('./shaders/lambert-vert.glsl')),
  //   new Shader(gl.FRAGMENT_SHADER, require('./shaders/lambert-frag.glsl')),
  // ]);

  // // setup custom shader
  // const custom = new ShaderProgram([
  //   new Shader(gl.VERTEX_SHADER, require('./shaders/custom-vert.glsl')),
  //   new Shader(gl.FRAGMENT_SHADER, require('./shaders/custom-frag.glsl')),
  // ]);

  // setup perlin shader
  const perlin = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/perlin.vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/perlin.frag.glsl')),
  ]);
  perlin.setDimensions(vec2.fromValues(1.0, 1.0));

  // setup planet shader
  const planet = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/noisy-planet.vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/noisy-planet-base.frag.glsl')),
  ]);
  planet.setNoise3d(0.0, 0.1);

  const planet_out = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/noisy-planet.vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/noisy-planet-cover.frag.glsl')),
  ]);
  planet_out.setNoise3d(0.0, noiseScale);
  planet_out.setGeometryColor(vec4.fromValues(0.0, 1.0, 0.0, 1.0));    
  
  // setup background shader
  const background = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/background.vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/background.frag.glsl')),
  ]);
  background.setDimensions(vec2.fromValues(1.0, 1.0));


  // set uniform color for lambert shader
  // function setColor(){
  //   lambert.setGeometryColor(vec4.fromValues(controls.color[0] / 255.0, controls.color[1] / 255.0, controls.color[2] / 255.0, 1.0));
  //   custom.setGeometryColor(vec4.fromValues(controls.color[0] / 255.0, controls.color[1] / 255.0, controls.color[2] / 255.0, 1.0));    
  //   perlin.setGeometryColor(vec4.fromValues(controls.color[0] / 255.0, controls.color[1] / 255.0, controls.color[2] / 255.0, 1.0));    
  //   planet.setGeometryColor(vec4.fromValues(controls.color[0] / 255.0, controls.color[1] / 255.0, controls.color[2] / 255.0, 1.0));    
  // }
  //gui.addColor(controls, 'color').onChange(setColor);
  //setColor();

  function setNoiseScale(){
    planet_out.setNoiseScale(controls.noiseScale);
  }
  gui.add(controls, 'noiseScale', 0.8, 2.0).step(0.2).onChange(setNoiseScale);

  function setTimeScale(){
    if(controls.terrainMove){
      planet_out.setTimeScale(0.2);
    }
    else{
      planet_out.setTimeScale(0.0);
    }
  }
  gui.add(controls, 'terrainMove').onChange(setTimeScale);

  function setDebugPerlin(){
    isDebugPerlin = controls.isDebugPerlin;
  }
  gui.add(controls, 'isDebugPerlin').onChange(setDebugPerlin);

  // set which shader program to use
  // var shaderToUse : any;

  // function setShaderProgram(){
  //   switch(controls.shaderProg){
  //     case LAMBERT:
  //       shaderToUse = lambert;
  //       break;
  //     case CUSTOM:
  //       shaderToUse = custom;
  //       break;
  //     case PERLIN:
  //       shaderToUse = perlin;
  //       break;
  //     case PLANET:
  //       shaderToUse = planet;
  //       break;
  //   }
  // }
  // gui.add(controls, 'shaderProg', [LAMBERT, CUSTOM, PERLIN, PLANET]).onChange(setShaderProgram);
  
  // setShaderProgram();


  // setup timer;
  var timer = 0.0;

  // This function will be called every frame
  function tick() {
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);

    timer += 1.0;
    if(timer > 10000.0){
      timer -= 10000.0;
    }

    renderer.clear();


    if(isDebugPerlin){
      perlin.setTimer(speed * timer / 50.0);  
      renderer.render(camera, perlin, [
        square,
      ], 0);
    }
    else{
      // background
      background.setTimer(speed * timer / 500.0);
      renderer.render(camera, background, [
        square,
      ], 0);

      // base sphere
      // shaderToUse.setTimer(timer / 50.0);  
      // renderer.render(camera, shaderToUse, [
      //   geometryToRender,
      // ]);
      planet.setTimer(speed * timer / 50.0);  
      renderer.render(camera, planet, [
        icosphere,
      ], speed * timer / 350.0);

      // outer cover sphere
      planet_out.setTimer(speed * timer / 200.0);       
      renderer.render(camera, planet_out, [
        icosphere_out,
      ], speed * timer / 350.0);
    }

    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
