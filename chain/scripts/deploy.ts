import { network } from "hardhat";
import { parseUnits } from "ethers";

const { ethers, networkName } = await network.create();
const chain = await ethers.provider.getNetwork();
if (networkName === "robinhoodTestnet" && chain.chainId !== 46630n) throw Error("Wrong chain ID");
const [deployer] = await ethers.getSigners();
if (!deployer) throw Error("Configure DEPLOYER_PRIVATE_KEY for testnet");
console.log(`Deploying with ${await deployer.getAddress()} to ${networkName} (${chain.chainId})`);

const asset = await ethers.deployContract("DynamicaTestAsset");
await asset.waitForDeployment();
const assetAddress = await asset.getAddress();
const cap = parseUnits("1000000", 18);
const vault = await ethers.deployContract("DynamicaVault", [assetAddress, cap, await deployer.getAddress()]);
await vault.waitForDeployment();
console.log(`Asset: ${assetAddress}\nVault: ${await vault.getAddress()}`);
console.log(`NEXT_PUBLIC_DYNAMICA_ASSET_ADDRESS=${assetAddress}`);
console.log(`NEXT_PUBLIC_DYNAMICA_VAULT_ADDRESS=${await vault.getAddress()}`);
