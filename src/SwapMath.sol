// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

import {FixedPoint} from "./FixedPoint.sol";
import {StableMath} from "./StableMath.sol";
import {console} from "forge-std/Console.sol";

contract SwapMath {
    using FixedPoint for uint256;

    function _upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal pure {
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = amounts[i] * scalingFactors[i] / FixedPoint.ONE;
        }
    }

    function _downscaleUp(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return FixedPoint.divUp(amount, scalingFactor);
    }

    function getAfterSwapOutBalances(
        uint256[] memory balances,
        uint256[] memory scalingFactors,
        uint256 indexIn,
        uint256 indexOut,
        uint256 swapOutAmount,
        uint256 amp,
        uint256 swapFeePercentage
    ) external pure returns (uint256[] memory) {
        uint256 balancesIn = balances[indexIn];
        uint256 balancesOut = balances[indexOut];

        _upscaleArray(balances, scalingFactors);

        uint256 swapOutAmountAfterScale = swapOutAmount * scalingFactors[indexOut] / FixedPoint.ONE;

        uint256 invariant = StableMath._calculateInvariant(amp, balances);
        console.log("invariant:", invariant);
        uint256 amountIn =
            StableMath._calcInGivenOut(amp, balances, indexIn, indexOut, swapOutAmountAfterScale, invariant);

        amountIn = _downscaleUp(amountIn, scalingFactors[indexIn]);

        uint256 amountInWithFee = amountIn.divUp(swapFeePercentage.complement());

        // balancesIn += amountInWithFee;
        // balancesOut -= swapOutAmount;

        uint256[] memory newBalances = new uint256[](balances.length);
        newBalances[indexIn] = balancesIn + amountInWithFee;
        newBalances[indexOut] = balancesOut - swapOutAmount;

        return newBalances;
    }
}
