// Ported from Solidity:
// https://github.com/balancer-labs/balancer-v2-monorepo/blob/ce70f7663e0ac94b25ed60cb86faaa8199fd9e13/pkg/solidity-utils/contracts/math/Math.sol

export const ZERO = 0n;
export const ONE = 1n;
export const TWO = 2n;

export const abs = (a: bigint): bigint => {
  return a > 0n ? a : -a;
};

export const add = (a: bigint, b: bigint): bigint => {
  return a + b;
};

export const sub = (a: bigint, b: bigint): bigint => {
  if (b > a) {
    throw new Error("SUB_OVERFLOW");
  }
  return a - b;
};

export const max = (a: bigint, b: bigint): bigint => {
  return a >= b ? a : b;
};

export const min = (a: bigint, b: bigint): bigint => {
  return a < b ? a : b;
};

export const mul = (a: bigint, b: bigint): bigint => {
  return a * b;
};

export const div = (
  a: bigint,
  b: bigint,
  roundUp: boolean
): bigint => {
  return roundUp ? divUp(a, b) : divDown(a, b);
};

export const divDown = (a: bigint, b: bigint): bigint => {
  if (b === 0n) {
    throw new Error("ZERO_DIVISION");
  }
  return a / b;
};

export const divUp = (a: bigint, b: bigint): bigint => {
  if (b === 0n) {
    throw new Error("ZERO_DIVISION");
  }
  return a === 0n ? ZERO : ONE + (a - ONE) / b;
};
