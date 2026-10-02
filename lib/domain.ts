export const vaults = [
 {id:'market-neutral',name:'Market neutral',type:'Market-Neutral Strategies',tag:'Hedged exposure',description:'Balance opposing positions to explore returns with reduced market direction.',risk:'Medium',allocation:'Hedged asset basket'},
 {id:'liquidity',name:'Liquidity provision',type:'Liquidity Strategies',tag:'Market depth',description:'Deploy capital across liquidity positions with defined concentration limits.',risk:'High',allocation:'ETH / USD sample pool'},
 {id:'rebalancing',name:'Adaptive balance',type:'Rebalancing Strategies',tag:'Portfolio weights',description:'Keep a portfolio close to target allocations as market conditions change.',risk:'Medium',allocation:'60% ETH / 40% BTC'},
 {id:'treasury',name:'Treasury reserve',type:'Treasury Strategies',tag:'Capital discipline',description:'Model reserve allocation within explicit spending and exposure boundaries.',risk:'Medium',allocation:'Reserve / growth basket'},
 {id:'yield',name:'Yield allocation',type:'Yield Strategies',tag:'Rate awareness',description:'Compare lending and yield allocations within a risk budget.',risk:'High',allocation:'Sample lending allocation'},
 {id:'volatility',name:'Volatility range',type:'Volatility Strategies',tag:'Dynamic conditions',description:'Test a bounded response to changing price volatility.',risk:'High',allocation:'Volatility-sensitive basket'},
] as const;
export const stages=['Observe','Evaluate','Authorize','Execute','Record','Reassess'];
export type Event = {id:string;time:string;module:string;asset:string;action:string;amount:number;status:string;mode:'Demo'};
export type Ledger={version:1;cash:number;positions:Record<string,number>;paused:Record<string,boolean>;collateral:number;debt:number;events:Event[];treasury:number[];operatorPaused:boolean};
export const freshLedger=():Ledger=>({version:1,cash:10000,positions:{},paused:{},collateral:0,debt:0,events:[],treasury:[30,15,25,10,10,5,5],operatorPaused:false});
export function amount(value:string,decimals=2):bigint{if(!Number.isInteger(decimals)||decimals<0||decimals>18)throw Error('Unsupported precision.');if(!(decimals===0?/^(0|[1-9]\d*)$/:new RegExp(`^(0|[1-9]\\d*)(\\.\\d{1,${decimals}})?$`)).test(value))throw Error(`Enter a positive amount with up to ${decimals} decimal places.`);const [a,b='']=value.split('.');const units=BigInt(a)*10n**BigInt(decimals)+BigInt(b.padEnd(decimals,'0'));if(units<=0n)throw Error('Amount must be greater than zero.');if(units>10n**36n)throw Error('Amount is too large.');return units;}
export function money(value:string):number{const a=amount(value,2);if(a>100000000000n)throw Error('Amount exceeds the demo limit.');return Number(a)/100;}
const cents=(v:number)=>Math.round(v*100)/100;
export function transact(state:Ledger,action:'deposit'|'withdraw'|'collateral'|'borrow'|'repay'|'release',key:string,value:string):Ledger{
 const a=money(value),s=structuredClone(state),have=s.positions[key]||0;
 if(action==='deposit'){if(s.paused[key])throw Error('This strategy is paused.');if(a>s.cash)throw Error('Insufficient demo balance.');s.cash=cents(s.cash-a);s.positions[key]=cents(have+a);}
 if(action==='withdraw'){if(a>have)throw Error('Amount exceeds your position.');s.positions[key]=cents(have-a);s.cash=cents(s.cash+a);}
 if(action==='collateral'){if(a>s.cash)throw Error('Insufficient demo balance.');s.cash=cents(s.cash-a);s.collateral=cents(s.collateral+a);}
 if(action==='borrow'){if(cents(s.debt+a)>Math.floor(s.collateral*50)/100)throw Error('Borrowing would exceed the 50% demo LTV limit.');s.debt=cents(s.debt+a);s.cash=cents(s.cash+a);}
 if(action==='repay'){if(a>s.debt||a>s.cash)throw Error('Amount exceeds debt or available balance.');s.debt=cents(s.debt-a);s.cash=cents(s.cash-a);}
 if(action==='release'){if(a>s.collateral||s.debt>(s.collateral-a)*.5)throw Error('Collateral is required to support your debt.');s.collateral=cents(s.collateral-a);s.cash=cents(s.cash+a);}
 return s;
}
export function allocations(values:number[]){if(values.length!==7||values.some(v=>!Number.isFinite(v)||v<0||v>100)||Math.abs(values.reduce((a,b)=>a+b,0)-100)>.0001)throw Error('All seven allocations must be nonnegative and total exactly 100%.');return values;}
export function laboratory(initial:number,days:number,risk:number,feeBps:number){if(!Number.isFinite(initial)||initial<=0||initial>1e9||!Number.isInteger(days)||days<7||days>365||!Number.isFinite(risk)||risk<1||risk>10||!Number.isFinite(feeBps)||feeBps<0||feeBps>100)throw Error('Use positive capital, 7–365 days, risk 1–10, and fees 0–100 bps.');let value=initial,peak=initial,drawdown=0;const series=[initial];for(let d=1;d<=days;d++){const ret=.0002+Math.sin(d*1.618)*risk*.003+Math.cos(d*.17)*risk*.001;value=value*(1+ret)*(1-feeBps/10000/days);peak=Math.max(peak,value);drawdown=Math.max(drawdown,(peak-value)/peak);series.push(value);}return {series,totalReturn:value/initial-1,drawdown,ending:value};}
export function validateLedger(x:unknown):x is Ledger{const s=x as Ledger;if(!s||s.version!==1||!Number.isFinite(s.cash)||s.cash<0||!Number.isFinite(s.collateral)||s.collateral<0||!Number.isFinite(s.debt)||s.debt<0||!s.positions||!s.paused||!Array.isArray(s.events)||typeof s.operatorPaused!=='boolean')return false;if(Object.values(s.positions).some(v=>!Number.isFinite(v)||v<0))return false;try{allocations(s.treasury);}catch{return false;}return s.events.every(e=>e.mode==='Demo'&&typeof e.id==='string'&&Number.isFinite(e.amount));}
