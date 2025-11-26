// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

library FixedPoint {
    uint256 internal constant ONE = 1e18; // 18 decimal places

    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;

        return product / ONE;
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256 result) {
        require(b != 0, "ZERO_DIVISION");

        uint256 aInflated = a * ONE;
        require(a == 0 || aInflated / a == ONE, "DIV_INTERNAL"); // mul overflow

        // The traditional divUp formula is:
        // divUp(x, y) := (x + y - 1) / y
        // To avoid intermediate overflow in the addition, we distribute the division and get:
        // divUp(x, y) := (x - 1) / y + 1
        // Note that this requires x != 0, if x == 0 then the result is zero
        //
        // Equivalent to:
        // result = a == 0 ? 0 : (a * FixedPoint.ONE - 1) / b + 1;
        assembly {
            result := mul(iszero(iszero(aInflated)), add(div(sub(aInflated, 1), b), 1))
        }
    }

    function complement(uint256 x) internal pure returns (uint256 result) {
        // Equivalent to:
        // result = (x < ONE) ? (ONE - x) : 0;
        assembly {
            result := mul(lt(x, ONE), sub(ONE, x))
        }
    }
}
