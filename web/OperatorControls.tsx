import {useCallback,useEffect,useRef,useState} from 'react';
import {getAddress,isAddress,parseUnits,formatUnits,type Address} from 'viem';
import {useWallet,publicClient,testnet,walletClient} from '../components/dynamica/wallet';
import {DynamicaStrategyVaultAbi as abi} from '../packages/abi/src/contracts';
const raw=process.env.NEXT_PUBLIC_DYNAMICA_VAULT_ADDRESS||'';
const vault=isAddress(raw)?getAddress(raw):null;
const reasons=['Ready','Execution paused','No operator configured','Policy expired','Cooldown active','Window budget exhausted','At reserve target'];
type State={owner:Address;operator:Address;version:bigint;sequence:bigint;observedAt:bigint;target:number;idle:bigint;remaining:bigint;reserve:Address;preview:readonly[boolean,bigint,number];paused:boolean};
type Action='configure'|'rebalance'|'revoke'|'pause';
export function OperatorControls(){
 const w=useWallet(),[data,setData]=useState<State|null>(null),[operator,setOperator]=useState(''),[target,setTarget]=useState('50'),[limit,setLimit]=useState('10'),[budget,setBudget]=useState('100'),[error,setError]=useState(''),[status,setStatus]=useState(''),[hash,setHash]=useState(''),[review,setReview]=useState<Action|null>(null),[busy,setBusy]=useState(false);
 const lock=useRef(false);
 const refresh=useCallback(async()=>{if(!vault||w.chainId!==testnet.id){setData(null);return;}try{
  const [owner,policy,version,idle,remaining,reserve,preview,paused,sequence,block]=await Promise.all([
   publicClient.readContract({address:vault,abi,functionName:'owner'}),publicClient.readContract({address:vault,abi,functionName:'policy'}),
   publicClient.readContract({address:vault,abi,functionName:'policyVersion'}),publicClient.readContract({address:vault,abi,functionName:'idleAssets'}),
   publicClient.readContract({address:vault,abi,functionName:'windowRemaining'}),publicClient.readContract({address:vault,abi,functionName:'reserve'}),
   publicClient.readContract({address:vault,abi,functionName:'previewRebalance'}),publicClient.readContract({address:vault,abi,functionName:'executionPaused'}),
   publicClient.readContract({address:vault,abi,functionName:'executionCount'}),publicClient.getBlock()]);
  setData({owner,operator:policy[0],version,sequence,observedAt:block.timestamp,target:policy[1],idle,remaining,reserve,preview,paused});setError('');
 }catch{setData(null);setError('Operator policy could not be read. Check the configured strategy vault and refresh.');}},[w.chainId]);
 useEffect(()=>{void refresh();},[refresh]);
 useEffect(()=>{setReview(null);setData(null);setHash('');setStatus('');void refresh();},[w.address,w.chainId,refresh]);
 const isOwner=!!w.address&&data?.owner.toLowerCase()===w.address.toLowerCase();
 const isOperator=!!w.address&&data?.operator.toLowerCase()===w.address.toLowerCase();
 const validate=()=>{
  if(!isAddress(operator)||/^0x0{40}$/i.test(operator))throw Error('Enter a nonzero operator address.');
  if(!/^\d+(\.\d{1,2})?$/.test(target)||Number(target)>80)throw Error('Reserve target must be between 0 and 80%, with at most two decimals.');
  for(const value of [limit,budget])if(!/^\d+(\.\d{1,18})?$/.test(value))throw Error('Enter positive dTEST limits with at most 18 decimals.');
  const maxMove=parseUnits(limit,18),windowLimit=parseUnits(budget,18);
  if(maxMove<=0n||windowLimit<maxMove)throw Error('Window budget must cover a positive per-call limit.');
  return {operator:getAddress(operator),reserveBps:Math.round(Number(target)*100),maxMove,windowLimit};
 };
 const prepare=(action:Action)=>{try{if(action==='configure')validate();setError('');setReview(action);}catch(e){setError((e as Error).message);}};
 const submit=async()=>{
  if(!review||!data||!vault||!w.address||!w.provider||lock.current)return;
  const account=w.address,chain=w.chainId,action=review;
  lock.current=true;setBusy(true);setError('');setHash('');
  try{
   if(chain!==testnet.id)throw Error('Switch to Robinhood Testnet.');
   const actualAccounts=await w.provider.request({method:'eth_accounts'}) as string[];
   const actualChain=Number(await w.provider.request({method:'eth_chainId'}));
   if(actualAccounts[0]?.toLowerCase()!==account.toLowerCase()||actualChain!==chain)throw Error('Wallet account or network changed. Review again.');
   const client=walletClient(w.provider,account);
   setStatus('Awaiting wallet signature…');
   let tx:`0x${string}`;
   if(action==='configure'){
    const p=validate();const block=await publicClient.getBlock();
    tx=await client.writeContract({address:vault,abi,functionName:'configurePolicy',args:[{...p,minInterval:60n,windowDuration:3600n,expiresAt:block.timestamp+604800n}]});
   }else if(action==='rebalance'){
    tx=await client.writeContract({address:vault,abi,functionName:'rebalanceWithBounds',args:[data.version,data.sequence,data.preview[1],data.preview[1],data.observedAt+120n]});
   }else if(action==='revoke')tx=await client.writeContract({address:vault,abi,functionName:'revokeOperator'});
   else tx=await client.writeContract({address:vault,abi,functionName:'setExecutionPaused',args:[!data.paused]});
   setHash(tx);setStatus('Submitted; waiting for confirmation…');
   const receipt=await publicClient.waitForTransactionReceipt({hash:tx,timeout:120000});
   if(receipt.status!=='success')throw Error('Transaction reverted.');
   setStatus('Confirmed on Robinhood Testnet.');setReview(null);await refresh();
  }catch(e){setError((e as Error).message.slice(0,220));setStatus(hash?'Check the transaction before retrying.':'No action confirmed.');setReview(null);}
  finally{lock.current=false;setBusy(false);}
 };
 return <section className="operator"><span className="eyebrow">PROGRAMMABLE PERMISSIONS</span><h2>Reserve operator</h2><p>Move custody toward a configured target. The operator cannot select another destination or receive assets. Withdrawals bypass execution limits.</p>
 {!data?<><p>Connect on testnet to read a configured vault.</p><button onClick={()=>void refresh()}>Refresh policy</button></>:<>
 <div className="vault-facts"><div><span>Idle dTEST</span><strong>{formatUnits(data.idle,18)}</strong></div><div><span>Window budget remaining</span><strong>{formatUnits(data.remaining,18)}</strong></div><div><span>Execution status</span><strong>{reasons[data.preview[2]]||'Unknown'}</strong></div></div>
 <p className="vault-subnote break-word">Policy #{String(data.version)} · target {data.target/100}% · operator {data.operator}<br/>Fixed reserve: {data.reserve}</p>
 {isOwner&&<><div className="operator-form"><label>Operator wallet<input value={operator} onChange={e=>{setOperator(e.target.value);setReview(null);}} disabled={busy}/></label><label>Reserve target (%)<input value={target} onChange={e=>{setTarget(e.target.value);setReview(null);}} disabled={busy}/></label><label>Per-call dTEST limit<input value={limit} onChange={e=>{setLimit(e.target.value);setReview(null);}} disabled={busy}/></label><label>Hourly dTEST budget<input value={budget} onChange={e=>{setBudget(e.target.value);setReview(null);}} disabled={busy}/></label></div><div className="operator-actions"><button disabled={busy} onClick={()=>prepare('configure')}>Review policy</button><button disabled={busy} onClick={()=>prepare('revoke')}>Review revocation</button><button disabled={busy} onClick={()=>prepare('pause')}>Review {data.paused?'resume':'pause'}</button></div></>}
 <div className="operator-actions">{isOperator&&<button disabled={busy||data.preview[2]!==0} onClick={()=>prepare('rebalance')}>Review rebalance</button>}<button disabled={busy} onClick={()=>void refresh()}>Refresh policy</button></div>
 {review&&<div className="vault-review"><h3>Review {review}</h3><p>{review==='configure'?`Operator ${operator}; target ${target}%; per-call ${limit} dTEST; hourly budget ${budget} dTEST. 60-second cooldown; expires in 7 days. The owner can replace or revoke this policy immediately. Replacing it resets the budget.`:review==='rebalance'?`${formatUnits(data.preview[1],18)} dTEST ${data.preview[0]?'to reserve':'to idle vault custody'} under policy #${data.version}. Any smaller movement or changed policy version will revert.`:review==='pause'?`Execution will be ${data.paused?'resumed':'paused'}.`:'The current operator will lose its execution permission immediately.'}</p><p>Robinhood Testnet (46630) · ETH gas shown by wallet.<br/>Contract: <code className="break-word">{vault}</code></p><button disabled={busy} onClick={()=>void submit()}>Confirm in wallet</button><button disabled={busy} onClick={()=>setReview(null)}>Cancel</button></div>}
 </>}{status&&<p role="status">{status}</p>}{hash&&<a href={`${testnet.blockExplorers.default.url}/tx/${hash}`} target="_blank" rel="noreferrer">View transaction</a>}{error&&<p role="alert" className="error">{error}</p>}
 <p className="vault-subnote">The policy persists onchain. Rebalancing requires an operator to submit transactions; no background execution service is included.</p></section>;
}
