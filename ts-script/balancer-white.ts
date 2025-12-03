import { upscale, upscaleArray, divUp, complement, downscaleUp } from "./fixed-point";
import { _calcInGivenOut } from "./stable";

const initBlanace: bigint[] = [
    1289182985200111n, // rETH
    1378334582400545n, // WETH
];

enum TokenIndex {
    rETH = 0,
    WETH = 1,
}

type Swap = {
    assetInIndex: TokenIndex;
    assetOutIndex: TokenIndex;
    amount: bigint;
}

export const addSwapFeeAmount = (amount: bigint, swapFeePercentage: bigint): bigint => {
    return divUp(amount, complement(swapFeePercentage));
}

const swapFeePercentage = 400000000000000n; // 0.04%
const amp = 50000n;
const scaleFactors = [1150339103169213008n, 10n ** 18n]; // rETH, WETH

export const swapGivenOut = (step: number, balances: bigint[], tokenIndexIn: TokenIndex, tokenIndexOut: TokenIndex, tokenAmountOut: bigint): bigint => {
    console.log(`Step: ${step}`);
    console.log(`   Initial Balances: `, balances);
    const scaledBalances = upscaleArray(initBlanace, scaleFactors);
    console.log(`   Scaled Balances: `, scaledBalances);

    const tokenAmountOutScaled = upscale(tokenAmountOut, scaleFactors[tokenIndexOut]);
    console.log(`   Token Amount Out (scaled): `, tokenAmountOutScaled);

    const amountIn = _calcInGivenOut(
        amp,
        scaledBalances,
        tokenIndexIn,
        tokenIndexOut,
        tokenAmountOutScaled,
    );

    const scaledAmountIn = downscaleUp(amountIn, scaleFactors[tokenIndexIn]);
    const amountInWithFee = addSwapFeeAmount(scaledAmountIn, swapFeePercentage);
    // console.log(`   Amount In (scaled):`, amountInWithFee);
    return amountInWithFee;
}

const swaps = (await Bun.file("whitehack.json").json())["swaps"] as Swap[];

// console.log("Swaps to perform:", swaps.length);
// swapGivenOut(1, initBlanace, TokenIndex.WETH, TokenIndex.rETH, 1289182985197611n);
let balance = initBlanace;

for (let i = 0; i < swaps.length; i++) {
    const swap = swaps[i];
    const amountInWithFee = swapGivenOut(i, initBlanace, swap.assetInIndex, swap.assetOutIndex, BigInt(swap.amount));
    console.log(`   Amount In with Fee: `, amountInWithFee);
    console.log("   Swap Amount Out: ", BigInt(swap.amount));
    balance[swap.assetInIndex] += amountInWithFee;
    balance[swap.assetOutIndex] -= BigInt(swap.amount);
    console.log(`   New Balances: `, balance);
}