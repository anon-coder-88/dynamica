'use client';
import {useEffect,useRef,useState,type CSSProperties} from 'react';
import {Button} from '@/components/ui/button';
import {transitionDestination} from '@/lib/page-transitions';
const names:Record<string,string>={'/':'Dynamica','/app':'Your workspace','/ecosystem':'The ecosystem','/token':'Token Studio','/docs':'Documentation','/risks':'Risks & disclosures'};

export function PageTransitions(){
 const [visible,setVisible]=useState(false),[label,setLabel]=useState('Preparing your page'),[compact,setCompact]=useState(false);
 const release=useRef<()=>void>(()=>{});
 useEffect(()=>{
  const root=document.documentElement,content=document.getElementById('site-content');
  let disposed=false,navigating=false,finishTimer=0,removeTimer=0,navigationTimer=0,failsafe=0;
  const motionAllowed=()=>{if(matchMedia('(prefers-reduced-motion: reduce)').matches)return false;try{return localStorage.getItem('dynamica:motion')!=='off';}catch{return true;}};
  const unlock=()=>{if(content?.hasAttribute('data-intro-inert')){content.inert=false;content.removeAttribute('data-intro-inert');}};
  const lock=()=>{if(content&&!content.inert){content.inert=true;content.setAttribute('data-intro-inert','');}};
  const clear=()=>{if(disposed)return;delete root.dataset.pageLoading;unlock();setVisible(false);};
  const finish=(immediate=false)=>{clearTimeout(finishTimer);clearTimeout(failsafe);if(!root.dataset.pageLoading){clear();return;}root.dataset.pageLoading=immediate||!motionAllowed()?'':'revealing';unlock();const skip=document.getElementById('skip-page-intro');if(document.activeElement===skip){const main=document.getElementById('main');main?.setAttribute('tabindex','-1');main?.focus({preventScroll:true});}if(immediate||!motionAllowed())clear();else removeTimer=window.setTimeout(clear,650);};
  release.current=()=>finish();
  const started=performance.now(),incoming=root.dataset.pageLoading==='incoming';
  const checkReady=()=>{if(navigating||!root.dataset.pageLoading||root.dataset.pageLoading==='revealing')return;const hero=document.querySelector<HTMLElement>('.capital-object');if(hero&&hero.dataset.objectState==='loading')return;clearTimeout(finishTimer);finishTimer=window.setTimeout(()=>finish(),Math.max(0,(incoming?160:850)-(performance.now()-started)));};
  if(root.dataset.pageLoading){lock();queueMicrotask(()=>{if(!disposed){setVisible(true);setCompact(incoming);}});checkReady();failsafe=window.setTimeout(()=>finish(),incoming?1800:3200);}
  const heroReady=()=>checkReady();window.addEventListener('dynamica:hero-state',heroReady);
  const onClick=(event:MouseEvent)=>{
   const anchor=(event.target as Element)?.closest<HTMLAnchorElement>('a[href]');if(!anchor)return;
   const destination=transitionDestination(anchor.href,location.href,{button:event.button,modified:event.metaKey||event.ctrlKey||event.shiftKey||event.altKey,target:anchor.target,download:anchor.hasAttribute('download'),prevented:event.defaultPrevented});
   if(!destination||!motionAllowed())return;
   event.preventDefault();if(navigating)return;navigating=true;
   clearTimeout(finishTimer);clearTimeout(removeTimer);clearTimeout(failsafe);
   const target=new URL(destination);setLabel('Opening '+(names[target.pathname]||'Dynamica'));setVisible(true);setCompact(true);lock();root.dataset.pageLoading='leaving';
   try{sessionStorage.setItem('dynamica:arrival',JSON.stringify({path:target.pathname+target.search,at:Date.now()}));}catch{}
   navigationTimer=window.setTimeout(()=>{try{location.assign(destination);}catch{navigating=false;finish(true);}},420);
   failsafe=window.setTimeout(()=>{navigating=false;finish(true);},5000);
  };
  // Bubble phase lets app navigation handlers and modified clicks retain their native behavior.
  document.addEventListener('click',onClick);
  const restore=(event:PageTransitionEvent)=>{if(event.persisted){clearTimeout(navigationTimer);navigating=false;finish(true);}};
  window.addEventListener('pageshow',restore);
  const preferences=matchMedia('(prefers-reduced-motion: reduce)');const reduced=()=>{if(preferences.matches&&!navigating)finish(true);};preferences.addEventListener('change',reduced);
  return()=>{disposed=true;clearTimeout(finishTimer);clearTimeout(removeTimer);clearTimeout(navigationTimer);clearTimeout(failsafe);unlock();delete root.dataset.pageLoading;window.removeEventListener('dynamica:hero-state',heroReady);document.removeEventListener('click',onClick);window.removeEventListener('pageshow',restore);preferences.removeEventListener('change',reduced);};
 },[]);
 return <div className="page-transition" data-compact={compact} aria-hidden={!visible}>
  <div className="transition-panels" aria-hidden="true"><i/><i/><i/></div>
  <div className="page-intro-center"><div className="intro-symbol" aria-hidden="true"><svg viewBox="0 0 100 100"><path pathLength="1" d="M12 8H46C72 8 90 22 94 40H75C71 31 60 26 46 26H30V74H46C60 74 71 69 75 60H94C90 78 72 92 46 92H12Z"/><rect x="80" y="43" width="14" height="14"/></svg></div><div className="intro-wordmark" aria-hidden="true">{'dynamica.'.split('').map((letter,i)=><span key={i} style={{'--letter':i} as CSSProperties}>{letter}</span>)}</div><div className="intro-signal" aria-hidden="true"><i/></div><p role="status" aria-live="polite" aria-atomic="true">{visible?label:''}</p></div>
  <div className="intro-corners" aria-hidden="true"><span>D / CONTROLLED MOTION</span><span>INTENT · PERMISSIONS · EXECUTION</span></div>
  <Button id="skip-page-intro" className="skip-page-intro" variant="ghost" tabIndex={visible?0:-1} onClick={()=>release.current()}>Skip intro</Button>
 </div>;
}
