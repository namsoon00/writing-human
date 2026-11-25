/* Shared Flutter geometry, rendered with WebGL depth instead of CPU polygon BSP. */
(() => {
  'use strict';
  const vertex = `#version 300 es
  precision highp float;
  layout(location=0) in vec3 position;
  layout(location=1) in vec3 normal;
  layout(location=2) in vec2 uv;
  layout(location=3) in vec4 color;
  layout(location=4) in vec4 options;
  uniform vec3 eye, right, up, forward;
  uniform vec2 focal;
  uniform float omit;
  out vec2 texcoord;
  out vec4 shade;
  out vec3 point, norm;
  out float unlit, roomX;
  void main() {
    vec3 d=position-eye;
    float z=dot(d,forward);
    float near=.06, far=110.;
    gl_Position=vec4(dot(d,right)*focal.x,dot(d,up)*focal.y,
      ((far+near)/(far-near))*z-2.*far*near/(far-near),z);
    gl_Position.z-=options.z*.000004*z;
    if(omit>0. && abs(options.y-omit)<.1) gl_Position=vec4(3.,3.,3.,1.);
    texcoord=uv; shade=color; point=position; norm=normal; unlit=options.x;roomX=options.w;
  }`;
  const fragment = `#version 300 es
  precision highp float;
  in vec2 texcoord;
  in vec4 shade;
  in vec3 point, norm;
  in float unlit, roomX;
  uniform sampler2D image;
  uniform bool textured, cutout, outside;
  uniform int mood, lampCount, wallCount;
  uniform vec4 lamps[32], walls[12];
  uniform vec3 tint;
  uniform float lampScale, brightness, warmth;
  out vec4 result;
  void main() {
    vec4 c=shade*(textured?texture(image,texcoord):vec4(1.));
    if(cutout && c.a<.34) discard;
    if(c.a<.008) discard;
    if(unlit<.5) {
      vec3 n=normalize(norm);
      vec3 day=normalize(vec3(-.7,.9,-.35));
      float daylight=max(0.,dot(n,day));
      float fill=outside?((mood==0?.80:.49)+.18*daylight+.08*max(0.,n.y)):
        ((mood==0?.76:(mood==1?.58:.52))+.11*daylight*exp(-max(0.,roomX+4.4)/4.5)+.035*max(0.,n.y));
      float warm=0.;
      for(int i=0;i<32;i++) {
        if(i>=lampCount) break;
        vec3 delta=lamps[i].xyz-point; float dd=dot(delta,delta);
        if(outside) warm+=lamps[i].w*.65*max(0.,dot(n,normalize(delta)))/(1.+dd*2.4);
        else {
          float cone=clamp(1.-length(delta.xz)/(.40+max(0.,delta.y)*.75),0.,1.);
          warm+=1.45*lamps[i].w*(mood==0 || lamps[i].y<1.8?1.:.45)*cone*cone*
            max(0.,dot(n,normalize(delta)))/(1.+.45*dd);
        }
      }
      for(int i=0;i<12;i++) {
        if(i>=wallCount) break;
        vec3 delta=walls[i].xyz-point;
        warm+=.70*walls[i].w*max(0.,dot(n,normalize(delta)))/(1.+3.2*dot(delta,delta));
      }
      vec3 ambient=outside?vec3(fill*(mood==0?1.:.93),fill*.978,fill*(mood==0?.925:1.08)):
          vec3(fill,fill*.96,fill*.89);
      vec3 glow=outside?vec3(warm,warm*.76,warm*.43):
          vec3(warm,warm*(.86-warmth*.08),warm*(.69-warmth*.16));
      c.rgb*=clamp(ambient*tint+glow*lampScale,0.,1.45)*(outside?1.:brightness);
    }
    result=c;
  }`;

  globalThis.writingCafeGpuCreate = canvas => {
    const gl=canvas.getContext('webgl2',{alpha:false,antialias:true,depth:true,powerPreference:'high-performance'});
    if(!gl) return null;
    const shader=(type,source)=>{
      const s=gl.createShader(type); gl.shaderSource(s,source); gl.compileShader(s);
      if(!gl.getShaderParameter(s,gl.COMPILE_STATUS)) throw Error(gl.getShaderInfoLog(s));
      return s;
    };
    let program;
    try {
      const v=shader(gl.VERTEX_SHADER,vertex), f=shader(gl.FRAGMENT_SHADER,fragment);
      program=gl.createProgram(); gl.attachShader(program,v);gl.attachShader(program,f);gl.linkProgram(program);
      gl.deleteShader(v); gl.deleteShader(f);
      if(!gl.getProgramParameter(program,gl.LINK_STATUS)) throw Error(gl.getProgramInfoLog(program));
    } catch(e) { console.warn('Cafe GPU unavailable:',String(e));return null; }
    const skyProgram=gl.createProgram();
    const skyV=shader(gl.VERTEX_SHADER,`#version 300 es
      out vec2 uv;
      void main(){vec2 p=vec2(gl_VertexID==1?3.:-1.,gl_VertexID==2?3.:-1.);uv=p*.5+.5;gl_Position=vec4(p,0.,1.);}`);
    const skyF=shader(gl.FRAGMENT_SHADER,`#version 300 es
      precision highp float;in vec2 uv;uniform vec3 topColor,bottomColor;uniform vec2 shift;out vec4 color;
      void main(){vec2 p=uv+shift;float t=clamp((p.y-.28)*1.35,0.,1.);
        vec3 c=mix(bottomColor,topColor,t);
        float cloud=exp(-pow((p.x-.22)*5.,2.)-pow((p.y-.76)*24.,2.))+
          .7*exp(-pow((p.x-.70)*6.,2.)-pow((p.y-.88)*28.,2.));
        color=vec4(mix(c,vec3(1.,.97,.9),clamp(cloud*.35,0.,.45)),1.);}`);
    gl.attachShader(skyProgram,skyV);gl.attachShader(skyProgram,skyF);gl.linkProgram(skyProgram);
    gl.deleteShader(skyV);gl.deleteShader(skyF);
    const skyTop=gl.getUniformLocation(skyProgram,'topColor'),skyBottom=gl.getUniformLocation(skyProgram,'bottomColor'),skyShift=gl.getUniformLocation(skyProgram,'shift');
    const uniform={};
    for(const n of ['eye','right','up','forward','focal','omit','image','textured','cutout','outside',
      'mood','lampCount','wallCount','lamps','walls','tint','lampScale','brightness','warmth']) uniform[n]=gl.getUniformLocation(program,n);
    const textures=new Map(), statics=[], dynamics=[];
    let disposed=false, lost=false, frameNumber=0;
    canvas.addEventListener('webglcontextlost',event=>{event.preventDefault();lost=true;});
    // Flutter replaces this surface with its native Canvas fallback on context loss.
    const remove=list=>{for(const b of list){gl.deleteBuffer(b.buffer);gl.deleteVertexArray(b.vao);}list.length=0;};
    const batch=(list,key,data,room,alpha,cutout)=>{
      let b=list.find(x=>x.key===key);
      if(!b){b={key,buffer:gl.createBuffer(),vao:gl.createVertexArray()};list.push(b);}
      b.room=room;b.alpha=alpha;b.cutout=cutout;b.count=data.length/16;
      gl.bindVertexArray(b.vao);gl.bindBuffer(gl.ARRAY_BUFFER,b.buffer);
      gl.bufferData(gl.ARRAY_BUFFER,data,list===statics?gl.STATIC_DRAW:gl.DYNAMIC_DRAW);
      for(const [loc,count,offset] of [[0,3,0],[1,3,3],[2,2,6],[3,4,8],[4,4,12]]) {
        gl.enableVertexAttribArray(loc);gl.vertexAttribPointer(loc,count,gl.FLOAT,false,64,offset*4);
      }
      gl.bindVertexArray(null);
    };
    const api={
      texture(id,width,height,bytes,clamp){
        const previous=textures.get(id);if(previous)gl.deleteTexture(previous);
        const t=gl.createTexture();textures.set(id,t);gl.bindTexture(gl.TEXTURE_2D,t);
        gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,false);
        gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,width,height,0,gl.RGBA,gl.UNSIGNED_BYTE,bytes);
        gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,clamp?gl.CLAMP_TO_EDGE:gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,clamp?gl.CLAMP_TO_EDGE:gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR_MIPMAP_LINEAR);
        gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);gl.generateMipmap(gl.TEXTURE_2D);
      },
      keepTextures(ids){for(const [key,t] of textures){if(!ids.includes(key)){gl.deleteTexture(t);textures.delete(key);}}},
      clear(){remove(statics);},
      batch(key,data,room,alpha,cutout){batch(statics,key,data,room,alpha,cutout);},
      begin(){for(const b of dynamics)b.count=0;},
      dynamic(key,data,room,alpha,cutout){batch(dynamics,key,data,room,alpha,cutout);},
      draw(camera,width,height,ratio,rooms,omit,buildMs){
        if(disposed||lost)return;
        const started=performance.now();
        const w=Math.max(1,Math.round(width*Math.min(ratio,1.75))),h=Math.max(1,Math.round(height*Math.min(ratio,1.75)));
        if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}
        gl.viewport(0,0,w,h);gl.clear(gl.DEPTH_BUFFER_BIT);gl.disable(gl.DEPTH_TEST);gl.disable(gl.BLEND);
        gl.useProgram(skyProgram);
        const mood=rooms[0].mood;
        gl.uniform3fv(skyTop,mood===0?[.72,.83,.88]:mood===1?[.49,.58,.69]:[.40,.49,.56]);
        gl.uniform3fv(skyBottom,mood===0?[1.,.93,.79]:mood===1?[.91,.74,.64]:[.66,.69,.67]);
        gl.uniform2f(skyShift,Math.atan2(camera[9],-camera[11])*.12,camera[10]*.7);
        gl.bindVertexArray(null);gl.drawArrays(gl.TRIANGLES,0,3);
        gl.enable(gl.DEPTH_TEST);gl.depthFunc(gl.LEQUAL);gl.disable(gl.CULL_FACE);gl.useProgram(program);
        const set3=(n,v)=>gl.uniform3fv(uniform[n],v);
        set3('eye',camera.slice(0,3));set3('right',camera.slice(3,6));set3('up',camera.slice(6,9));set3('forward',camera.slice(9,12));
        gl.uniform2f(uniform.focal,camera[12],camera[13]);gl.uniform1f(uniform.omit,omit);gl.uniform1i(uniform.image,0);
        let selected=-1;
        const draw=b=>{
          if(!b.count)return;
          const cfg=rooms[b.room];
          if(selected!==b.room){
            selected=b.room;gl.uniform1i(uniform.outside,cfg.outside);gl.uniform1i(uniform.mood,cfg.mood);
            gl.uniform1i(uniform.lampCount,cfg.lamps.length/4);if(cfg.lamps.length)gl.uniform4fv(uniform.lamps,new Float32Array(cfg.lamps));
            gl.uniform1i(uniform.wallCount,cfg.walls.length/4);if(cfg.walls.length)gl.uniform4fv(uniform.walls,new Float32Array(cfg.walls));
            set3('tint',cfg.tint);gl.uniform1f(uniform.lampScale,cfg.lampScale);
            gl.uniform1f(uniform.brightness,cfg.brightness);gl.uniform1f(uniform.warmth,cfg.warmth);
          }
          const tex=textures.get(b.key.split(':')[0]);
          gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,tex||null);
          gl.uniform1i(uniform.textured,!!tex);gl.uniform1i(uniform.cutout,b.cutout);
          gl.bindVertexArray(b.vao);gl.drawArrays(gl.TRIANGLES,0,b.count);
        };
        const all=[...statics,...dynamics];
        gl.disable(gl.BLEND);gl.depthMask(true);
        for(const b of all)if(!b.alpha)draw(b);
        gl.enable(gl.BLEND);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);gl.depthMask(false);
        for(const b of all)if(b.alpha)draw(b);
        gl.depthMask(true);gl.bindVertexArray(null);
        canvas.dataset.cafeRenderer='webgl2';canvas.dataset.cafeFrame=String(++frameNumber);
        canvas.dataset.cafeSubmitMs=(performance.now()-started).toFixed(2);
        canvas.dataset.cafeBuildMs=Number(buildMs).toFixed(2);
        const error=gl.getError();if(error!==gl.NO_ERROR)canvas.dataset.cafeGlError=String(error);
      },
      dispose(){disposed=true;remove(statics);remove(dynamics);for(const t of textures.values())gl.deleteTexture(t);gl.deleteProgram(program);gl.deleteProgram(skyProgram);gl.getExtension('WEBGL_lose_context')?.loseContext();}
    };
    return api;
  };
})();
