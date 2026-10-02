# Wallet connection update

The public header previously had no wallet entry point. The app header opened a dialog whose only connection action called `window.ethereum` directly, so multiple installed wallets could not be selected. Both headers now use the same Connect Wallet selector, and Token Studio's connection prompts open it as well.

Installed EVM wallets are discovered through EIP-6963 announcements. Each announced provider supplies its name and icon; selecting one calls `eth_requestAccounts` on that exact provider. A legacy `window.ethereum` option remains for wallets without EIP-6963 support. Duplicate legacy entries for an already announced provider are hidden. MetaMask, Coinbase Wallet, and Rabby links are offered when those wallets are not detected. These links open the vendors' pages and are labeled Install or open wallet; they are not falsely shown as connected providers.

The chosen provider is used for account, chain, balance, token reads, and testnet writes. Account/chain events update the shared state. Disconnect clears this app's state but does not revoke the wallet extension's site authorization. Robinhood Testnet remains the only enabled write network. The panel never requests a signature or transaction merely by opening.

WalletConnect QR pairing was not included: the official Wagmi connector requires an application-specific WalletConnect Project ID, which this project has not supplied. The selector does not show a nonfunctional QR option. Mobile visitors can open the site inside a supported wallet browser.

Build, TypeScript, static export, route smoke, and page-transition regressions passed. The connection dialog and real wallet authorization require browser testing with installed wallets; no such runtime validation is claimed here. The reference domains did not expose their actual wallet menus through the available retrieval/browser access, so the precise third-party lists could not be verified.
