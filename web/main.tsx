import React from 'react';
import {createRoot} from 'react-dom/client';
import {WalletProvider} from '../components/dynamica/wallet';
import {WalletConnect} from '../components/dynamica/WalletConnect';
import {LiveVault} from '../components/dynamica/LiveVault';
import {OperatorControls} from './OperatorControls';
import './style.css';
function App(){return <WalletProvider><header><a className="brand" href="/"><img src="/brand/mark.svg" alt=""/>Dynamica</a><WalletConnect/></header><main><div className="intro"><span className="eyebrow">UTILITY MVP · ROBINHOOD TESTNET</span><h1>Capital with clear boundaries.</h1><p>Deposit test assets, hold redeemable shares, and authorize a limited reserve operator. Every movement is recorded onchain.</p></div><LiveVault/><OperatorControls/></main><footer>Testnet source MVP · No investment strategy or yield · <a href="https://github.com/anon-coder-88/dynamica">Source and setup</a></footer></WalletProvider>}
createRoot(document.getElementById('root')!).render(<React.StrictMode><App/></React.StrictMode>);
