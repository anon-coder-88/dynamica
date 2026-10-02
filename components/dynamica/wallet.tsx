/* eslint-disable react-hooks/set-state-in-effect -- Synchronize external wallet announcements and account/network events. */
'use client';
import { createContext, useContext, useEffect, useState, useCallback, type ReactNode } from 'react';
import { createPublicClient, createWalletClient, custom, defineChain, http, formatEther, type EIP1193Provider, type Address } from 'viem';
export const testnet=defineChain({id:46630,name:'Robinhood Testnet',nativeCurrency:{name:'Ether',symbol:'ETH',decimals:18},rpcUrls:{default:{http:['https://rpc.testnet.chain.robinhood.com']}},blockExplorers:{default:{name:'Blockscout',url:'https://explorer.testnet.chain.robinhood.com'}},testnet:true});
export const publicClient=createPublicClient({chain:testnet,transport:http(undefined,{timeout:12000,retryCount:1})});
type Injected=EIP1193Provider & {on?:(name:string,fn:(value:unknown)=>void)=>void;removeListener?:(name:string,fn:(value:unknown)=>void)=>void;isMetaMask?:boolean;isCoinbaseWallet?:boolean;isRabby?:boolean;isPhantom?:boolean;isTrust?:boolean;isOkxWallet?:boolean;providers?:Injected[]};
export function openWalletDialog(){window.dispatchEvent(new Event('dynamica:open-wallet'));}
export type WalletOption={id:string;name:string;icon:string|null;rdns:string|null;provider:Injected};
type W={address:Address|null;chainId:number|null;balance:string|null;balanceTime:string|null;error:string;busy:boolean;wallets:WalletOption[];walletName:string|null;connect:(id:string)=>Promise<boolean>;disconnect:()=>void;switchNetwork:()=>Promise<void>;refresh:()=>Promise<void>;rescan:()=>void;provider:Injected|null};
const Context=createContext<W|null>(null);
function legacyName(p:Injected){return p.isRabby?'Rabby Wallet':p.isCoinbaseWallet?'Coinbase Wallet':p.isPhantom?'Phantom':p.isTrust?'Trust Wallet':p.isOkxWallet?'OKX Wallet':p.isMetaMask?'MetaMask':'Browser wallet';}
export function WalletProvider({children}:{children:ReactNode}){
 const [wallets,setWallets]=useState<WalletOption[]>([]),[provider,setProvider]=useState<Injected|null>(null),[walletName,setWalletName]=useState<string|null>(null),[address,setAddress]=useState<Address|null>(null),[chainId,setChain]=useState<number|null>(null),[balance,setBalance]=useState<string|null>(null),[balanceTime,setBalanceTime]=useState<string|null>(null),[error,setError]=useState(''),[busy,setBusy]=useState(false);
 const rescan=useCallback(()=>{
  window.dispatchEvent(new Event('eip6963:requestProvider'));
  const legacy=(window as unknown as {ethereum?:Injected}).ethereum;
  if(legacy){const candidates=legacy.providers?.length?legacy.providers:[legacy];setWallets(prev=>{const next=[...prev];candidates.forEach((item,index)=>{if(!next.some(w=>w.provider===item))next.push({id:'legacy-'+index,name:legacyName(item),icon:null,rdns:null,provider:item});});return next.length===prev.length?prev:next;});}
 },[]);
 useEffect(()=>{
  const announce=(event:Event)=>{const detail=(event as CustomEvent<{info?:{uuid?:string;name?:string;icon?:string;rdns?:string};provider?:Injected}>).detail;
   if(!detail?.provider?.request||!detail.info?.uuid||!detail.info?.name)return;
   const {info,provider:found}=detail;
   // A wallet supplies its own icon. Only bounded image data URLs are used as inline art.
   const icon=typeof info.icon==='string'&&info.icon.length<24000&&/^data:image\/(png|jpeg|webp|svg\+xml);/i.test(info.icon)?info.icon:null;
   const option:WalletOption={id:info.uuid!.slice(0,120),name:info.name!.slice(0,80),icon,rdns:info.rdns?.slice(0,120)||null,provider:found};
   setWallets(prev=>prev.some(w=>w.id===option.id||w.provider===found)?prev:[...prev,option]);
  };
  window.addEventListener('eip6963:announceProvider',announce);
  rescan();
  return()=>window.removeEventListener('eip6963:announceProvider',announce);
 },[rescan]);
 // Announced providers take precedence over a duplicate legacy window.ethereum entry.
 const choices=wallets.filter(w=>!w.id.startsWith('legacy-')||!wallets.some(other=>!other.id.startsWith('legacy-')&&other.provider===w.provider));
 useEffect(()=>{if(!provider)return;const accounts=(v:unknown)=>{setAddress((v as Address[])[0]||null);setBalance(null);};const chain=(v:unknown)=>{setChain(Number(v));setBalance(null);};provider.on?.('accountsChanged',accounts);provider.on?.('chainChanged',chain);return()=>{provider.removeListener?.('accountsChanged',accounts);provider.removeListener?.('chainChanged',chain);};},[provider]);
 const refresh=useCallback(async()=>{if(!provider||!address||chainId!==testnet.id){setBalance(null);return;}try{const b=await publicClient.getBalance({address});setBalance(formatEther(b));setBalanceTime(new Date().toISOString());setError('');}catch{setBalance(null);setBalanceTime(null);setError('Balance unavailable. The testnet RPC did not respond.');}},[provider,address,chainId]);
 useEffect(()=>{refresh();},[refresh]);
 const connect=async(id:string)=>{const choice=choices.find(w=>w.id===id);if(!choice||busy)return false;setError('');setBusy(true);try{const accounts=await choice.provider.request({method:'eth_requestAccounts'}) as Address[];if(!accounts?.[0])throw Error('No account was selected.');const chain=await choice.provider.request({method:'eth_chainId'}) as string;setProvider(choice.provider);setWalletName(choice.name);setAddress(accounts[0]);setChain(Number(chain));return true;}catch{setError('Wallet connection was declined or could not complete.');return false;}finally{setBusy(false);}};
 const disconnect=()=>{setProvider(null);setWalletName(null);setAddress(null);setBalance(null);setBalanceTime(null);setChain(null);setError('');};
 const switchNetwork=async()=>{if(!provider)return;setBusy(true);setError('');try{await provider.request({method:'wallet_switchEthereumChain',params:[{chainId:'0xb626'}]});setChain(testnet.id);}catch(e){if((e as {code?:number}).code===4902){try{await provider.request({method:'wallet_addEthereumChain',params:[{chainId:'0xb626',chainName:testnet.name,nativeCurrency:testnet.nativeCurrency,rpcUrls:testnet.rpcUrls.default.http,blockExplorerUrls:[testnet.blockExplorers.default.url]}]});setChain(Number(await provider.request({method:'eth_chainId'})));}catch{setError('Network request was declined.');}}else setError('Could not switch network. Try selecting Robinhood Testnet in your wallet.');}finally{setBusy(false);}};
 return <Context.Provider value={{address,chainId,balance,balanceTime,error,busy,wallets:choices,walletName,connect,disconnect,switchNetwork,refresh,rescan,provider}}>{children}</Context.Provider>;
}
export function useWallet(){const w=useContext(Context);if(!w)throw Error('Wallet provider missing');return w;}
export function walletClient(provider:EIP1193Provider,address:Address){return createWalletClient({account:address,chain:testnet,transport:custom(provider)});}

