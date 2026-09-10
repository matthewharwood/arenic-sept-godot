/* Exercise every generated ability/direction/timing path without requiring a renderer. */
const fs=require('fs'),path=require('path'),vm=require('vm');
const root=path.resolve(__dirname,'../previews');
const javascript=fs.readFileSync(path.join(__dirname,'character-preview.js'),'utf8');
async function check(hero){
 const html=fs.readFileSync(path.join(root,hero,'attacks.html'),'utf8');
 const PAGE=JSON.parse(html.match(/const PAGE=(.*?);<\/script>/s)[1]);
 const nodes=new Map(),all=[];let drawing=0;
 class Element{
  constructor(tag='div'){this.tagName=tag;this.children=[];this.style={};this.value='';this.width=247;this.height=247;this.clientWidth=300;this.clientHeight=300;this.dataset={prefix:'..'};this.cache={};all.push(this);}
  append(child){child.parentElement=this;this.children.push(child);if(this.tagName==='select'&&!this.value)this.value=child.value;}
  prepend(child){this.append(child);} setAttribute(){} addEventListener(){}
  querySelector(query){if(!this.cache[query]){const child=query==='canvas'?new Element('canvas'):new Element();child.parentElement=this;this.cache[query]=child;}return this.cache[query];}
  getContext(){return new Proxy({canvas:this,drawImage(){drawing++;}},{get:(o,k)=>o[k]??(()=>{}),set:(o,k,v)=>(o[k]=v,true)});}
 }
 const defaults={direction:'e',speed:'1',scale:'1',mode:'scene',volume:'.45','arena-scale':'fit',ability:PAGE.hero.abilities[0].id};
 const document={body:new Element(),hidden:false,addEventListener(){},createElement:t=>new Element(t),getElementById(id){const existing=all.find(n=>n.id===id);if(existing)return existing;if(!nodes.has(id)){const node=new Element(id==='ability'?'select':id==='arena'?'canvas':'div');node.value=defaults[id]??'';nodes.set(id,node);}return nodes.get(id);}};
 class Image{set src(value){this.onload?.();}}
 const fetch=async url=>{const file=path.resolve(root,hero,url);return{ok:fs.existsSync(file),json:async()=>JSON.parse(fs.readFileSync(file,'utf8'))};};
 const context={PAGE,document,Image,fetch,performance:{now:()=>0},requestAnimationFrame(){},window:{addEventListener(){}},setTimeout,console};
 vm.createContext(context);vm.runInContext(javascript,context);await new Promise(ok=>setImmediate(ok));
 const result=vm.runInContext(`(()=>{
  let samples=0; const c=$('arena').getContext('2d');
  for(const s of specs)for(const dir of ['n','e','s','w']){
   $('direction').value=dir;
   const times=new Set([0,1,s.release_ms,s.preview.impact_ms,s.total,s.preview.duration_ms,s.cycle-1]);
   let elapsed=0;for(const duration of s.durations_ms){times.add(elapsed);times.add(elapsed+duration-1);elapsed+=duration;}
   for(let t=0;t<s.cycle;t+=50)times.add(t);
   for(const t of times){scene(s,c,t);drawArena(s,t);samples++;}
   if(s.id==='helix')for(const mode of ['regeneration','haste']){$('helix-state').value=mode;scene(s,c,1200);}
   if(s.id==='mushroom')for(const mode of ['seed','sprout','young','mature','ancient']){$('growth').value=mode;scene(s,c,1200);}
  }
  return {hero:hero.id,abilities:specs.length,samples};
 })()`,context);
 if(document.getElementById('load-error').textContent)throw Error(hero+': '+document.getElementById('load-error').textContent);
 if(!drawing)throw Error(hero+': no native frames drawn');return{...result,frame_draws:drawing};
}
(async()=>{const roster=['hunter','warrior','thief','alchemist','cardinal','bard','forager','merchant'];const reports=[];for(const h of roster){if(fs.existsSync(path.join(root,h,'attacks.html'))){const report=await check(h);reports.push(report);console.log(JSON.stringify(report));}}fs.writeFileSync(path.join(root,'validation.json'),JSON.stringify({kind:'preview execution and native tag coverage',reports},null,2)+'\n');})().catch(e=>{console.error(e);process.exitCode=1;});
