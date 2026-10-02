// Count tracked/source bytes using GitHub's byte-based language statistic convention.
// This MVP contains no language overrides or vendored Solidity.
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {readFileSync,existsSync} from 'node:fs';
const extensions={sol:'Solidity',ts:'TypeScript',tsx:'TypeScript',js:'JavaScript',mjs:'JavaScript',css:'CSS',html:'HTML',py:'Python'};
const {stdout}=await promisify(execFile)('git',['ls-files','--cached','--others','--exclude-standard','-z']);
const paths=stdout.split('\0').filter(Boolean);
const languages={},counts={};
for(const path of new Set(paths)){
 if(!existsSync(path)||path.startsWith('docs/'))continue;
 const language=extensions[path.split('.').pop()];if(!language)continue;
 const bytes=readFileSync(path).length;languages[language]=(languages[language]||0)+bytes;counts[language]=(counts[language]||0)+1;
}
const total=Object.values(languages).reduce((sum,value)=>sum+value,0);
const percentage=100*(languages.Solidity||0)/total;
console.log(JSON.stringify({method:'Tracked source bytes; generated artifacts, lockfiles, data, binaries and documentation excluded',languages,files:counts,total,solidityPercentage:Number(percentage.toFixed(2))},null,2));
if(percentage<50){console.error('Solidity source share must be at least 50%.');process.exitCode=1;}
