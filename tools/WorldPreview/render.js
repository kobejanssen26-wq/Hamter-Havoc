#!/usr/bin/env node
/*
  WorldPreview: renders the baked world (world/*.model.json) from a camera you choose, with a small WebGL renderer in the
  Chromium that ships with Playwright. It is a PREVIEW (flat shading, no textures, no real Roblox lighting) made so shapes,
  connections, gaps and layouts can be LOOKED at without opening Studio.

    node tools/WorldPreview/render.js --eye 40,25,60 --target 12,6,20 --out /tmp/shot.png [--fov 60] [--size 1280x720]
         [--files Environment,HamsterPlaza,...  or a path to any .json model file] [--box x0,x1,z0,z1] [--sky 0.62,0.8,0.95]
*/
const fs = require('fs');
const path = require('path');
const { chromium } = require('/opt/node-tools/node_modules/playwright');

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, a) => (v.startsWith('--') ? acc.concat([[v.slice(2), a[i + 1]]]) : acc), []));
const eye = (args.eye || '60,40,80').split(',').map(Number);
const target = (args.target || '0,5,0').split(',').map(Number);
const fov = Number(args.fov || 60);
const [W, H] = (args.size || '1280x720').split('x').map(Number);
const files = (args.files || 'Environment,HamsterPlaza,HamsterPath,PlayerHouses,LeaderboardHall').split(',');
const box = args.box ? args.box.split(',').map(Number) : null; // x0,x1,z0,z1 : keep only parts whose centre is inside
const sky = (args.sky || '0.62,0.8,0.95').split(',').map(Number);
const root = path.join(__dirname, '..', '..', 'world');

const parts = [];
function walk(node, meshParent) {
  const props = node.Properties || {};
  if (props.CFrame && props.Size && /Part|Wedge|Truss|Seat|Spawn/.test(node.ClassName || '')) {
    let shape = 'box';
    if (node.ClassName === 'WedgePart') shape = 'wedge';
    else if (props.Shape === 'Cylinder') shape = 'cyl';
    else if (props.Shape === 'Ball') shape = 'ball';
    for (const child of node.Children || []) {
      if (child.ClassName === 'SpecialMesh' && child.Properties && child.Properties.MeshType === 'Sphere') shape = 'ball';
    }
    const t = props.Transparency || 0;
    if (t < 0.9) parts.push({ cf: props.CFrame, size: props.Size, color: props.Color || [0.6, 0.6, 0.6], t, shape, neon: props.Material === 'Neon', name: node.Name });
  }
  for (const child of node.Children || []) walk(child);
}
for (const f of files) {
  const p = f.includes('/') ? f : path.join(root, f + '.model.json');
  if (fs.existsSync(p)) walk(JSON.parse(fs.readFileSync(p, 'utf8')));
}
const kept = box ? parts.filter(p => p.cf[0] >= box[0] && p.cf[0] <= box[1] && p.cf[2] >= box[2] && p.cf[2] <= box[3]) : parts;

