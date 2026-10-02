'use client';
import {useEffect,useState} from 'react';
import {Wallet,ExternalLink,RefreshCw} from 'lucide-react';
import {Button} from '@/components/ui/button';
import {Dialog,DialogContent,DialogTitle,DialogDescription} from '@/components/ui/dialog';
import {useWallet,TokenBalance} from './wallet';

const suggested=[
 {name:'MetaMask',url:'https://metamask.io/download/',match:/metamask/i,icon:'/wallets/metamask.ico',mark:'M',tone:'metamask'},
 {name:'Coinbase Wallet',url:'https://www.coinbase.com/wallet/downloads',match:/coinbase/i,icon:'/wallets/coinbase.svg',mark:'C',tone:'coinbase'},
 {name:'Rabby Wallet',url:'https://rabby.io/',match:/rabby/i,icon:'/wallets/rabby.png',mark:'R',tone:'rabby'},
 {name:'Phantom',url:'https://phantom.com/download',match:/phantom/i,icon:'/wallets/phantom.png',mark:'P',tone:'phantom'},
 {name:'Trust Wallet',url:'https://trustwallet.com/download',match:/trust( wallet)?/i,icon:'/wallets/trustwallet.png',mark:'T',tone:'trust'},
 {name:'OKX Wallet',url:'https://web3.okx.com/download',match:/okx/i,icon:'/wallets/okx.png',mark:'O',tone:'okx'},
];
function WalletMark({name,icon}:{name:string;icon?:string|null}){
 const brand=suggested.find(item=>item.match.test(name));
 // Announced EIP-6963 art belongs to the selected provider; known options also
 // have an explicit brand asset when a legacy provider does not announce one.
 const src=icon||brand?.icon;
 return <span className={'wallet-logo '+(brand?'wallet-logo-'+brand.tone:'')} aria-hidden="true"><span className="wallet-logo-fallback">{brand?.mark||<Wallet size={20}/>}</span>{src&&<img src={src} alt="" loading="lazy" onError={event=>{event.currentTarget.style.display='none';}}/>}</span>;
}
export function WalletConnect({detailed=false}:{detailed?:boolean}){
 const w=useWallet(),[open,setOpen]=useState(false);
 const available=w.wallets;
 const known=suggested.map(item=>({item,wallet:available.find(wallet=>item.match.test(wallet.rdns||'')||item.match.test(wallet.name))}));
 const other=available.filter(wallet=>!suggested.some(item=>item.match.test(wallet.rdns||'')||item.match.test(wallet.name)));
 useEffect(()=>{const show=()=>setOpen(true);window.addEventListener('dynamica:open-wallet',show);return()=>window.removeEventListener('dynamica:open-wallet',show);},[]);
 return <>
  <Button variant="outline" className="wallet-btn wallet-trigger" onClick={()=>setOpen(true)}><Wallet size={16} aria-hidden="true"/><span>{w.address?w.address.slice(0,6)+'…'+w.address.slice(-4):'Connect Wallet'}</span></Button>
  <Dialog open={open} onOpenChange={setOpen}><DialogContent className="modal wallet-dialog"><DialogTitle>{w.address?'Your wallet':'Connect Wallet'}</DialogTitle>
   <DialogDescription>{w.address?'Review the connected account and network.':'Choose an Ethereum-compatible wallet. Only your wallet can authorize access.'}</DialogDescription>
   {w.address?<div className="wallet-connected">
    <div className="wallet-connected-heading"><WalletMark name={w.walletName||'Browser wallet'} icon={available.find(item=>item.provider===w.provider)?.icon}/><div><strong>{w.walletName||'Browser wallet'}</strong><span>Connected account</span></div></div>
    <div className="address-box">{w.address}</div>
    <dl className="review-list"><div><dt>Network</dt><dd>{w.chainId===46630?'Robinhood Testnet':`Chain ${w.chainId??'unknown'}`}</dd></div><div><dt>Testnet ETH</dt><dd>{w.chainId===46630?(w.balance===null?'Unavailable':Number(w.balance).toLocaleString(undefined,{maximumFractionDigits:6})):'Switch to testnet'}</dd></div><div><dt>Last read</dt><dd>{w.balanceTime?new Date(w.balanceTime).toLocaleTimeString():'Not read'}</dd></div></dl>
    <div className="wallet-actions">{w.chainId!==46630&&<Button onClick={w.switchNetwork} disabled={w.busy}>Switch to Robinhood Testnet</Button>}<Button variant="outline" onClick={w.refresh} disabled={w.busy}><RefreshCw size={15}/>Refresh balance</Button><Button variant="ghost" onClick={()=>{w.disconnect();setOpen(false);}}>Disconnect from this app</Button></div>
    {detailed&&<TokenBalance key={w.address+':'+w.chainId}/>}
   </div>:<>
    <div className="wallet-option-group"><span className="wallet-group-label">CHOOSE A WALLET</span>
     {!available.length&&<p className="wallet-empty">No wallet detected. Install a wallet, or open Dynamica in your wallet’s browser.</p>}
     {known.map(({item,wallet})=>wallet?<button type="button" className="wallet-option" key={item.name} disabled={w.busy} onClick={async()=>{if(await w.connect(wallet.id))setOpen(false);}}><WalletMark name={item.name} icon={wallet.icon}/><span className="wallet-option-copy"><strong>{item.name}</strong><small>Available in this browser</small></span><span className="wallet-option-action">{w.busy?'Connecting…':'Connect'}</span></button>:<a key={item.name} href={item.url} target="_blank" rel="noopener noreferrer" className="wallet-option install-option" aria-label={`Install ${item.name} (opens a new tab)`}><WalletMark name={item.name} icon={item.icon}/><span className="wallet-option-copy"><strong>{item.name}</strong><small>Install or open in wallet browser</small></span><ExternalLink size={16} aria-hidden="true"/></a>)}
     {other.map(wallet=><button type="button" className="wallet-option" key={wallet.id} disabled={w.busy} onClick={async()=>{if(await w.connect(wallet.id))setOpen(false);}}><WalletMark name={wallet.name} icon={wallet.icon}/><span className="wallet-option-copy"><strong>{wallet.name}</strong><small>Available in this browser</small></span><span className="wallet-option-action">{w.busy?'Connecting…':'Connect'}</span></button>)}
    </div>
    <button type="button" className="wallet-refresh" onClick={w.rescan} disabled={w.busy}><RefreshCw size={14}/> Refresh wallets</button>
    <p className="wallet-hint">On mobile, open this site in your wallet’s browser. Connecting requires your approval in the wallet and does not submit a transaction.</p>
   </>}
   {w.error&&<p className="error" role="alert">{w.error}</p>}
  </DialogContent></Dialog>
 </>;
}
