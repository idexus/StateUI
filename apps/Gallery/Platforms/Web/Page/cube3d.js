// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// <gallery-cube3d>: a cube drawn by WebGL 2 on a canvas of its own, turning on the browser's display frames while
// it is in view - an element that knows nothing of StateUI. Its attributes say what it is: `size`, the edge as a
// share of its room from 0 to 1; `color`, 0 teal, 1 amber, 2 violet; `spinning`, present while it turns. The Swift
// half is Platforms/Web/Host/WebGLCube3DView.swift.

const colors = [[0.161, 0.722, 0.678], [0.961, 0.710, 0.275], [0.580, 0.443, 0.929]];

// Six faces of two triangles each, every corner its position and its face's brightness in w.
const corners = new Float32Array([
  [[[1, -1, -1], [1, 1, -1], [1, 1, 1], [1, -1, 1]], 1.00],
  [[[-1, -1, -1], [-1, 1, -1], [-1, 1, 1], [-1, -1, 1]], 0.55],
  [[[-1, 1, -1], [1, 1, -1], [1, 1, 1], [-1, 1, 1]], 0.88],
  [[[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]], 0.42],
  [[[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]], 0.97],
  [[[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1]], 0.50],
].flatMap(([face, shade]) => [0, 1, 2, 0, 2, 3].flatMap((at) => [...face[at], shade])));

const vertexShader = `#version 300 es
layout(location = 0) in vec4 corner;
uniform mat4 transform;
uniform vec4 color;
out vec4 painted;
void main() {
  gl_Position = transform * vec4(corner.xyz, 1.0);
  painted = vec4(color.rgb * corner.w, color.a);
}`;

const fragmentShader = `#version 300 es
precision mediump float;
in vec4 painted;
out vec4 fragment;
void main() { fragment = painted; }`;

class Cube3D extends HTMLElement {
  static observedAttributes = ["size", "color", "spinning"];

  constructor() {
    super();
    const shadow = this.attachShadow({ mode: "open" });
    shadow.innerHTML = `<style>
      :host { display: block; position: relative; min-width: 240px; min-height: 240px; }
      canvas { position: absolute; inset: 0; width: 100%; height: 100%; display: block; border-radius: inherit; }
      p { position: absolute; inset: 0; margin: auto; height: fit-content; text-align: center; color: #bbb; font: 14px system-ui; }
    </style><canvas></canvas>`;
    this.canvas = shadow.querySelector("canvas");
    this.angle = 0;
    this.lastFrame = 0;
    this.inView = false;
    this.canvas.addEventListener("webglcontextlost", (lost) => { lost.preventDefault(); this.gl = null; });
    this.canvas.addEventListener("webglcontextrestored", () => this.makeContext());
  }

  connectedCallback() {
    if (!this.gl) this.makeContext();
    this.resized = new ResizeObserver(() => this.draw());
    this.resized.observe(this);
    // The cube turns only where the user can see it: behind a page left, it holds its angle.
    this.seen = new IntersectionObserver(([entry]) => {
      this.inView = entry.isIntersecting;
      this.follow();
    });
    this.seen.observe(this);
  }

  disconnectedCallback() {
    this.resized?.disconnect();
    this.seen?.disconnect();
    this.inView = false;
    this.follow();
  }

  attributeChangedCallback() {
    this.follow();
    this.draw();
  }

  get size() { return Math.min(Math.max(Number(this.getAttribute("size") ?? 0.6), 0), 1); }
  get color() { return colors[Number(this.getAttribute("color") ?? 0)] ?? colors[0]; }
  get spinning() { return this.hasAttribute("spinning"); }

