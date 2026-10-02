import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=path.resolve('dist/client');
const routes=['index','app','ecosystem','token','docs','risks'];
let checked=0;
for(const route of routes){const file=path.join(root,route+'.html');assert.ok(fs.existsSync(file),`Missing route ${route}`);const html=fs.readFileSync(file,'utf8');assert.match(html,/<title>Dynamica/);assert.match(html,/<h1[ >]/);assert.match(html,/id="main"/);assert.ok(!html.includes('Starter Project'));for(const match of html.matchAll(/(?:href|src)="(\/(?!\/)[^"#?]*)[^" ]*"/g)){const url=match[1];if(!url||url==='/')continue;const base=path.join(root,url);assert.ok([base,base+'.html',path.join(base,'index.html')].some(f=>fs.existsSync(f)),`Missing local asset/route: ${url} in ${route}`);checked++;}}
console.log(`Static smoke passed: ${routes.length} routes, ${checked} local route/asset references.`);
