'use strict';
const {hero,sprites,roster}=PAGE;
const $=id=>document.getElementById(id), vectors={n:[0,-1],e:[1,0],s:[0,1],w:[-1,0]},angles={n:-Math.PI/2,e:0,s:Math.PI/2,w:Math.PI};
const key=path=>path.replace(/\.aseprite$/,'');
const specs=hero.abilities.map(a=>({...a,total:a.durations_ms.reduce((x,y)=>x+y,0),cycle:Math.max(2500,a.preview.duration_ms+400)}));
let now=0,running=true,ready=false,last=performance.now(),soundEnabled=false,activeAudio=new Set(),contextAudio=null;
const arena=$('arena'),ctx=arena.getContext('2d');
for(const [name,path]of [['Heroes','index.html'],['Bosses','bosses/index.html']]){const a=document.createElement('a');a.href=document.body.dataset.prefix+'/'+path;a.textContent=name;if(name==='Heroes')a.setAttribute('aria-current','page');$('character-types').append(a);}
let arenaBoss=null,bossRequest=0;
async function chooseBoss(){const request=++bossRequest,id=$('boss-choice').value;arenaBoss=null;if(!id){render();return;}try{const base=document.body.dataset.prefix+'/bosses/'+id+'/';const response=await fetch(base+id+'.json');if(!response.ok)throw Error('Boss data unavailable');const content=await response.json(),img=new Image();await new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=reject;img.src=base+id+'.png';});if(request!==bossRequest)return;arenaBoss={id,img,frames:content.frames,tags:content.meta.frameTags};render();}catch(error){if(request===bossRequest)$('load-error').textContent='Boss preview could not load: '+id;}}
$('boss-choice').onchange=chooseBoss;
fetch(document.body.dataset.prefix+'/bosses/gallery.json').then(r=>{if(!r.ok)throw Error('Boss gallery unavailable');return r.json();}).then(bosses=>{for(const boss of bosses){const o=document.createElement('option');o.value=boss.id;o.textContent=boss.name;$('boss-choice').append(o);}if(bosses.some(b=>b.id===hero.id)){$('boss-choice').value=hero.id;chooseBoss();}}).catch(()=>{});
$('title').textContent=`One ${hero.name}. One 19-pixel tile.`;document.title=`${hero.name} · 19px overhead abilities`;
$('portrait').src=hero.portrait_image;$('portrait').alt=hero.name+' portrait reference';
for(const h of roster){const a=document.createElement('a');a.href=document.body.dataset.prefix+'/'+h.id+'/attacks.html';a.textContent=h.name;if(h.id===hero.id)a.setAttribute('aria-current','page');$('heroes').append(a);}
const index=document.createElement('a');index.href=document.body.dataset.prefix+'/index.html';index.textContent='All heroes';$('heroes').prepend(index);
for(const s of specs){const o=document.createElement('option');o.value=s.id;o.textContent=s.name;$('ability').append(o);}
function variant(id,label,options){const l=document.createElement('label');l.textContent=label+' ';const select=document.createElement('select');select.id=id;for(const [value,name]of options){const o=document.createElement('option');o.value=value;o.textContent=name;select.append(o);}select.onchange=()=>{stopSounds();now=0;render();};l.append(select);$('variant-controls').append(l);}
if(hero.id==='bard')variant('helix-state','Helix mode',[['regeneration','Regeneration'],['haste','Haste']]);
if(hero.id==='forager')variant('growth','Symbiosis node',[['seed','Seed · no healing'],['sprout','Sprout · resource-fed'],['young','Young · resource-fed'],['mature','Mature · resource-fed'],['ancient','Ancient · resource-fed']]);
function frameAt(s,t,tag,loop=false){const range=tag?s.tags.find(x=>x.name===tag):null;if(tag&&!range)throw Error('Missing tag '+tag);const start=range?range.from:0,end=range?range.to:s.frames.length-1;const duration=s.frames.slice(start,end+1).reduce((n,f)=>n+f.duration,0);if(loop)t=((t%duration)+duration)%duration;for(let i=start;i<=end;i++){if(t<s.frames[i].duration)return i;t-=s.frames[i].duration;}return end;}
function draw(c,path,t,x,y,tag,loop=false,angle=0){const s=sprites[key(path)];if(!s)throw Error('Missing sprite '+path);const f=s.frames[frameAt(s,t,tag,loop)].frame;c.save();c.translate(Math.round(x)+.5,Math.round(y)+.5);c.rotate(angle);c.drawImage(s.img,f.x,f.y,f.w,f.h,-s.pivot[0]-.5,-s.pivot[1]-.5,f.w,f.h);c.restore();}
function circle(c,x,y,r,fill,stroke){c.beginPath();c.arc(x+.5,y+.5,r,0,Math.PI*2);c.fillStyle=fill;c.fill();if(stroke){c.strokeStyle=stroke;c.lineWidth=1;c.stroke();}}
function grid(c,w,h,ox=0,oy=0,cols=Math.floor(w/19),rows=Math.floor(h/19)){c.fillStyle='oklch(.97 .009 95)';c.fillRect(0,0,w,h);c.fillStyle='oklch(.67 .024 150)';for(let r=0;r<=rows;r++)for(let n=0;n<=cols;n++)c.fillRect(ox+n*19,oy+r*19,1,1);}
function tile(c,p){c.strokeStyle='oklch(.55 .14 160)';c.lineWidth=1;c.strokeRect(p[0]-9+.5,p[1]-9+.5,18,18);}
function step(p,dir,n){const v=vectors[dir];return[p[0]+v[0]*19*n,p[1]+v[1]*19*n];}
function label(c,p,text){c.font='9px system-ui';c.fillStyle='oklch(.34 .04 150)';c.textAlign='center';c.fillText(text,p[0],p[1]+20);c.textAlign='left';}
function actor(c,s,t,p,dir){
 const source=sprites[key(s.actor)],holdName=dir+(['heal','siphon'].includes(s.id)?'_channel':'_hold');
 const hold=['heal','siphon','block'].includes(s.id)?source.tags.find(a=>a.name===holdName):null;
 const full=source.tags.find(a=>a.name===s.id+'_'+dir);
 if(hold){
  const begins=source.frames.slice(full.from,hold.from).reduce((n,f)=>n+f.duration,0);
  const release=source.tags.find(a=>a.name===dir+'_release')||source.tags.find(a=>a.name===dir+'_lower');
  const releaseDuration=release?source.frames.slice(release.from,release.to+1).reduce((n,f)=>n+f.duration,0):200;
  const holdEnd=s.preview.duration_ms-releaseDuration;
  if(t>=begins&&t<holdEnd){draw(c,s.actor,t-begins,...p,holdName,true);return;}
  if(release&&t>=holdEnd){draw(c,s.actor,t-holdEnd,...p,release.name);return;}
 }
 draw(c,s.actor,t,...p,s.id+'_'+dir);
}
function selected(){return specs.find(s=>s.id===$('ability').value);}
function phase(s,t){if(s.id==='mimic')return t<500?'Ally attack → passive echo':t<900?'Echo after 500 ms':'Copied attack · staged proc';if(s.id==='dance')return t<4000?`Beat ${Math.min(8,Math.floor(t/500)+1)} / 8`:'Successful finale';if(s.id==='trap')return t<500?'Place · active immediately':t<1200?'Armed · staged approach':'Triggered on collision';if(s.id==='mushroom')return $('growth').value==='seed'?'Seed · no healing':'Resource-fed '+$('growth').value;if(t<s.release_ms)return s.audio.charge?'Charge / hold':'Preparation';if(t<s.preview.impact_ms)return s.preview.type==='blink'?'Transit':s.preview.type==='self'?'Active guard / buff':'Travel';if(t<s.total)return 'Resolve / recovery';if(t<s.preview.duration_ms)return 'Effect / held state';return 'Reset pause';}
function action(c,s,t,origin,target,dir){
 const [dx,dy]=vectors[dir],hit=s.preview.impact_ms,release=s.release_ms,end=s.preview.duration_ms;
 let p=[...origin];
 if(hero.id==='hunter'&&((s.id==='poison_shot'&&t>=500)||(s.id==='trap'&&t>=500)))p=step(origin,dir,-1);
 if(s.preview.type==='blink'&&t>=0)p=step(origin,dir,Math.min(4,Math.floor(t/50)));
 const self=s.preview.target==='self'||s.preview.type==='self';
 const point=self?p:target;
 function fx(i,at=point,begin=hit,finish=null,override={}){
  const f=s.fx[i];if(!f)return;let tag=override.tag||f.tag,loop=override.loop??f.loop;
  const until=finish??(loop?end:begin+f.duration_ms);if(t<begin||t>=until)return;
  const source=sprites[key(f.source)],suffix=tag.match(/_([nesw])$/);let angle=0;
  if(suffix){const directional=tag.slice(0,-1)+dir;if(source.tags.some(x=>x.name===directional))tag=directional;else angle=angles[dir]-angles[suffix[1]];}
  else if(['projectile','beam','trail'].includes(f.role))angle=angles[dir];
  if(override.angle!==undefined)angle=override.angle;
  draw(c,f.source,t-begin,...at,tag,loop,angle);
 }
 function traveling(i=0){if(t<release||t>=hit)return;const distance=Math.round((Math.abs(target[0]-origin[0])+Math.abs(target[1]-origin[1]))/19);const progress=Math.min(distance,1+Math.floor((t-release)/(hit-release)*Math.max(1,distance-1)));fx(i,step(origin,dir,progress),release,hit);}
 function link(i,from=origin,to=target,begin=release,finish=end){
  const f=s.fx[i];if(!f||t<begin||t>=finish)return;
  const sprite=sprites[key(f.source)],attachment=step(from,dir,Math.floor(sprite.pivot[0]/19));
  fx(i,attachment,begin,finish);
 }
 // Target markers are scene fixtures, not extra generated effects or game logic.
 if(s.preview.target==='ally'){
  const dead=hero.id==='cardinal'&&s.id==='resurrect'&&t<hit;
  circle(c,...target,7,dead?'oklch(.75 .005 140)':'oklch(.73 .09 230)','oklch(.40 .04 230)');label(c,target,dead?'Fallen ally':'Ally');
 }else if(s.preview.target==='ground'&&!['shadow_step','trap'].includes(s.id)){tile(c,target);}
 if(hero.id==='hunter'){
  if(s.id==='trap'){
   fx(0,origin,0,500);fx(1,origin,500,1200);fx(2,origin,1200,1300);fx(3,origin,1200,2200);
   if(t>=500&&t<1200)circle(c,...step(origin,dir,t<900?2:1),6,'oklch(.62 .08 25)','oklch(.33 .05 25)');
  }else{traveling();fx(1,target);if(s.id==='poison_shot')fx(2,target);if(s.id==='sniper')fx(2,target,0,500);}
 }else if(hero.id==='warrior'){
  if(s.id==='bash'){fx(0,target);fx(1,target,0,end);}
  if(s.id==='block'){fx(0,p,0,end);fx(1,step(p,dir,1),300);if(t<300)circle(c,...step(p,dir,t<150?3:2),2,'oklch(.54 .05 25)');}
  if(s.id==='taunt'){fx(0,target);fx(1,target);}
  if(s.id==='bulwark'){fx(0,p,0,end);fx(1,step(p,dir,1),500);if(t<500)circle(c,...step(p,dir,t<250?3:2),2,'oklch(.54 .05 25)');}
 }else if(hero.id==='thief'){
  if(s.id==='backstab'){fx(0,target);fx(1,target);label(c,target,'Back exposed');}
  if(s.id==='pickpocket'){fx(0,target);fx(1,step(origin,dir,1));}
  if(s.id==='smoke_screen'){fx(0,target,0,end);fx(1,target,700);label(c,target,'Redirect zone');}
  if(s.id==='shadow_step'){
   fx(0,origin,0,300);if(t<200)for(let i=1;i<=4;i++)fx(1,step(origin,dir,i),0,200);
   fx(0,p,200,500,{tag:'arrive'});fx(2,p,0,1000);
  }
 }else if(hero.id==='alchemist'){
  if(s.id==='acid_flask'){traveling();fx(1,target);fx(2,target);}
  if(s.id==='ironskin_draft'){fx(0,p);fx(1,p);}
  if(s.id==='siphon'){link(0,p,target);fx(1,target);fx(2,p);label(c,target,'Donor ally');}
  if(s.id==='transmute'){circle(c,...target,4,'oklch(.67 .06 80)','oklch(.34 .03 80)');link(0,origin,target,0,release);fx(1,target);label(c,target,'Item conversion');}
 }else if(hero.id==='cardinal'){
  if(s.id==='heal'){link(0);fx(1,target);fx(2,target);}
  if(s.id==='barrier'){fx(0,target);fx(1,target);}
  if(s.id==='beam'){link(0,origin,step(origin,dir,8),release,release+1500);fx(1,target);}
  if(s.id==='resurrect'){fx(0,target);fx(1,target);}
 }else if(hero.id==='bard'){
  if(s.id==='mimic'){
   // A plain qualifying ally strike is staged, followed by its matching echo.
   const enemy=step(target,dir,2);circle(c,...enemy,6,'oklch(.72 .06 30)','oklch(.4 .04 30)');
   if(t<400){const q=step(target,dir,t<200?1:2);circle(c,...q,2,'oklch(.58 .04 90)');}
   if(t>=500&&t<900){const q=step(p,dir,1+Math.floor((t-500)/400*2));circle(c,...q,2,'oklch(.58 .04 90)');}
   fx(0,p,500);fx(1,enemy,900);label(c,target,'Adjacent ally');
  }
  if(s.id==='dance'){fx(0,p,0,4000);fx(1,p,4000);}
  if(s.id==='cleanse'){fx(0,p,0);fx(1,target,0);}
  if(s.id==='helix'){fx($('helix-state').value==='haste'?1:0,p,0,end);fx(2,p,0,600);}
 }else if(hero.id==='forager'){
  if(s.id==='dig'){fx(0,target,0,800);fx(1,target,800,end);}
  if(s.id==='bolder'){traveling();fx(1,target);}
  if(s.id==='border'){
   // The prepared tile is a prerequisite; grow resolves at the real 1500ms cast end.
   c.fillStyle='oklch(.74 .035 70)';c.fillRect(target[0]-8,target[1]-8,17,17);
   fx(0,target,0,1500);fx(1,target,1500,end);fx(2,target,2500);label(c,target,'Prepared soil');
  }
  if(s.id==='mushroom'){
   const stage=$('growth').value,index=['seed','sprout','young','mature','ancient'].indexOf(stage);
   fx(index,target,release,end);if(index>0){link(5,origin,target,release,Math.min(end,release+1000));fx(6,target,release,end);}
   label(c,target,index?'Resources invested':'Seed · no heal');
  }
 }else if(hero.id==='merchant'){
  if(s.id==='coin_toss'){traveling();fx(1,target);}
  if(s.id==='dice'){fx(0,p,0,500);fx(1,p,500,end);fx(2,p,500);}
  if(s.id==='fortune'){fx(0,p,0,end);fx(1,target,0);}
  if(s.id==='vault'){fx(0,target,0,700);fx(1,target,700,end);fx(2,target,1200);label(c,target,'Critical buff zone');}
 }
 tile(c,p);actor(c,s,t,p,dir);return p;
}
function scene(s,c,t){const dir=$('direction').value,solo=$('mode').value==='actor';grid(c,c.canvas.width,c.canvas.height);if(solo){c.fillStyle='oklch(.97 .009 95)';c.fillRect(0,0,19,19);actor(c,s,t,[9,9],dir);return;}
 let start=step([123,123],dir,-1),target=step(start,dir,3);
 if(s.preview.type==='melee')target=step(start,dir,1);
 if(['heal','siphon'].includes(s.id))target=step(start,dir,4);
 if(['transmute','mushroom','fortune'].includes(s.id))target=step(start,dir,2);
 if(['dig','mimic','cleanse'].includes(s.id))target=step(start,dir,1);
 if(s.preview.type==='blink'){start=step([123,123],dir,-2);target=step(start,dir,4);}
 if(hero.id==='cardinal'&&s.id==='beam'){start=step([123,123],dir,-4);target=step(start,dir,6);}
 if(s.preview.target==='boss'&&s.preview.type!=='self')circle(c,...target,7,'oklch(.77 .035 25)','oklch(.40 .035 25)');
 action(c,s,t,start,target,dir);
}
function drawArena(s,t){const dir=$('direction').value,[dx,dy]=vectors[dir],ox=13,oy=35;grid(ctx,1280,720,ox,oy,66,31);ctx.fillStyle='oklch(.94 .015 95)';ctx.fillRect(0,0,1280,29);ctx.fillRect(0,638,1280,82);ctx.font='12px system-ui';ctx.fillStyle='oklch(.29 .025 150)';ctx.fillText(hero.name.toUpperCase()+'   /   '+s.name.toUpperCase(),22,20);ctx.fillText('OVERHEAD  ·  19 PX / TILE  ·  SOURCE PREVIEW',907,20);
 ctx.strokeStyle='oklch(.64 .028 145)';ctx.lineWidth=2;for(const[a,b,c,d]of[[4,4,4,30],[9,0,9,26],[19,0,19,30],[25,4,25,30],[25,4,36,4],[40,0,40,25],[30,26,40,26],[46,3,46,30],[56,0,56,25],[61,0,61,26]]){ctx.beginPath();ctx.moveTo(ox+a*19+.5,oy+b*19+.5);ctx.lineTo(ox+c*19+.5,oy+d*19+.5);ctx.stroke();}
 const boss=[ox+33*19+9,oy+15*19+9];if(arenaBoss){const f=arenaBoss.frames[frameAt(arenaBoss,now,'idle_'+dir,true)].frame;ctx.drawImage(arenaBoss.img,f.x,f.y,f.w,f.h,boss[0]-57,boss[1]-57,114,114);}else{circle(ctx,...boss,57,'oklch(.58 .12 30)','oklch(.31 .055 30)');circle(ctx,...boss,41,'oklch(.66 .12 35)');circle(ctx,...boss,21,'oklch(.72 .10 55)');}label(ctx,[boss[0],boss[1]+48],'BOSS');
 let start=step(boss,dir,s.preview.type==='melee'?-4:-7),target=step(boss,dir,-3);
 if(s.preview.target==='ally'||s.preview.target==='ground')target=step(start,dir,2);
 if(['heal','siphon'].includes(s.id))target=step(start,dir,4);
 if(['dig','mimic','cleanse'].includes(s.id))target=step(start,dir,1);
 const p=action(ctx,s,t,start,target,dir);ctx.strokeStyle='oklch(.42 .075 145)';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(p[0]+11,p[1]-11);ctx.lineTo(p[0]+28,p[1]-28);ctx.stroke();ctx.fillStyle='oklch(.27 .04 150)';ctx.font='11px system-ui';ctx.fillText(hero.name+' · 19 × 19',p[0]+31,p[1]-28);
 ctx.fillStyle='oklch(.29 .03 150)';ctx.font='13px system-ui';ctx.fillText(phase(s,t)+'  ·  '+Math.floor(t)+' ms',24,665);ctx.font='11px system-ui';ctx.fillText('Tile ('+Math.round((p[0]-ox-9)/19)+', '+Math.round((p[1]-oy-9)/19)+')  ·  '+dir.toUpperCase()+'  ·  '+s.frames_per_direction+' frames per direction',24,687);
 specs.forEach((a,i)=>{const x=705+i*140;ctx.fillStyle=a.id===s.id?'oklch(.79 .07 145)':'oklch(.90 .02 95)';ctx.fillRect(x,651,128,45);ctx.strokeStyle='oklch(.57 .025 145)';ctx.strokeRect(x+.5,651.5,127,44);ctx.fillStyle='oklch(.28 .04 145)';ctx.font='12px system-ui';ctx.fillText(a.name,x+10,678);});
}
function stopSounds(){for(const a of activeAudio){a.pause();a.currentTime=0;}activeAudio.clear();}
function conditionAllows(cue){const c=cue.preview_window?.condition;return !c||c.values.includes($(c.control)?.value);}
function playCue(s,phase,manual=false){
 const cue=s.sounds[phase];if(!cue?.url||(!soundEnabled&&!manual)||(!manual&&!conditionAllows(cue)))return;
 const audio=new Audio(cue.url);audio.volume=Number($('volume').value);audio.loop=cue.loop;audio.playbackRate=Number($('speed').value);
 audio.previewEnd=cue.preview_window?.end_ms??s.preview.duration_ms;audio.manualAudition=manual;
 activeAudio.add(audio);audio.onended=()=>activeAudio.delete(audio);
 audio.play().catch(()=>{activeAudio.delete(audio);$('sound-status').textContent='Use Enable sound to allow playback.';});
 if(manual&&cue.loop)setTimeout(()=>{audio.pause();activeAudio.delete(audio);},3000);
}
function cueTimes(s){return Object.fromEntries(Object.entries(s.sounds).map(([phase,cue])=>[phase,cue.preview_window.start_ms]));}
function startActiveSounds(s,t){
 for(const [phase,cue]of Object.entries(s.sounds)){
  const w=cue.preview_window;if(w.start_ms===t||((cue.loop||phase==='charge')&&t>=w.start_ms&&t<w.end_ms))playCue(s,phase);
 }
}
function scheduleSounds(s,before,after){
 if(!soundEnabled)return;if(after<before){stopSounds();before=-1;}
 for(const[phase,t]of Object.entries(cueTimes(s)))if(t>before&&t<=after)playCue(s,phase);
 for(const audio of activeAudio)if(!audio.manualAudition&&after>=audio.previewEnd){audio.pause();activeAudio.delete(audio);}
}