// User-selected token reads are public calls; this component never requests allowances.
export function TokenBalance(){const w=useWallet();const [token,setToken]=useState(''),[value,setValue]=useState(''),[error,setError]=useState(''),[busy,setBusy]=useState(false);useEffect(()=>{setValue('');setError('');},[w.address,w.chainId,token]);const read=async()=>{setBusy(true);setError('');setValue('');const account=w.address;try{if(!account||w.chainId!==46630)throw Error('Connect on Robinhood Testnet to read a token balance.');const {isAddress,erc20Abi,formatUnits}=await import('viem');if(!isAddress(token))throw Error('Enter a valid ERC-20 contract address.');const [balance,decimals,symbol]=await Promise.all([publicClient.readContract({address:token as Address,abi:erc20Abi,functionName:'balanceOf',args:[account]}),publicClient.readContract({address:token as Address,abi:erc20Abi,functionName:'decimals'}),publicClient.readContract({address:token as Address,abi:erc20Abi,functionName:'symbol'})]);setValue(`${formatUnits(balance,decimals)} ${symbol} · read ${new Date().toLocaleTimeString()}`);}catch(e){const m=(e as Error).message;setError(m.length<150?m:'Token metadata or balance is unavailable. Check the contract and network.');}finally{setBusy(false);}};return <div className="custom-token"><label htmlFor="wallet-token">Read an ERC-20 balance</label><input disabled={busy} id="wallet-token" value={token} onChange={e=>setToken(e.target.value)} placeholder="Testnet contract address · 0x…" className="token-address-input"/><button className="token-read-btn" disabled={busy} onClick={read}>{busy?'Reading token…':'Read token balance'}</button>{value&&<p role="status" className="small break-word">{value}</p>}{error&&<p role="alert" className="error">{error}</p>}</div>}
