// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TestSupport, MockAsset} from "./TestSupport.sol";
import {DynamicaStrategyVault} from "../contracts/DynamicaStrategyVault.sol";
import {DynamicaVaultFactory} from "../contracts/DynamicaVaultFactory.sol";
import {DynamicaTestAsset} from "../contracts/DynamicaTestAsset.sol";

contract FactoryAndAuthorityTest is TestSupport {
    DynamicaVaultFactory internal factory;

    function setUp() public override {
        super.setUp();
        factory = new DynamicaVaultFactory();
    }

    function testFactorySetsCreatorAsVaultOwner() public {
        vm.prank(ALICE);
        address deployed = factory.createVault(IERC20(address(token)), 100 ether, bytes32("first"));
        DynamicaStrategyVault created = DynamicaStrategyVault(deployed);
        assertEq(created.owner(), ALICE, "Factory must not retain owner authority");
        assertEq(created.asset(), address(token), "Created vault asset differs from request");
        assertEq(created.assetCap(), 100 ether, "Created vault cap differs from request");
        assertEq(created.reserve().vault(), deployed, "Created reserve is not bound to created vault");
        assertEq(created.policyVersion(), 0, "Factory silently authorized an operator");
        assertTrue(factory.isVault(deployed), "Factory omitted created vault from registry");
    }

    function testPredictedAddressMatchesCreate2Deployment() public {
        bytes32 salt = keccak256("deterministic vault");
        address predicted = factory.predictVault(IERC20(address(token)), 100 ether, ALICE, salt);
        vm.prank(ALICE);
        address deployed = factory.createVault(IERC20(address(token)), 100 ether, salt);
        assertEq(deployed, predicted, "CREATE2 prediction differs from actual deployment");
        assertTrue(deployed.code.length > 0, "Factory result has no bytecode");
    }

    function testDuplicateCreatorSaltCannotOverwriteRegistry() public {
        bytes32 salt = bytes32("duplicate");
        vm.prank(ALICE);
        address first = factory.createVault(IERC20(address(token)), 100 ether, salt);
        vm.expectRevert(DynamicaVaultFactory.DuplicateSalt.selector);
        vm.prank(ALICE);
        factory.createVault(IERC20(address(token)), 200 ether, salt);
        bytes32 key = keccak256(abi.encode(ALICE, salt));
        assertEq(factory.vaultByKey(key), first, "Duplicate salt overwrote registry address");
        assertEq(factory.vaultCount(), 1, "Duplicate creation appended a record");
    }

    function testAnotherCreatorCanUseSameSaltWithoutCollision() public {
        bytes32 salt = bytes32("shared salt");
        vm.prank(ALICE);
        address a = factory.createVault(IERC20(address(token)), 100 ether, salt);
        vm.prank(BOB);
        address b = factory.createVault(IERC20(address(token)), 100 ether, salt);
        assertTrue(a != b, "Creator namespaces collided");
        assertEq(DynamicaStrategyVault(a).owner(), ALICE, "First creator lost ownership");
        assertEq(DynamicaStrategyVault(b).owner(), BOB, "Second creator lost ownership");
        assertEq(factory.vaultCount(), 2, "Independent creations missing from registry");
    }

    function testFactoryRejectsAddressWithoutAssetCode() public {
        vm.expectRevert(DynamicaVaultFactory.InvalidAsset.selector);
        factory.createVault(IERC20(OUTSIDER), 100 ether, bytes32("bad asset"));
        vm.expectRevert(DynamicaVaultFactory.InvalidAsset.selector);
        factory.createVault(IERC20(address(0)), 100 ether, bytes32("zero asset"));
        assertEq(factory.vaultCount(), 0, "Invalid asset created a record");
    }

    function testFactoryRejectsZeroCapAndAllowsRetryOfSalt() public {
        bytes32 salt = bytes32("retry");
        vm.expectRevert();
        vm.prank(ALICE);
        factory.createVault(IERC20(address(token)), 0, salt);
        assertEq(factory.vaultCount(), 0, "Failed constructor left registry state");
        vm.prank(ALICE);
        address deployed = factory.createVault(IERC20(address(token)), 100 ether, salt);
        assertTrue(factory.isVault(deployed), "Failed deployment consumed creator salt");
    }

    function testRegistryRecordPreservesProvenance() public {
        uint256 timestamp = block.timestamp;
        vm.prank(ALICE);
        address deployed = factory.createVault(IERC20(address(token)), 100 ether, bytes32("record"));
        DynamicaVaultFactory.Record memory record = factory.vaultAt(0);
        assertEq(record.vault, deployed, "Record vault address mismatch");
        assertEq(record.asset, address(token), "Record asset address mismatch");
        assertEq(record.creator, ALICE, "Record creator mismatch");
        assertEq(record.createdAt, timestamp, "Record timestamp mismatch");
        assertTrue(!factory.isVault(address(vault)), "Registry incorrectly endorses an unregistered vault");
    }

    function testRegistryPaginationPreservesOrderAndClampsLength() public {
        address[] memory deployed = new address[](3);
        for (uint256 i; i < deployed.length; i++) {
            vm.prank(ALICE);
            deployed[i] = factory.createVault(IERC20(address(token)), 100 ether, bytes32(i));
        }
        DynamicaVaultFactory.Record[] memory first = factory.listVaults(0, 2);
        assertEq(first.length, 2, "First page does not honor limit");
        assertEq(first[0].vault, deployed[0], "First page order changed");
        assertEq(first[1].vault, deployed[1], "First page omitted second vault");
        DynamicaVaultFactory.Record[] memory tail = factory.listVaults(2, 100);
        assertEq(tail.length, 1, "Tail page must clamp to remaining records");
        assertEq(tail[0].vault, deployed[2], "Tail page returned wrong record");
    }

    function testRegistryEmptyPagesAndOversizeRequest() public {
        assertEq(factory.listVaults(0, 10).length, 0, "Empty registry returned records");
        vm.prank(ALICE);
        factory.createVault(IERC20(address(token)), 100 ether, bytes32("page"));
        assertEq(factory.listVaults(1, 10).length, 0, "Offset at end returned records");
        assertEq(factory.listVaults(type(uint256).max, 10).length, 0, "Huge offset overflowed");
        assertEq(factory.listVaults(0, 0).length, 0, "Zero limit returned records");
        vm.expectRevert(DynamicaVaultFactory.PageTooLarge.selector);
        factory.listVaults(0, 101);
    }

    function testUnregisteredAddressIsNotMarkedAsVault() public view {
        assertTrue(!factory.isVault(ALICE), "User account incorrectly marked as vault");
        assertTrue(!factory.isVault(address(token)), "Asset contract incorrectly marked as vault");
        assertTrue(!factory.isVault(address(factory)), "Factory incorrectly marked as vault");
    }

    function testIndependentVaultsCannotConsumeEachOthersReserve() public {
        vm.prank(ALICE);
        address first = factory.createVault(IERC20(address(token)), 100 ether, bytes32("a"));
        vm.prank(BOB);
        address second = factory.createVault(IERC20(address(token)), 100 ether, bytes32("b"));
        DynamicaStrategyVault a = DynamicaStrategyVault(first);
        DynamicaStrategyVault b = DynamicaStrategyVault(second);
        vm.startPrank(ALICE);
        token.approve(first, 100 ether);
        a.deposit(100 ether, ALICE);
        vm.stopPrank();
        vm.startPrank(BOB);
        token.approve(second, 100 ether);
        b.deposit(100 ether, BOB);
        vm.stopPrank();
        DynamicaStrategyVault.Policy memory p = policy(8000, 100 ether, 100 ether);
        vm.prank(ALICE);
        a.configurePolicy(p);
        vm.prank(KEEPER);
        a.rebalance(1, 0);
        assertEq(a.reserve().totalAssets(), 80 ether, "First vault allocation missing");
        assertEq(b.reserve().totalAssets(), 0, "First vault moved assets into second reserve");
        assertEq(b.totalAssets(), 100 ether, "First vault changed second vault accounting");
        vm.prank(BOB);
        b.withdraw(100 ether, BOB, BOB);
        assertEq(a.totalAssets(), 100 ether, "Second vault exit consumed first vault assets");
    }

    function testOwnerTransferChangesAdministrativeAuthority() public {
        vault.transferOwnership(ALICE);
        assertEq(vault.owner(), ALICE, "Owner transfer did not change authority");
        vm.expectRevert();
        vault.setAssetCap(2000 ether);
        vm.prank(ALICE);
        vault.setAssetCap(2000 ether);
        assertEq(vault.assetCap(), 2000 ether, "New owner cannot update cap");
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 20 ether);
        vm.prank(ALICE);
        vault.configurePolicy(p);
        assertEq(vault.policyVersion(), 1, "New owner cannot configure policy");
    }

    function testRenouncedOwnerCannotRestoreAdministrativeControl() public {
        depositAlice(100 ether);
        vault.renounceOwnership();
        assertEq(vault.owner(), address(0), "Renunciation retained authority");
        vm.expectRevert();
        vault.setDepositsPaused(true);
        vm.prank(ALICE);
        vault.withdraw(100 ether, ALICE, ALICE);
        assertConservation(0);
    }

    function testFaucetClaimsExactlyOncePerAddress() public {
        DynamicaTestAsset faucet = new DynamicaTestAsset();
        vm.prank(ALICE);
        faucet.claim();
        assertEq(faucet.balanceOf(ALICE), 100 ether, "Faucet claim amount differs from advertised amount");
        assertTrue(faucet.claimed(ALICE), "Faucet did not mark address claimed");
        vm.expectRevert();
        vm.prank(ALICE);
        faucet.claim();
        vm.prank(BOB);
        faucet.claim();
        assertEq(faucet.totalSupply(), 200 ether, "Faucet supply does not reconcile with unique claims");
    }

    function testFaucetCanCompleteRealVaultRoundTrip() public {
        DynamicaTestAsset faucet = new DynamicaTestAsset();
        DynamicaStrategyVault live = new DynamicaStrategyVault(IERC20(address(faucet)), 200 ether, ALICE);
        vm.startPrank(ALICE);
        faucet.claim();
        faucet.approve(address(live), 100 ether);
        live.deposit(100 ether, ALICE);
        vm.stopPrank();
        DynamicaStrategyVault.Policy memory p = policy(8000, 100 ether, 100 ether);
        vm.prank(ALICE);
        live.configurePolicy(p);
        vm.prank(KEEPER);
        live.rebalance(1, 0);
        vm.prank(ALICE);
        live.withdraw(100 ether, ALICE, ALICE);
        assertEq(faucet.balanceOf(ALICE), 100 ether, "Faucet principal lost during operator round trip");
        assertEq(live.totalSupply(), 0, "Faucet round trip left shares outstanding");
        assertEq(live.totalAssets(), 0, "Faucet round trip left custody assets behind");
    }

    function testFuzzPredictionSeparatesCreatorsAndCaps(bytes32 salt, uint96 capSeed) public {
        uint256 cap = uint256(capSeed) + 1;
        address a = factory.predictVault(IERC20(address(token)), cap, ALICE, salt);
        address b = factory.predictVault(IERC20(address(token)), cap, BOB, salt);
        address changedCap = factory.predictVault(IERC20(address(token)), cap + 1, ALICE, salt);
        assertTrue(a != b, "Prediction collided across creator namespaces");
        assertTrue(a != changedCap, "Prediction ignored constructor cap");
        vm.prank(ALICE);
        address actual = factory.createVault(IERC20(address(token)), cap, salt);
        assertEq(actual, a, "Fuzzed CREATE2 prediction does not match deployment");
    }
}
