'use client';
import {useEffect,useRef,useState} from 'react';
import {Button} from '@/components/ui/button';
import {Layers3,Box} from 'lucide-react';

/** Genuine WebGL geometry extruded from the canonical Dynamica SVG, coordinated with the page-wide introduction. */
export function CapitalObject(){
 const host=useRef<HTMLDivElement>(null),controller=useRef<{expand:(value:boolean)=>void}|null>(null);
 const [status,setStatus]=useState<'loading'|'ready'|'error'>('loading'),[attempt,setAttempt]=useState(0),[expanded,setExpanded]=useState(false);
 const ready=status==='ready';
 useEffect(()=>{window.dispatchEvent(new CustomEvent('dynamica:hero-state',{detail:{status}}));},[status]);
 useEffect(()=>{
  const el=host.current;if(!el)return;
  let disposed=false,cancelled=false,cleanup=()=>{};
  const timeout=setTimeout(()=>{cancelled=true;cleanup();if(!disposed)setStatus('error');},30000);
  const load=async()=>{try{
   const [T,{SVGLoader},{RoomEnvironment},svg]=await Promise.all([import('three'),import('three/addons/loaders/SVGLoader.js'),import('three/addons/environments/RoomEnvironment.js'),fetch('/brand/mark.svg',{signal:AbortSignal.timeout(15000)}).then(r=>{if(!r.ok)throw Error('Mark unavailable');return r.text();})]);
   if(disposed||cancelled)return;
   const renderer=new T.WebGLRenderer({antialias:true,alpha:true,powerPreference:'low-power'});
   renderer.setPixelRatio(Math.min(devicePixelRatio,innerWidth<640?1.25:1.7));
   renderer.setClearColor(0x0d1212,0);renderer.outputColorSpace=T.SRGBColorSpace;renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.05;
   renderer.domElement.setAttribute('aria-hidden','true');renderer.domElement.className='capital-canvas';
   const scene=new T.Scene(),camera=new T.PerspectiveCamera(34,1,.1,100);camera.position.set(0,0,8.8);
   const pmrem=new T.PMREMGenerator(renderer),room=new RoomEnvironment(),environment=pmrem.fromScene(room,.04);scene.environment=environment.texture;room.dispose();pmrem.dispose();
   scene.add(new T.HemisphereLight(0xeef5df,0x123c34,1.15));
   const key=new T.DirectionalLight(0xfff5d8,2.6);key.position.set(-3,5,5);scene.add(key);
   const rim=new T.DirectionalLight(0x8bdac6,2.1);rim.position.set(5,1,-3);scene.add(rim);
   const lime=new T.PointLight(0xd6ef95,12,8);lime.position.set(2.4,.1,2);scene.add(lime);
   const group=new T.Group();group.rotation.set(.18,-.55,-.1);group.scale.setScalar(.041);scene.add(group);
   const paths=new SVGLoader().parse(svg).paths;
   const layerColors=[0x20594f,0x258c7b,0x46b497,0x8bbb65,0xc4dc62,0xd4ef77];
   const layerMaterials=layerColors.map(color=>[
    new T.MeshPhysicalMaterial({color,metalness:.32,roughness:.31,clearcoat:.65,clearcoatRoughness:.24,envMapIntensity:.65,side:T.DoubleSide}),
    new T.MeshPhysicalMaterial({color:new T.Color(color).multiplyScalar(.48),metalness:.45,roughness:.27,clearcoat:.4,envMapIntensity:.7,side:T.DoubleSide})
   ]);
   const gateMaterial=new T.MeshPhysicalMaterial({color:0xecff9a,metalness:.08,roughness:.22,transmission:.08,thickness:2,emissive:0xc3ef61,emissiveIntensity:.28,clearcoat:.55,envMapIntensity:.6,side:T.DoubleSide});
   const geometries=paths.map(path=>{const shape=SVGLoader.createShapes(path);const geometry=new T.ExtrudeGeometry(shape,{depth:2.2,bevelEnabled:true,bevelSegments:3,steps:1,bevelSize:.42,bevelThickness:.42,curveSegments:20});geometry.translate(-53,-50,-1.1);geometry.scale(1,-1,1);geometry.computeVertexNormals();return geometry;});
   const layers=Array.from({length:6},(_,i)=>{const layer=new T.Group();for(let j=0;j<geometries.length;j++){const mesh=new T.Mesh(geometries[j],j===1?gateMaterial:layerMaterials[i]);layer.add(mesh);}layer.position.z=(i-2.5)*3.5;group.add(layer);return layer;});
   el.appendChild(renderer.domElement);
   let motion=document.body.dataset.motion==='on'&&!matchMedia('(prefers-reduced-motion: reduce)').matches;
   let failed=false,visible=true,frame=0,last=0,time=0,spread=motion?.45:0,targetSpread=0,px=0,py=0,sx=0,sy=0;
   const draw=()=>{if(disposed||cancelled)return;renderer.render(scene,camera);};
   const pose=()=>{layers.forEach((layer,i)=>{layer.position.z=(i-2.5)*(3.5+spread*10);layer.position.x=(i-2.5)*spread*1.5;layer.rotation.y=(i-2.5)*spread*.017;});group.rotation.set(.18+sy*.12+(motion?Math.sin(time*.35)*.025:0),-.55+sx*.22,-.1);group.position.y=motion?Math.sin(time*.5)*.045:0;};
   const tick=(stamp:number)=>{frame=0;if(disposed||cancelled||failed||!visible||document.hidden)return;const delta=Math.min((stamp-last)/1000,.05);if(stamp-last>=28){last=stamp;if(motion)time+=delta;spread+=(targetSpread-spread)*(motion?.065:1);sx+=(px-sx)*.055;sy+=(py-sy)*.055;pose();draw();}if(motion||Math.abs(targetSpread-spread)>.002)frame=requestAnimationFrame(tick);};
   const wake=()=>{if(!frame&&visible&&!document.hidden)frame=requestAnimationFrame(tick);};
   const resize=()=>{const w=el.clientWidth,h=el.clientHeight;if(!w||!h)return;renderer.setSize(w,h);camera.aspect=w/h;camera.position.z=w/h<.85?10.3:8.8;camera.updateProjectionMatrix();pose();draw();};
   const pointer=(event:PointerEvent)=>{if(!motion||event.pointerType!=='mouse')return;const rect=el.getBoundingClientRect();px=(event.clientX-rect.left)/rect.width*2-1;py=(event.clientY-rect.top)/rect.height*2-1;wake();};
   const leave=()=>{px=0;py=0;};
   const resizeObserver=new ResizeObserver(resize);resizeObserver.observe(el);
   const viewport=new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;if(visible)wake();else{cancelAnimationFrame(frame);frame=0;}},{threshold:0});viewport.observe(el);
   const updateMotion=()=>{motion=document.body.dataset.motion==='on'&&!matchMedia('(prefers-reduced-motion: reduce)').matches;if(!motion){cancelAnimationFrame(frame);frame=0;spread=targetSpread;sx=sy=0;pose();draw();}else wake();};
   const attributes=new MutationObserver(updateMotion);attributes.observe(document.body,{attributes:true,attributeFilter:['data-motion']});
   const visibility=()=>{if(document.hidden){cancelAnimationFrame(frame);frame=0;}else wake();};
   const lost=(e:Event)=>{e.preventDefault();failed=true;setStatus('error');cancelAnimationFrame(frame);frame=0;};
   renderer.domElement.addEventListener('webglcontextlost',lost);el.addEventListener('pointermove',pointer);el.addEventListener('pointerleave',leave);document.addEventListener('visibilitychange',visibility);
   controller.current={expand:value=>{targetSpread=value?1:0;if(!motion){spread=targetSpread;pose();draw();}else wake();}};
   cleanup=()=>{cancelAnimationFrame(frame);resizeObserver.disconnect();viewport.disconnect();attributes.disconnect();document.removeEventListener('visibilitychange',visibility);el.removeEventListener('pointermove',pointer);el.removeEventListener('pointerleave',leave);renderer.domElement.removeEventListener('webglcontextlost',lost);geometries.forEach(g=>g.dispose());layerMaterials.flat().forEach(material=>material.dispose());gateMaterial.dispose();environment.dispose();renderer.dispose();renderer.domElement.remove();controller.current=null;};
   await renderer.compileAsync(scene,camera);
   if(disposed||cancelled)return;
   resize();wake();clearTimeout(timeout);setStatus('ready');
  }catch{clearTimeout(timeout);cleanup();if(!disposed&&!cancelled)setStatus('error');}};
  void load();return()=>{disposed=true;clearTimeout(timeout);cleanup();};
 },[attempt]);
 const toggle=()=>{const next=!expanded;setExpanded(next);controller.current?.expand(next);};
 return <figure data-object-state={status} className={'capital-object '+(ready?'webgl-ready':'')}>
  <div className="capital-object-stage" ref={host} role={ready?'img':undefined} aria-label={ready?'A three-dimensional Dynamica mark with six colored layers graduating from deep teal to citron, joined at a luminous permission checkpoint.':undefined}/>
  {status==='error'&&<div className="capital-error" role="status"><p>The 3D view couldn’t start.</p><Button variant="outline" size="sm" onClick={()=>{setExpanded(false);setStatus('loading');setAttempt(a=>a+1);}}>Retry 3D view</Button></div>}
  <div className="object-index"><span>D / 001</span><span>THE CAPITAL ENGINE</span></div>
  <figcaption className="object-caption"><div><span className="object-line"/><p>Six strategy layers.<br/><strong>One permission checkpoint.</strong></p></div>{ready&&<Button variant="ghost" className="object-toggle" onClick={toggle} aria-pressed={expanded}>{expanded?<Box size={16}/>:<Layers3 size={16}/>} {expanded?'Assemble':'Explore layers'}</Button>}</figcaption>
 </figure>;
}
