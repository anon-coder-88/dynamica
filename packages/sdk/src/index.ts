import {getAddress, type Address, type PublicClient, type WalletClient, type Hash} from 'viem';
import {DynamicaStrategyVaultAbi as abi, DynamicaTestAssetAbi as assetAbi} from '../../abi/src/contracts.ts';

export type Policy = {
  operator: Address; reserveBps: number; minInterval: bigint; windowDuration: bigint;
  expiresAt: bigint; maxMove: bigint; windowLimit: bigint;
};
export type ExecutionRequest = {
  version: bigint; sequence: bigint; minimum: bigint; maximum: bigint; deadline: bigint;
};

/** Exact human decimal parsing. Excess precision is rejected, never rounded. */
export function parseAssetAmount(value: string, decimals: number): bigint {
  if (!Number.isInteger(decimals) || decimals < 0 || decimals > 77) throw new Error('Invalid asset precision');
  if (!/^(0|[1-9]\d*)(\.\d+)?$/.test(value)) throw new Error('Enter a positive decimal amount');
  const [whole, fraction = ''] = value.split('.');
  if (fraction.length > decimals) throw new Error('Amount exceeds asset precision');
  const amount = BigInt(whole) * 10n ** BigInt(decimals) + BigInt(fraction.padEnd(decimals, '0') || '0');
  if (amount <= 0n || amount >= 2n ** 256n) throw new Error('Amount outside uint256 range');
  return amount;
}

/** Bound to one chain and vault; each write checks signer/chain, simulates, and reconciles its receipt. */
export class StrategyVaultClient {
  constructor(readonly publicClient: PublicClient, readonly walletClient: WalletClient,
    readonly address: Address, readonly chainId: number) { getAddress(address); }

  async snapshot() {
    if (await this.publicClient.getChainId() !== this.chainId) throw new Error('Wrong network');
    const block = await this.publicClient.getBlock({blockTag:'latest'});
    const read = <T extends 'asset' | 'policyVersion' | 'executionCount' | 'totalAssets' | 'totalSupply' | 'previewRebalance'>(functionName:T) =>
      this.publicClient.readContract({address:this.address, abi, functionName, blockNumber:block.number});
    const [asset, version, sequence, totalAssets, totalSupply, preview] = await Promise.all([
      read('asset'), read('policyVersion'), read('executionCount'), read('totalAssets'), read('totalSupply'), read('previewRebalance')]);
    return {asset:asset as Address, version:version as bigint, sequence:sequence as bigint,
      totalAssets:totalAssets as bigint, totalSupply:totalSupply as bigint,
      preview:preview as readonly [boolean,bigint,number], blockNumber:block.number,
      timestamp:block.timestamp, chainId:this.chainId, mode:this.chainId===31337?'Local':'Testnet'};
  }

  private async signer(): Promise<Address> {
    if (![31337,46630].includes(this.chainId)) throw new Error('Only local or Robinhood Testnet writes supported');
    const [readChain, writeChain, addresses] = await Promise.all([
      this.publicClient.getChainId(), this.walletClient.getChainId(), this.walletClient.getAddresses()]);
    if (readChain!==this.chainId || writeChain!==this.chainId) throw new Error('Wrong network');
    const account = this.walletClient.account?.address ?? addresses[0];
    if (!account) throw new Error('Wallet disconnected');
    return account;
  }

  private async confirmed(hash:Hash) {
    const receipt = await this.publicClient.waitForTransactionReceipt({hash, confirmations:1});
    if (receipt.status!=='success') throw new Error(`Transaction reverted: ${hash}`);
    return receipt;
  }

  async approveExact(amount:bigint) {
    const account = await this.signer();
    const asset = await this.publicClient.readContract({address:this.address,abi,functionName:'asset'});
    const {request} = await this.publicClient.simulateContract({address:asset,abi:assetAbi,functionName:'approve',
      args:[this.address,amount],account});
    return this.confirmed(await this.walletClient.writeContract({...request,chain:this.walletClient.chain}));
  }

  async deposit(amount:bigint, minimumShares:bigint) {
    const account = await this.signer();
    const {request} = await this.publicClient.simulateContract({address:this.address,abi,functionName:'depositWithMinShares',
      args:[amount,account,minimumShares],account});
    return this.confirmed(await this.walletClient.writeContract({...request,chain:this.walletClient.chain}));
  }

  async redeem(shares:bigint, minimumAssets:bigint) {
    const account = await this.signer();
    const {request} = await this.publicClient.simulateContract({address:this.address,abi,functionName:'redeemWithMinAssets',
      args:[shares,account,account,minimumAssets],account});
    return this.confirmed(await this.walletClient.writeContract({...request,chain:this.walletClient.chain}));
  }

  async configure(policy:Policy) {
    const account = await this.signer();
    const {request} = await this.publicClient.simulateContract({address:this.address,abi,functionName:'configurePolicy',args:[policy],account});
    return this.confirmed(await this.walletClient.writeContract({...request,chain:this.walletClient.chain}));
  }

  async prepareExecution(ttlSeconds=120n): Promise<ExecutionRequest> {
    if (ttlSeconds<=0n || ttlSeconds>3600n) throw new Error('Preview lifetime must be 1–3600 seconds');
    const state = await this.snapshot();
    if (state.preview[2]!==0 || state.preview[1]===0n) throw new Error(`Execution blocked: ${state.preview[2]}`);
    return {version:state.version,sequence:state.sequence,minimum:state.preview[1],maximum:state.preview[1],deadline:state.timestamp+ttlSeconds};
  }

  async execute(bounds:ExecutionRequest) {
    const account = await this.signer();
    const {request} = await this.publicClient.simulateContract({address:this.address,abi,functionName:'rebalanceWithBounds',
      args:[bounds.version,bounds.sequence,bounds.minimum,bounds.maximum,bounds.deadline],account});
    return this.confirmed(await this.walletClient.writeContract({...request,chain:this.walletClient.chain}));
  }

  async revoke() {
    const account = await this.signer();
    const {request} = await this.publicClient.simulateContract({address:this.address,abi,functionName:'revokeOperator',account});
    return this.confirmed(await this.walletClient.writeContract({...request,chain:this.walletClient.chain}));
  }
}