for(const s of specs){const article=document.createElement('article');article.className='panel';article.innerHTML=`<div class="bar"><h2></h2><span class="badge">${s.frames_per_direction}f × 4 · ${s.total} ms</span></div><div class="stage"><canvas width="247" height="247"></canvas></div><div class="caption"><div class="phase"></div><p class="description"></p><div class="cue-buttons"></div><details><summary>Base behavior & source notes</summary><ul class="notes"></ul><p class="readme"></p></details></div>`;article.querySelector('h2').textContent=s.name;article.querySelector('.description').textContent=s.description;article.querySelector('.readme').textContent=`Source ID: ${hero.id}/${s.id} · release ${s.release_ms} ms · example impact ${s.preview.impact_ms} ms`;
 for(const n of s.notes){const li=document.createElement('li');li.textContent=n;article.querySelector('ul').append(li);}for(const [phase,cue]of Object.entries(s.sounds)){const b=document.createElement('button');b.textContent=phase+(cue.status==='ready'?' ▶':' · pending');b.disabled=cue.status!=='ready';b.onclick=()=>{stopSounds();playCue(s,phase,true);};article.querySelector('.cue-buttons').append(b);}
 $('cards').append(article);s.canvas=article.querySelector('canvas');s.canvas.setAttribute('aria-label',s.name+' overhead animation');s.ctx=s.canvas.getContext('2d');s.phaseLabel=article.querySelector('.phase');}
