"""Read-only Dynamica vault status. Never needs or accepts a private key."""
import json
import os
import sys
from pathlib import Path
from web3 import Web3

RPC = os.environ.get("RH_TESTNET_RPC_URL", "https://rpc.testnet.chain.robinhood.com")
VAULT = os.environ.get("DYNAMICA_VAULT_ADDRESS", "")
ACCOUNT = os.environ.get("DYNAMICA_ACCOUNT_ADDRESS", "")
if not Web3.is_address(VAULT):
    sys.exit("Set DYNAMICA_VAULT_ADDRESS to a deployed testnet vault")
w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 12}))
if w3.eth.chain_id != 46630:
    sys.exit("RPC is not Robinhood Testnet (46630)")
abi = json.loads((Path(__file__).parent / "vault_read_abi.json").read_text())
vault = w3.eth.contract(address=Web3.to_checksum_address(VAULT), abi=abi)
asset = vault.functions.asset().call()
decimals = vault.functions.decimals().call()
result = {"chain_id": 46630, "vault": VAULT, "asset": asset,
          "total_assets": str(vault.functions.totalAssets().call()),
          "share_supply": str(vault.functions.totalSupply().call()),
          "asset_cap": str(vault.functions.assetCap().call()),
          "deposits_paused": vault.functions.depositsPaused().call(),
          "share_decimals": decimals}
if ACCOUNT:
    if not Web3.is_address(ACCOUNT):
        sys.exit("DYNAMICA_ACCOUNT_ADDRESS is invalid")
    owner = Web3.to_checksum_address(ACCOUNT)
    result["shares"] = str(vault.functions.balanceOf(owner).call())
    result["withdrawable_assets"] = str(vault.functions.maxWithdraw(owner).call())
print(json.dumps(result, indent=2))
