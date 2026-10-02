import {readFileSync,writeFileSync} from 'node:fs';
const artifact=JSON.parse(readFileSync('chain/artifacts/contracts/DynamicaStrategyVault.sol/DynamicaStrategyVault.json','utf8'));
const names=['asset','decimals','totalAssets','totalSupply','assetCap','depositsPaused','balanceOf','maxWithdraw','idleAssets','policyVersion','windowRemaining','executionPaused','reserve','previewRebalance'];
writeFileSync('python/vault_read_abi.json',JSON.stringify(artifact.abi.filter(item=>names.includes(item.name)),null,2)+'\n');
