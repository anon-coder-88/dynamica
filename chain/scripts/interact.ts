import { network } from "hardhat";
import { parseUnits, formatUnits, getAddress } from "ethers";

const { ethers } = await network.create();
const chain = await ethers.provider.getNetwork();
if (chain.chainId !== 46630n) throw Error("This script only writes on Robinhood Testnet");
const address = getAddress(process.env.DYNAMICA_VAULT_ADDRESS ?? "");
const amount = parseUnits(process.env.DYNAMICA_AMOUNT ?? "1", 18);
const [signer] = await ethers.getSigners();
const vault = await ethers.getContractAt("DynamicaVault", address, signer);
const asset = await ethers.getContractAt("DynamicaTestAsset", await vault.asset(), signer);
const account = await signer.getAddress();
const action = process.env.DYNAMICA_ACTION ?? "status";
if (action === "claim") await (await asset.claim()).wait();
else if (action === "deposit") {
  if (amount > await vault.maxDeposit(account)) throw Error("Vault capacity exceeded or deposits paused");
  await (await asset.approve(address, amount)).wait();
  await (await vault.deposit(amount, account)).wait();
} else if (action === "withdraw") {
  if (amount > await vault.maxWithdraw(account)) throw Error("Insufficient withdrawable assets");
  await (await vault.withdraw(amount, account, account)).wait();
} else if (action !== "status") throw Error("Use status, claim, deposit, or withdraw");
console.log(JSON.stringify({ chainId: chain.chainId.toString(), vault: address,
  assetBalance: formatUnits(await asset.balanceOf(account), 18),
  shares: formatUnits(await vault.balanceOf(account), 18),
  withdrawable: formatUnits(await vault.maxWithdraw(account), 18) }, null, 2));
