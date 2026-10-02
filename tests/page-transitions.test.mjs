import assert from 'node:assert/strict';
import {test} from 'node:test';
import vm from 'node:vm';
import {transitionDestination,pageTransitionBoot} from '../lib/page-transitions.ts';
const current='https://dynamica.example/';
test('public route and workspace links qualify for transitions',()=>{
 assert.equal(transitionDestination('/ecosystem',current),'https://dynamica.example/ecosystem');
 assert.equal(transitionDestination('/app?view=vaults',current),'https://dynamica.example/app?view=vaults');
 assert.equal(transitionDestination('/docs#methodology',current),'https://dynamica.example/docs#methodology');
});
test('native link behavior is preserved for non-navigation and modified clicks',()=>{
 for(const href of ['#ecosystem','/','https://other.example/docs','mailto:team@example.com','javascript:void(0)','/brand/mark.svg','http://['])assert.equal(transitionDestination(href,current),null,href);
 for(const options of [{modified:true},{button:1},{target:'_blank'},{download:true},{prevented:true}])assert.equal(transitionDestination('/docs',current,options),null,JSON.stringify(options));
 assert.equal(transitionDestination('/docs#next','https://dynamica.example/docs'),null);
});
function boot({reduced=false,motion=null,arrival=null,storageError=false}={}){
 const dataset={},attributes=new Set(['inert','data-intro-inert']),timers=[];
 const context={document:{documentElement:{dataset},getElementById:()=>({hasAttribute:k=>attributes.has(k),removeAttribute:k=>attributes.delete(k)})},location:{pathname:'/docs',search:''},matchMedia:()=>({matches:reduced}),localStorage:{getItem:()=>{if(storageError)throw Error('blocked');return motion;}},sessionStorage:{getItem:()=>JSON.stringify(arrival),removeItem:()=>{}},setTimeout:(fn,delay)=>timers.push({fn,delay})};
 vm.runInNewContext(pageTransitionBoot,context);
 return {dataset,attributes,timers};
}
test('initial loader has an independent release if hydration fails',()=>{
 const result=boot();assert.equal(result.dataset.pageLoading,'initial');assert.equal(result.timers[0].delay,5500);
 result.timers[0].fn();assert.equal(result.dataset.pageLoading,undefined);assert.equal(result.attributes.size,0);
});
test('reduced motion and saved motion-off preference bypass the intro',()=>{
 for(const settings of [{reduced:true},{motion:'off'}]){const result=boot(settings);assert.equal(result.dataset.pageLoading,undefined);assert.equal(result.timers.length,0);}
});
test('only a recent matching navigation uses the shorter arrival',()=>{
 assert.equal(boot({arrival:{path:'/docs',at:Date.now()}}).dataset.pageLoading,'incoming');
 assert.equal(boot({arrival:{path:'/token',at:Date.now()}}).dataset.pageLoading,'initial');
 assert.equal(boot({arrival:{path:'/docs',at:Date.now()-11000}}).dataset.pageLoading,'initial');
 assert.equal(boot({storageError:true}).dataset.pageLoading,'initial');
});
