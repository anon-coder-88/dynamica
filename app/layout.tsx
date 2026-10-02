import type { Metadata } from 'next';
import './globals.css';
import './refinement.css';
import './landing.css';
import './transitions.css';
import {PageTransitions} from '@/components/dynamica/PageTransitions';
import {pageTransitionBoot} from '@/lib/page-transitions';
import {WalletProvider} from '@/components/dynamica/wallet';
import {Experience} from '@/components/dynamica/Experience';
export const metadata: Metadata = {title:'Dynamica — Capital, in motion.',description:'Build, explore, and govern financial strategies in one connected ecosystem. Capital, in motion. By your rules.',icons:{icon:'/favicon.svg',shortcut:'/favicon.svg'}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en" suppressHydrationWarning><head><script dangerouslySetInnerHTML={{__html:pageTransitionBoot}}/></head><body><div id="site-content"><WalletProvider><a href="#main" className="skip-link">Skip to content</a>{children}<Experience/></WalletProvider></div><PageTransitions/></body></html>}