  // The shaders, the corners and where the uniforms stand, made in the canvas's own context.
  makeContext() {
    const gl = this.canvas.getContext("webgl2", { antialias: true });
    if (!gl) {
      this.shadowRoot.append(Object.assign(document.createElement("p"), { textContent: "This browser draws no WebGL 2." }));
      return;
    }
    const program = gl.createProgram();
    for (const [kind, source] of [[gl.VERTEX_SHADER, vertexShader], [gl.FRAGMENT_SHADER, fragmentShader]]) {
      const shader = gl.createShader(kind);
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      gl.attachShader(program, shader);
      gl.deleteShader(shader);
    }
    gl.linkProgram(program);
    const vertexArray = gl.createVertexArray();
    gl.bindVertexArray(vertexArray);
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, corners, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 4, gl.FLOAT, false, 16, 0);
    this.gl = gl;
    this.program = program;
    this.vertexArray = vertexArray;
    this.transformAt = gl.getUniformLocation(program, "transform");
    this.colorAt = gl.getUniformLocation(program, "color");
    this.draw();
  }

  // Turns on the display's frames while spinning in view; a stopped cube still owes one frame to a value changed.
  follow() {
    const turns = this.spinning && this.inView;
    if (turns && !this.frame) {
      this.lastFrame = 0;
      const turn = (time) => {
        if (this.lastFrame) this.angle += (time - this.lastFrame) / 1000;
        this.lastFrame = time;
        this.draw();
        this.frame = requestAnimationFrame(turn);
      };
      this.frame = requestAnimationFrame(turn);
    } else if (!turns && this.frame) {
      cancelAnimationFrame(this.frame);
      this.frame = 0;
    }
  }

  // Clears to the housing's colour and draws the cube: turned, scaled and seen in perspective.
  draw() {
    const gl = this.gl;
    if (!gl) return;
    const ratio = devicePixelRatio || 1;
    const width = Math.max(1, Math.round(this.clientWidth * ratio)), height = Math.max(1, Math.round(this.clientHeight * ratio));
    if (this.canvas.width !== width) this.canvas.width = width;
    if (this.canvas.height !== height) this.canvas.height = height;
    gl.viewport(0, 0, width, height);
    gl.clearColor(0.102, 0.090, 0.145, 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.DEPTH_TEST);
    gl.useProgram(this.program);
    gl.uniformMatrix4fv(this.transformAt, false, transform(width / height, this.angle, this.size));
    gl.uniform4f(this.colorAt, ...this.color, 1);
    gl.bindVertexArray(this.vertexArray);
    gl.drawArrays(gl.TRIANGLES, 0, corners.length / 4);
  }
}

// The arithmetic behind the matrix, column by column - the same as every host's cube.
function transform(aspect, turn, scale) {
  return multiply(perspective(50 * Math.PI / 180, aspect),
    multiply(translation(-4), multiply(rotationX(turn * 0.35), multiply(rotationY(turn * 0.60), scaling(scale)))));
}

function perspective(fieldOfView, aspect) {
  const focal = 1 / Math.tan(fieldOfView / 2), near = 0.1, far = 100;
  const matrix = new Float32Array(16);
  matrix[0] = focal / aspect;
  matrix[5] = focal;
  matrix[10] = (far + near) / (near - far);
  matrix[11] = -1;
  matrix[14] = 2 * far * near / (near - far);
  return matrix;
}

const identity = () => new Float32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

function translation(z) {
  const matrix = identity();
  matrix[14] = z;
  return matrix;
}

function rotationX(angle) {
  const matrix = identity();
  [matrix[5], matrix[6], matrix[9], matrix[10]] = [Math.cos(angle), Math.sin(angle), -Math.sin(angle), Math.cos(angle)];
  return matrix;
}

function rotationY(angle) {
  const matrix = identity();
  [matrix[0], matrix[2], matrix[8], matrix[10]] = [Math.cos(angle), -Math.sin(angle), Math.sin(angle), Math.cos(angle)];
  return matrix;
}

function scaling(scale) {
  const matrix = identity();
  [matrix[0], matrix[5], matrix[10]] = [scale, scale, scale];
  return matrix;
}

function multiply(left, right) {
  const matrix = new Float32Array(16);
  for (let at = 0; at < 16; at++) {
    const column = Math.floor(at / 4), row = at % 4;
    for (let step = 0; step < 4; step++) matrix[at] += left[step * 4 + row] * right[column * 4 + step];
  }
  return matrix;
}

customElements.define("gallery-cube3d", Cube3D);
