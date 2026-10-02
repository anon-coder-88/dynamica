'use client';
import { useCallback, useEffect, useRef, useState } from 'react';
import { formatUnits, getAddress, isAddress, parseAbi, parseUnits, type Address } from 'viem';
import { publicClient, testnet, useWallet, walletClient, openWalletDialog } from './wallet';

const vaultAbi = parseAbi([
  'function asset() view returns (address)', 'function totalAssets() view returns (uint256)',
  'function assetCap() view returns (uint256)', 'function depositsPaused() view returns (bool)',
  'function balanceOf(address) view returns (uint256)', 'function maxDeposit(address) view returns (uint256)',
  'function maxWithdraw(address) view returns (uint256)',
  'function previewDeposit(uint256) view returns (uint256)', 'function previewWithdraw(uint256) view returns (uint256)',
  'function deposit(uint256,address) returns (uint256)', 'function withdraw(uint256,address,address) returns (uint256)',
]);
const assetAbi = parseAbi([
  'function decimals() view returns (uint8)', 'function symbol() view returns (string)',
  'function balanceOf(address) view returns (uint256)', 'function allowance(address,address) view returns (uint256)',
  'function claimed(address) view returns (bool)', 'function claim()',
  'function approve(address,uint256) returns (bool)',
]);
const rawVault = process.env.NEXT_PUBLIC_DYNAMICA_VAULT_ADDRESS || '';
const rawAsset = process.env.NEXT_PUBLIC_DYNAMICA_ASSET_ADDRESS || '';
type Snapshot = { wallet:bigint; shares:bigint; withdrawable:bigint; capacity:bigint; allowance:bigint; total:bigint; paused:boolean; claimed:boolean; decimals:number; symbol:string; at:Date };
type Action = 'claim'|'approve'|'deposit'|'withdraw';