const html = `<!doctype html><body style="margin:0"><canvas id=c width=${W} height=${H}></canvas><script>
const PARTS=${JSON.stringify(kept)};const EYE=${JSON.stringify(eye)},TARGET=${JSON.stringify(target)},FOV=${fov},SKY=${JSON.stringify(sky)};
const gl=document.getElementById('c').getContext('webgl',{antialias:true,preserveDrawingBuffer:true});
const vs='attribute vec3 p;attribute vec3 n;attribute vec4 c;uniform mat4 m;varying vec3 vn;varying vec4 vc;varying float d;void main(){vn=n;vc=c;vec4 q=m*vec4(p,1.);d=q.w;gl_Position=q;}';
const fs='precision mediump float;varying vec3 vn;varying vec4 vc;varying float d;void main(){vec3 L=normalize(vec3(-.45,.85,-.35));float k=.42+.58*max(dot(normalize(vn),L),0.);vec3 col=vc.rgb*k;float f=clamp((d-250.)/900.,0.,.85);col=mix(col,vec3(${sky[0]},${sky[1]},${sky[2]}),f);gl_FragColor=vec4(col,vc.a);}';
function sh(t,s){const o=gl.createShader(t);gl.shaderSource(o,s);gl.compileShader(o);if(!gl.getShaderParameter(o,gl.COMPILE_STATUS))throw gl.getShaderInfoLog(o);return o}
const pr=gl.createProgram();gl.attachShader(pr,sh(gl.VERTEX_SHADER,vs));gl.attachShader(pr,sh(gl.FRAGMENT_SHADER,fs));gl.linkProgram(pr);gl.useProgram(pr);
function cube(){const f=[[[1,0,0],[[1,-1,-1],[1,1,-1],[1,1,1],[1,-1,1]]],[[-1,0,0],[[-1,-1,1],[-1,1,1],[-1,1,-1],[-1,-1,-1]]],[[0,1,0],[[-1,1,-1],[-1,1,1],[1,1,1],[1,1,-1]]],[[0,-1,0],[[-1,-1,1],[-1,-1,-1],[1,-1,-1],[1,-1,1]]],[[0,0,1],[[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]]],[[0,0,-1],[[1,-1,-1],[-1,-1,-1],[-1,1,-1],[1,1,-1]]]];const t=[];for(const[n,q]of f){for(const i of[0,1,2,0,2,3])t.push([q[i],n])}return t}
const CUBE=cube();
function wedge(){const T=[];const A=[-1,-1,-1],B=[1,-1,-1],C=[1,-1,1],D=[-1,-1,1],E=[-1,1,1],F=[1,1,1];const quad=(a,b,c,d,n)=>{for(const i of[a,b,c,a,c,d])T.push([i,n])};quad(D,C,B,A,[0,-1,0]);quad(A,B,F,E,[0,.7,.7]);quad(D,E,F,C,[0,0,1]);T.push([A,[-1,0,0]],[E,[-1,0,0]],[D,[-1,0,0]]);T.push([B,[1,0,0]],[C,[1,0,0]],[F,[1,0,0]]);return T}
const WEDGE=wedge();
function cyl(){const T=[],N=16;for(let i=0;i<N;i++){const a=i/N*6.2832,b=(i+1)/N*6.2832;const ca=Math.cos(a),sa=Math.sin(a),cb=Math.cos(b),sb=Math.sin(b);const n1=[0,ca,sa],n2=[0,cb,sb];T.push([[-1,ca,sa],n1],[[1,ca,sa],n1],[[1,cb,sb],n2],[[-1,ca,sa],n1],[[1,cb,sb],n2],[[-1,cb,sb],n2]);for(const x of[-1,1]){T.push([[x,0,0],[x,0,0]],[[x,ca,sa],[x,0,0]],[[x,cb,sb],[x,0,0]])}}return T}
const CYL=cyl();
function ball(){const T=[],A=10,B=7;const pt=(i,j)=>{const th=i/A*6.2832,ph=j/B*3.1416;return[Math.cos(th)*Math.sin(ph),Math.cos(ph),Math.sin(th)*Math.sin(ph)]};for(let i=0;i<A;i++)for(let j=0;j<B;j++){const a=pt(i,j),b=pt(i+1,j),c=pt(i+1,j+1),d=pt(i,j+1);for(const q of[a,b,c,a,c,d])T.push([q,q])}return T}
const BALL=ball();
const MESH={box:CUBE,wedge:WEDGE,cyl:CYL,ball:BALL};
function build(list){const pos=[],nor=[],col=[];for(const p of list){const cf=p.cf,s=p.size;const R=[[cf[3],cf[4],cf[5]],[cf[6],cf[7],cf[8]],[cf[9],cf[10],cf[11]]];const rgb=p.color.map(v=>p.neon?Math.min(1,v*1.25+.15):v);const a=1-p.t;for(const[v,n]of MESH[p.shape]){const x=v[0]*s[0]/2,y=v[1]*s[1]/2,z=v[2]*s[2]/2;pos.push(cf[0]+R[0][0]*x+R[0][1]*y+R[0][2]*z,cf[1]+R[1][0]*x+R[1][1]*y+R[1][2]*z,cf[2]+R[2][0]*x+R[2][1]*y+R[2][2]*z);const nx=n[0]/Math.max(1e-3,s[0]),ny=n[1]/Math.max(1e-3,s[1]),nz=n[2]/Math.max(1e-3,s[2]);const wx=R[0][0]*nx+R[0][1]*ny+R[0][2]*nz,wy=R[1][0]*nx+R[1][1]*ny+R[1][2]*nz,wz=R[2][0]*nx+R[2][1]*ny+R[2][2]*nz;nor.push(wx,wy,wz);col.push(rgb[0],rgb[1],rgb[2],a)}}return{pos:new Float32Array(pos),nor:new Float32Array(nor),col:new Float32Array(col),n:pos.length/3}}
function lookAt(e,t,u){const z=[e[0]-t[0],e[1]-t[1],e[2]-t[2]];let l=Math.hypot(...z);z[0]/=l;z[1]/=l;z[2]/=l;const x=[u[1]*z[2]-u[2]*z[1],u[2]*z[0]-u[0]*z[2],u[0]*z[1]-u[1]*z[0]];l=Math.hypot(...x);x[0]/=l;x[1]/=l;x[2]/=l;const y=[z[1]*x[2]-z[2]*x[1],z[2]*x[0]-z[0]*x[2],z[0]*x[1]-z[1]*x[0]];return[x[0],y[0],z[0],0,x[1],y[1],z[1],0,x[2],y[2],z[2],0,-(x[0]*e[0]+x[1]*e[1]+x[2]*e[2]),-(y[0]*e[0]+y[1]*e[1]+y[2]*e[2]),-(z[0]*e[0]+z[1]*e[1]+z[2]*e[2]),1]}
function persp(f,a,n,fa){const t=1/Math.tan(f/2),r=1/(n-fa);return[t/a,0,0,0,0,t,0,0,0,0,(n+fa)*r,-1,0,0,2*n*fa*r,0]}
function mul(a,b){const o=new Array(16).fill(0);for(let i=0;i<4;i++)for(let j=0;j<4;j++)for(let k=0;k<4;k++)o[j*4+i]+=a[k*4+i]*b[j*4+k];return o}
const opaque=PARTS.filter(p=>p.t<0.05),glass=PARTS.filter(p=>p.t>=0.05);
const M=mul(persp(FOV*Math.PI/180,${W}/${H},0.5,4000),lookAt(EYE,TARGET,[0,1,0]));
gl.uniformMatrix4fv(gl.getUniformLocation(pr,'m'),false,new Float32Array(M));
gl.viewport(0,0,${W},${H});gl.clearColor(${sky[0]},${sky[1]},${sky[2]},1);gl.enable(gl.DEPTH_TEST);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
function draw(list,blend){const g=build(list);if(!g.n)return;const att=(name,data,size)=>{const b=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,b);gl.bufferData(gl.ARRAY_BUFFER,data,gl.STATIC_DRAW);const l=gl.getAttribLocation(pr,name);gl.enableVertexAttribArray(l);gl.vertexAttribPointer(l,size,gl.FLOAT,false,0,0)};att('p',g.pos,3);att('n',g.nor,3);att('c',g.col,4);if(blend){gl.enable(gl.BLEND);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);gl.depthMask(false)}gl.drawArrays(gl.TRIANGLES,0,g.n);gl.depthMask(true);gl.disable(gl.BLEND)}
draw(opaque,false);draw(glass,true);document.title='done '+PARTS.length;
</script>`;
fs.writeFileSync('/tmp/wp/scene.html', html);
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--use-angle=swiftshader'] });
  const pg = await b.newPage({ viewport: { width: W, height: H } });
  pg.on('pageerror', e => console.log('page error', e));
  await pg.goto('file:///tmp/wp/scene.html');
  await pg.waitForFunction(() => document.title.startsWith('done'), null, { timeout: 120000 });
  await pg.screenshot({ path: args.out || '/tmp/wp/shot.png' });
  console.log(`rendered ${kept.length} of ${parts.length} parts -> ${args.out || '/tmp/wp/shot.png'}`);
  await b.close();
})();