const readyCues=specs.flatMap(s=>Object.values(s.sounds)).filter(c=>c.status==='ready').length,totalCues=specs.flatMap(s=>Object.values(s.sounds)).length;
$('sound-status').textContent=readyCues?`${readyCues} / ${totalCues} sound cues ready`:'Sounds pending · ElevenLabs connection needs a valid key';$('sound').disabled=readyCues===0;
function resize(){for(const s of specs){const size=$('mode').value==='actor'?19:247;s.canvas.width=size;s.canvas.height=size;s.ctx.imageSmoothingEnabled=false;s.canvas.style.width=size*Number($('scale').value)+'px';s.canvas.style.height=size*Number($('scale').value)+'px';const stage=s.canvas.parentElement;stage.scrollLeft=Math.max(0,(size*Number($('scale').value)-stage.clientWidth)/2);stage.scrollTop=Math.max(0,(size*Number($('scale').value)-stage.clientHeight)/2);}}
function arenaResize(){const v=$('arena-scale').value;arena.style.width=v==='fit'?'100%':1280*Number(v)+'px';arena.style.height=v==='fit'?'auto':720*Number(v)+'px';}
function render(){if(!ready)return;for(const s of specs){const t=now%s.cycle;scene(s,s.ctx,t);s.phaseLabel.textContent=phase(s,t)+' · '+Math.floor(t)+' ms';}const s=selected(),t=now%s.cycle;drawArena(s,t);$('time').max=s.cycle-1;$('time').value=t;$('clock').textContent=Math.floor(t)+' ms';}
$('play').onclick=()=>{running=!running;$('play').textContent=running?'Pause':'Play';stopSounds();if(running)startActiveSounds(selected(),now%selected().cycle);};$('restart').onclick=()=>{now=0;stopSounds();if(running)startActiveSounds(selected(),0);render();};$('time').oninput=()=>{running=false;$('play').textContent='Play';stopSounds();now=Number($('time').value);render();};$('scale').onchange=()=>{resize();render();};$('mode').onchange=()=>{resize();render();};$('direction').onchange=()=>{stopSounds();render();};$('ability').onchange=()=>{now=0;stopSounds();if(running)startActiveSounds(selected(),0);render();};$('arena-scale').onchange=arenaResize;$('speed').onchange=stopSounds;
$('sound').onclick=async()=>{soundEnabled=!soundEnabled;$('sound').textContent=soundEnabled?'Mute sound':'Enable sound';stopSounds();if(soundEnabled){contextAudio??=new AudioContext();await contextAudio.resume();now=0;if(running)startActiveSounds(selected(),0);}};
$('volume').oninput=()=>{for(const a of activeAudio)a.volume=Number($('volume').value);};
arena.onclick=e=>{const r=arena.getBoundingClientRect(),x=(e.clientX-r.left)*1280/r.width,y=(e.clientY-r.top)*720/r.height;if(y>=651&&y<=696){const i=Math.floor((x-705)/140);if(i>=0&&i<4&&x-705-i*140<128){$('ability').value=specs[i].id;now=0;stopSounds();if(running)startActiveSounds(selected(),0);render();}}};
window.addEventListener('pagehide',stopSounds);document.addEventListener('visibilitychange',()=>{if(document.hidden){stopSounds();running=false;$('play').textContent='Play';}});
Promise.all(Object.values(sprites).map(s=>new Promise((ok,fail)=>{s.img=new Image();s.img.onload=ok;s.img.onerror=fail;s.img.src=s.image;}))).then(()=>{ready=true;ctx.imageSmoothingEnabled=false;resize();arenaResize();function tick(ts){try{const s=selected(),before=now%s.cycle;if(running){now+=(ts-last)*Number($('speed').value);scheduleSounds(s,before,now%s.cycle);}last=ts;render();requestAnimationFrame(tick);}catch(e){stopSounds();$('load-error').textContent='Preview error: '+e.message;}}requestAnimationFrame(tick);}).catch(e=>{$('load-error').textContent='Preview failed: '+e.message;});