export function LiveVault(){
 const w=useWallet(),[data,setData]=useState<Snapshot|null>(null),[amount,setAmount]=useState(''),[error,setError]=useState(''),[status,setStatus]=useState(''),[hash,setHash]=useState<`0x${string}`|null>(null),[busy,setBusy]=useState(false),[review,setReview]=useState<{action:Action; amount:bigint; account:Address; chainId:number}|null>(null);
 const lock=useRef(false);
 const configured=isAddress(rawVault)&&isAddress(rawAsset);
 const vault=configured?getAddress(rawVault):null, asset=configured?getAddress(rawAsset):null;
 const ready=!!(vault&&asset&&w.address&&w.chainId===testnet.id);
 const refresh=useCallback(async()=>{
  if(!ready||!vault||!asset||!w.address){setData(null);return;}
  try{
   const code=await publicClient.getBytecode({address:vault});
   if(!code||code==='0x')throw Error('Vault contract not found at this address.');
   const [actualAsset,wallet,shares,withdrawable,capacity,allowance,total,paused,claimed,decimals,symbol]=await Promise.all([
    publicClient.readContract({address:vault,abi:vaultAbi,functionName:'asset'}),
    publicClient.readContract({address:asset,abi:assetAbi,functionName:'balanceOf',args:[w.address]}),
    publicClient.readContract({address:vault,abi:vaultAbi,functionName:'balanceOf',args:[w.address]}),
    publicClient.readContract({address:vault,abi:vaultAbi,functionName:'maxWithdraw',args:[w.address]}),
    publicClient.readContract({address:vault,abi:vaultAbi,functionName:'maxDeposit',args:[w.address]}),
    publicClient.readContract({address:asset,abi:assetAbi,functionName:'allowance',args:[w.address,vault]}),
    publicClient.readContract({address:vault,abi:vaultAbi,functionName:'totalAssets'}),
    publicClient.readContract({address:vault,abi:vaultAbi,functionName:'depositsPaused'}),
    publicClient.readContract({address:asset,abi:assetAbi,functionName:'claimed',args:[w.address]}),
    publicClient.readContract({address:asset,abi:assetAbi,functionName:'decimals'}),
    publicClient.readContract({address:asset,abi:assetAbi,functionName:'symbol'}),
   ]);
   if(actualAsset.toLowerCase()!==asset.toLowerCase())throw Error('Configured asset does not match the vault.');
   setData({wallet,shares,withdrawable,capacity,allowance,total,paused,claimed,decimals,symbol,at:new Date()});setError('');
  }catch(e){setData(null);setError((e as Error).message.slice(0,180));}
 },[ready,vault,asset,w.address]);
 useEffect(()=>{void refresh();},[refresh]);
 useEffect(()=>{setReview(null);setAmount('');setHash(null);setStatus('');setError('');},[w.address,w.chainId]);
 const prepare=(requested:Action)=>{
  if(!ready||!w.address||!data||!vault){setError('Connect on Robinhood Testnet and refresh the vault first.');return;}
  try{
   const value=requested==='claim'?0n:parseUnits(amount.trim(),data.decimals);
   if(requested!=='claim'&&value<=0n)throw Error('Enter a positive amount.');
   if(requested==='claim'&&data.claimed)throw Error('This wallet has already claimed its test asset.');
   if(requested==='deposit'&&(data.paused||value>data.capacity||value>data.wallet))throw Error('Amount exceeds your balance or the available vault capacity.');
   if(requested==='approve'&&(value>data.wallet||value<=data.allowance))throw Error('Approval is unnecessary or exceeds your balance.');
   if(requested==='withdraw'&&value>data.withdrawable)throw Error('Amount exceeds your withdrawable vault assets.');
   setError('');setReview({action:requested,amount:value,account:w.address,chainId:w.chainId!});
  }catch(e){setReview(null);setError((e as Error).message.includes('fractional')?'Too many decimal places for this asset.':(e as Error).message);}
 };
 const submit=async()=>{
  if(!review||lock.current||!w.provider||!w.address||!vault||!asset||!data)return;
  if(review.account!==w.address||review.chainId!==w.chainId||w.chainId!==testnet.id){setReview(null);setError('Account or network changed. Review again.');return;}
  lock.current=true;setBusy(true);setError('');setHash(null);
  const action=review.action;
  try{
   setStatus('Awaiting wallet signature…');
   const client=walletClient(w.provider,w.address);
   let tx:`0x${string}`;
   if(action==='claim')tx=await client.writeContract({address:asset,abi:assetAbi,functionName:'claim'});
   else if(action==='approve')tx=await client.writeContract({address:asset,abi:assetAbi,functionName:'approve',args:[vault,review.amount]});
   else if(action==='deposit'){
    const [capacity,balance,allowance]=await Promise.all([
     publicClient.readContract({address:vault,abi:vaultAbi,functionName:'maxDeposit',args:[w.address]}),
     publicClient.readContract({address:asset,abi:assetAbi,functionName:'balanceOf',args:[w.address]}),
     publicClient.readContract({address:asset,abi:assetAbi,functionName:'allowance',args:[w.address,vault]})]);
    if(review.amount>capacity||review.amount>balance||review.amount>allowance)throw Error('Balance, allowance, or capacity changed. Refresh and review again.');
    tx=await client.writeContract({address:vault,abi:vaultAbi,functionName:'deposit',args:[review.amount,w.address]});
   } else {
    const available=await publicClient.readContract({address:vault,abi:vaultAbi,functionName:'maxWithdraw',args:[w.address]});
    if(review.amount>available)throw Error('Withdrawable amount changed. Refresh and review again.');
    tx=await client.writeContract({address:vault,abi:vaultAbi,functionName:'withdraw',args:[review.amount,w.address,w.address]});
   }
   setHash(tx);setStatus('Submitted; waiting for confirmation…');
   const receipt=await publicClient.waitForTransactionReceipt({hash:tx,confirmations:1,timeout:120000});
   if(receipt.status!=='success')throw Error('Transaction reverted.');
   setStatus(`${action[0].toUpperCase()+action.slice(1)} confirmed on Robinhood Testnet.`);
   setReview(null);setAmount('');await refresh();
  }catch(e){const message=(e as Error).message;setError(/rejected|denied|cancelled/i.test(message)?'Wallet signature was rejected. No action was confirmed.':message.length<180?message:'Transaction failed or its status is unknown. Check the explorer before retrying.');setStatus('');setReview(null);}
  finally{lock.current=false;setBusy(false);}
 };
 const fmt=(n:bigint)=>data?Number(formatUnits(n,data.decimals)).toLocaleString(undefined,{maximumFractionDigits:6}):'—';
 let parsed:bigint|null=null;
 try{if(data&&amount.trim())parsed=parseUnits(amount.trim(),data.decimals);}catch{}
 const approvalNeeded=parsed!==null&&parsed>data!.allowance;
 return <section className="live-vault" aria-labelledby="live-vault-title"><div className="live-vault-head"><div><span className="eyebrow">LIVE CONTRACT UTILITY · TESTNET</span><h2 id="live-vault-title">Dynamica test vault</h2><p>Claim a valueless test asset, deposit it for vault shares, and withdraw it. Assets remain in this vault; no strategy or yield is active.</p></div><span className="pill live">Robinhood Testnet</span></div>
 {!configured?<p className="vault-message">Deployment addresses are not configured. Deploy the contracts, then set the two NEXT_PUBLIC_DYNAMICA addresses in your local environment and restart the site.</p>:<>
 <div className="vault-facts"><div><span>Vault</span><code title={vault||''}>{vault?.slice(0,8)}…{vault?.slice(-6)}</code></div><div><span>Asset</span><code title={asset||''}>{asset?.slice(0,8)}…{asset?.slice(-6)}</code></div><div><span>Network</span><strong>46630 · ETH gas</strong></div></div>
 {!w.address?<button className="vault-primary" onClick={openWalletDialog}>Connect Wallet</button>:w.chainId!==testnet.id?<button className="vault-primary" disabled={w.busy} onClick={()=>void w.switchNetwork()}>Switch to Robinhood Testnet</button>:!data?<button className="vault-primary" onClick={()=>void refresh()}>Retry vault read</button>:<>
 <div className="vault-facts vault-balances"><div><span>Your {data.symbol}</span><strong>{fmt(data.wallet)}</strong></div><div><span>Your vault shares</span><strong>{Number(formatUnits(data.shares,18)).toLocaleString(undefined,{maximumFractionDigits:6})}</strong></div><div><span>Withdrawable {data.symbol}</span><strong>{fmt(data.withdrawable)}</strong></div><div><span>Remaining capacity</span><strong>{fmt(data.capacity)}</strong></div></div>
 <p className="vault-subnote">Onchain read: {data.at.toLocaleString()} · Total assets: {fmt(data.total)} {data.symbol} · Deposits {data.paused?'paused':'open'}. Withdrawals stay available.</p>
 <div className="vault-controls"><button onClick={()=>prepare('claim')} disabled={busy||data.claimed}>{data.claimed?'Test asset claimed':'Claim 100 dTEST'}</button><label htmlFor="live-vault-amount">Amount in {data.symbol}<input id="live-vault-amount" value={amount} inputMode="decimal" placeholder="0.0" onChange={e=>{setAmount(e.target.value);setReview(null);}} disabled={busy}/></label><button onClick={()=>prepare(approvalNeeded?'approve':'deposit')} disabled={busy||!parsed||data.paused}>{approvalNeeded?'Review approval':'Review deposit'}</button><button onClick={()=>prepare('withdraw')} disabled={busy||!parsed}>Review withdrawal</button><button onClick={()=>void refresh()} disabled={busy}>Refresh</button></div>
 </>}
 {review&&<div className="vault-review" role="group" aria-label="Review testnet transaction"><h3>Review {review.action}</h3><p>{review.action==='claim'?'Receive 100 valueless test tokens.':`${fmt(review.amount)} ${data?.symbol} · ${review.action==='approve'?'Authorize this vault to spend exactly this amount.':review.action==='deposit'?'Exchange asset tokens for ERC-4626 shares.':'Burn vault shares for asset tokens.'}`}</p><dl><div><dt>Network</dt><dd>Robinhood Testnet (46630)</dd></div><div><dt>Contract</dt><dd className="break-word">{review.action==='claim'||review.action==='approve'?asset:vault}</dd></div><div><dt>Authority</dt><dd>Your wallet signature</dd></div><div><dt>Network fee</dt><dd>ETH gas, estimated by wallet</dd></div></dl><button className="vault-primary" onClick={()=>void submit()} disabled={busy}>{busy?'Waiting…':'Confirm in wallet'}</button><button onClick={()=>setReview(null)} disabled={busy}>Cancel</button></div>}
 {status&&<p role="status" className="vault-message">{status}</p>}{hash&&<a className="vault-tx" target="_blank" rel="noopener noreferrer" href={`${testnet.blockExplorers.default.url}/tx/${hash}`}>View transaction on explorer</a>}
 {error&&<p role="alert" className="error vault-message">{error}</p>}
 <p className="vault-subnote">This is a testnet MVP. A deposit may require a separate approval transaction. Do not send valuable assets to this unaudited contract.</p>
 </>}</section>;
}
