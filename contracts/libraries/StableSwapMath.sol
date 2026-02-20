// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StableSwapMath
 * @notice Math library for stableswap invariant calculations
 * @dev Implements Curve Finance's stableswap invariant:
 * D = A * sum(x_i) + product(x_i) ^ (n / (n * A + sum(x_i)))
 */
library StableSwapMath {
    uint256 internal constant A_PRECISION = 100;
    uint256 internal constant N_COINS = 3;
    uint256 internal constant PRECISION = 1e18;

    /**
     * @notice Calculate D (invariant) using Newton's method
     * @param xp Balances scaled by token decimals
     * @param amp Amplification parameter
     * @return D value
     */
    function getD(uint256[N_COINS] memory xp, uint256 amp) internal pure returns (uint256) {
        uint256 s = 0;
        for (uint256 i = 0; i < N_COINS; i++) {
            s += xp[i];
        }
        if (s == 0) {
            return 0;
        }

        uint256 d = s;
        uint256 ann = amp * N_COINS;

        for (uint256 i = 0; i < 255; i++) {
            uint256 dP = d;
            for (uint256 j = 0; j < N_COINS; j++) {
                dP = (dP * d) / (xp[j] * N_COINS + 1);
            }
            uint256 dPrev = d;
            d = ((ann * s + dP * N_COINS) * d) / ((ann - 1) * d + (N_COINS + 1) * dP);
            if (d > dPrev) {
                if (d - dPrev <= 1) {
                    return d;
                }
            } else {
                if (dPrev - d <= 1) {
                    return d;
                }
            }
        }
        return d;
    }

    /**
     * @notice Calculate y (output amount) for a given x (input amount)
     * @param x Balance of input token
     * @param amp Amplification parameter
     * @param d Current D value
     * @param i Index of input token
     * @param j Index of output token
     * @param xp Current balances
     * @return y Output amount
     */
    function getY(
        uint256 x,
        uint256 amp,
        uint256 d,
        uint256 i,
        uint256 j,
        uint256[N_COINS] memory xp
    ) internal pure returns (uint256) {
        uint256 ann = amp * N_COINS;
        uint256 c = d;
        uint256 s = 0;
        uint256 _x = 0;

        for (uint256 k = 0; k < N_COINS; k++) {
            if (k == i) {
                _x = x;
            } else if (k != j) {
                _x = xp[k];
            } else {
                continue;
            }
            s += _x;
            c = (c * d) / (_x * N_COINS);
        }
        c = (c * d) / (ann * N_COINS);
        uint256 b = s + d / ann;

        uint256 y = d;
        for (uint256 k = 0; k < 255; k++) {
            uint256 yPrev = y;
            y = (y * y + c) / (2 * y + b - d);
            if (y > yPrev) {
                if (y - yPrev <= 1) {
                    return y;
                }
            } else {
                if (yPrev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

    /**
     * @notice Calculate output amount for a swap
     * @param i Index of input token
     * @param j Index of output token
     * @param dx Amount of input token
     * @param xp Current balances
     * @param amp Amplification parameter
     * @return dy Output amount
     */
    function getYD(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256[N_COINS] memory xp,
        uint256 amp
    ) internal pure returns (uint256) {
        uint256 x = xp[i] + dx;
        uint256 d = getD(xp, amp);
        uint256[N_COINS] memory newXp = xp;
        newXp[i] = x;
        uint256 y = getY(x, amp, d, i, j, newXp);
        uint256 dy = xp[j] - y - 1;
        return dy;
    }

    /**
     * @notice Calculate LP tokens to mint for given deposit
     * @param amounts Deposit amounts
     * @param xp Current balances
     * @param amp Amplification parameter
     * @param totalSupply Current LP token supply
     * @return lpAmount LP tokens to mint
     */
    function calculateLPTokens(
        uint256[N_COINS] memory amounts,
        uint256[N_COINS] memory xp,
        uint256 amp,
        uint256 totalSupply
    ) internal pure returns (uint256) {
        uint256 d0 = getD(xp, amp);
        uint256[N_COINS] memory newXp = xp;
        for (uint256 i = 0; i < N_COINS; i++) {
            newXp[i] += amounts[i];
        }
        uint256 d1 = getD(newXp, amp);
        if (totalSupply == 0) {
            return d1;
        }
        return (totalSupply * (d1 - d0)) / d0;
    }
}
