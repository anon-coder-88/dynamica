// Use actual GitHub Linguist, not an extension-only approximation.
import {execFileSync} from 'node:child_process';
const data=JSON.parse(execFileSync('bundle',['exec','github-linguist','--json'],{encoding:'utf8'}));
const languages=Object.fromEntries(Object.entries(data).map(([name,stats])=>[name,stats.size]));
const total=Object.values(languages).reduce((a,b)=>a+b,0);
const solidity=languages.Solidity||0;
console.log(JSON.stringify({tool:'GitHub Linguist 9.3.0',revision:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),languages,total,solidityPercentage:100*solidity/total},null,2));
if(total===0||solidity/total<0.5)throw new Error('Eligible Solidity share is below 50%');
