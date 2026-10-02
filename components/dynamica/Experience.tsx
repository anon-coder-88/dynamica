'use client';
import {useEffect,useRef,useState} from 'react';
import {Volume2,VolumeX,Pause,Play} from 'lucide-react';
import {Button} from '@/components/ui/button';

/** Optional presentation effects. No sound, tracking, or financial actions on load. */
export function Experience(){
 const [motion,setMotion]=useState(false),[reduced,setReduced]=useState(false),[sound,setSound]=useState(false),[audioError,setAudioError]=useState('');
 const context=useRef<AudioContext|null>(null);
 useEffect(()=>{
  const preference=matchMedia('(prefers-reduced-motion: reduce)');
  let enabled=!preference.matches;
  try{const saved=localStorage.getItem('dynamica:motion');if(saved!==null)enabled=saved==='on'&&!preference.matches;}catch{}
  queueMicrotask(()=>{setMotion(enabled);setReduced(preference.matches);});
  const update=()=>{setReduced(preference.matches);if(preference.matches)setMotion(false);};
  preference.addEventListener('change',update);
  return()=>preference.removeEventListener('change',update);
 },[]);
 useEffect(()=>{
  document.body.dataset.motion=motion?'on':'off';
  if(!motion)return;
  const targets=document.querySelectorAll('.section-heading,.module-card,.control-section,.strategy-row,.start-section,.public-inner .article,.landing-intro-heading,.ecosystem-browser,.landing-strategies h2,.catalog-row,.landing-close');
  if(!('IntersectionObserver' in window))return;
  const observer=new IntersectionObserver(entries=>{for(const entry of entries){if(entry.isIntersecting){entry.target.classList.add('revealed');observer.unobserve(entry.target);}}},{threshold:.08});
  targets.forEach((node,i)=>{(node as HTMLElement).style.setProperty('--reveal-delay',`${Math.min(i%3*75,150)}ms`);node.classList.add('reveal-target');observer.observe(node);});
  const hero=document.querySelector<HTMLElement>('.hero-art');
  let frame=0;
  const pointer=(event:PointerEvent)=>{if(event.pointerType!=='mouse'||!hero)return;cancelAnimationFrame(frame);frame=requestAnimationFrame(()=>{const rect=hero.getBoundingClientRect();hero.style.setProperty('--tilt-x',`${-(event.clientY-rect.top-rect.height/2)/rect.height*5}deg`);hero.style.setProperty('--tilt-y',`${(event.clientX-rect.left-rect.width/2)/rect.width*7}deg`);});};
  const reset=()=>{if(hero){hero.style.setProperty('--tilt-x','0deg');hero.style.setProperty('--tilt-y','0deg');}};
  hero?.addEventListener('pointermove',pointer);hero?.addEventListener('pointerleave',reset);
  return()=>{observer.disconnect();targets.forEach(node=>node.classList.remove('reveal-target'));cancelAnimationFrame(frame);hero?.removeEventListener('pointermove',pointer);hero?.removeEventListener('pointerleave',reset);reset();};
 },[motion]);
 const tone=async(confirm=false)=>{
  try{
   const Audio=window.AudioContext||(window as unknown as {webkitAudioContext?:typeof AudioContext}).webkitAudioContext;
   if(!Audio)throw Error('Audio unsupported');
   if(!context.current)context.current=new Audio();
   const audio=context.current;
   if(audio.state==='suspended')await audio.resume();
   const now=audio.currentTime;
   const oscillator=audio.createOscillator(),gain=audio.createGain();
   oscillator.type='sine';oscillator.frequency.setValueAtTime(confirm?660:440,now);oscillator.frequency.exponentialRampToValueAtTime(confirm?880:330,now+.07);
   gain.gain.setValueAtTime(0,now);gain.gain.linearRampToValueAtTime(.028,now+.008);gain.gain.exponentialRampToValueAtTime(.0001,now+.11);
   oscillator.connect(gain);gain.connect(audio.destination);oscillator.start(now);oscillator.stop(now+.12);oscillator.onended=()=>{oscillator.disconnect();gain.disconnect();};
  }catch{setSound(false);setAudioError('Sound is unavailable in this browser.');}
 };
 useEffect(()=>{
  if(!sound)return;
  const click=(event:MouseEvent)=>{const element=(event.target as Element).closest('button,a[href]');if(!element||element.closest('.experience-dock')||element.hasAttribute('disabled')||element.getAttribute('aria-disabled')==='true')return;void tone();};
  document.addEventListener('click',click);
  return()=>document.removeEventListener('click',click);
 },[sound]);
 useEffect(()=>()=>{void context.current?.close();},[]);
 return <aside className="experience-dock" aria-label="Motion and sound preferences">
  <Button variant="ghost" size="sm" aria-pressed={motion} disabled={reduced} onClick={()=>{const next=!motion;setMotion(next);try{localStorage.setItem('dynamica:motion',next?'on':'off');}catch{}}} title={reduced?'Reduced motion is enabled in your device settings':motion?'Pause decorative motion':'Enable decorative motion'}>{motion?<Pause size={14}/>:<Play size={14}/>}<span>Motion {motion?'on':'off'}</span></Button>
  <span className="dock-divider"/>
  <Button variant="ghost" size="sm" aria-pressed={sound} onClick={()=>{setAudioError('');const next=!sound;setSound(next);if(next)void tone(true);}} title={sound?'Mute interface sounds':'Enable quiet interface sounds'}>{sound?<Volume2 size={15}/>:<VolumeX size={15}/>}<span>Sound {sound?'on':'off'}</span></Button>
  {audioError&&<span role="status" className="audio-error">{audioError}</span>}
 </aside>;
}
