# Security and trust boundaries

This revision has local automated verification, not an independent audit. No production readiness claim or public deployment is made.

The owner can immediately change asset capacity, pause deposits, pause execution, transfer/renounce ownership, authorize or revoke an operator and replace policy. Replacement resets budget/cooldown. There is no timelock or multisig requirement. Owners cannot select arbitrary execution destinations or take another user's shares through administrative methods. Factory deployment is permissionless and does not certify assets or owners.

The operator controls transaction timing and pays gas but can only move the vault's asset between fixed custody locations within policy. Lack of operator availability does not stop withdrawals. Target reserve percentage is a goal observed per execution, not a continuously maintained exposure constraint. Existing assets can be redeemed under either pause, expiry or revocation. The reserve is completely liquid; an external investment adapter would require a new withdrawal and risk specification.

OpenZeppelin handles share rounding, safe transfers and reentrancy. Strategy entry points check exact receipts and user exit amounts; fee tokens are rejected where detected. Rebasing or malicious tokens are unsupported. Token failure can prevent transfers/withdrawals; no contract can promise recovery from an asset that refuses transfer. The retained legacy base vault lacks strategy-vault transfer guards and is not the intended factory product. Development faucet and malicious token fixtures must never be substituted for production asset approval.

Donations alter share value and can fill capacity. OpenZeppelin virtual offsets mitigate empty-vault inflation behavior; tests cover donation/dust/rounding. Use deposit/redeem minimums. Bounded operator submissions also include sequence, version, amount interval and deadline; legacy rebalance intentionally has recurring semantics. Reverts roll back state and transfers, including post-transfer upper-bound checks. Every external transfer route is protected by the strategy's shared reentrancy guard.

SDK checks network/signer, simulates and waits for real receipt. It does not guarantee scheduler availability, browser-provider honesty, RPC correctness, finality after one confirmation or wallet UX. Applications must retain unknown outcomes and reconcile a known transaction hash before retrying. No trading key, server signer, oracle, AI result or external protocol is present. No valuable assets should be introduced before approved production decisions and independent review.

Local automated tests cannot establish Robinhood Testnet behavior, browser accessibility, financial performance, economic soundness or adversarial completeness. See validation.md for performed and unperformed checks.
