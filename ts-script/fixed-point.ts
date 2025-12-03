// Ported from Solidity:
// https://github.com/balancer-labs/balancer-core-v2/blob/70843e6a61ad11208c1cfabf5cfe15be216ca8d3/pkg/solidity-utils/contracts/math/FixedPoint.sol

export const ZERO = 0n;
export const ONE = 1000000000000000000n; // 10^18

export const MAX_POW_RELATIVE_ERROR = 10000n; // 10^(-14)

// Minimum base for the power function when the exponent is 'free' (larger than ONE)
export const MIN_POW_BASE_FREE_EXPONENT = 700000000000000000n; // 0.7e18

export const add = (a: bigint, b: bigint): bigint => {
  // Fixed Point addition is the same as regular checked addition
  return a + b;
};

export const sub = (a: bigint, b: bigint): bigint => {
  // Fixed Point subtraction is the same as regular checked subtraction
  if (b > a) {
    throw new Error("SUB_OVERFLOW");
  }
  return a - b;
};

export const mulDown = (a: bigint, b: bigint): bigint => {
  return (a * b) / ONE;
};

export const mulUp = (a: bigint, b: bigint): bigint => {
  const product = a * b;
  if (product === 0n) {
    return product;
  } else {
    // The traditional divUp formula is:
    // divUp(x, y) := (x + y - 1) / y
    // To avoid intermediate overflow in the addition, we distribute the division and get:
    // divUp(x, y) := (x - 1) / y + 1
    // Note that this requires x != 0, which we already tested for

    return (product - 1n) / ONE + 1n;
  }
};

export const divDown = (a: bigint, b: bigint): bigint => {
  if (b === 0n) {
    throw new Error("ZERO_DIVISION");
  }
  if (a === 0n) {
    return a;
  } else {
    return (a * ONE) / b;
  }
};

export const divUp = (a: bigint, b: bigint): bigint => {
  if (b === 0n) {
    throw new Error("ZERO_DIVISION");
  }
  if (a === 0n) {
    return a;
  } else {
    // The traditional divUp formula is:
    // divUp(x, y) := (x + y - 1) / y
    // To avoid intermediate overflow in the addition, we distribute the division and get:
    // divUp(x, y) := (x - 1) / y + 1
    // Note that this requires x != 0, which we already tested for.

    return (a * ONE - 1n) / b + 1n;
  }
};

export const complement = (x: bigint): bigint => {
  return x < ONE ? ONE - x : 0n;
};

export const upscale = (a: bigint, scalingFactor: bigint): bigint => {
    return (a * scalingFactor) / BigInt(1e18);
}

export const upscaleArray = (balances: bigint[], scalingFactors: bigint[]): bigint[] => {
    return balances.map((balance, i) => upscale(balance, scalingFactors[i]));
}

export const downscaleUp = (a: bigint, scalingFactor: bigint): bigint => {
    return divUp(a, scalingFactor);
}