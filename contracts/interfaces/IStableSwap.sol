// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStableSwap
 * @notice Interface for StableSwap AMM pool
 */
interface IStableSwap {
    /**
     * @notice Add liquidity to the pool
     * @param amounts Amounts of each token to add
     * @param minMintAmount Minimum LP tokens to mint
     * @param deadline Transaction deadline
     * @return Amount of LP tokens minted
     */
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minMintAmount,
        uint256 deadline
    ) external returns (uint256);

    /**
     * @notice Remove liquidity from the pool
     * @param amount Amount of LP tokens to burn
     * @param minAmounts Minimum amounts of each token to receive
     * @param deadline Transaction deadline
     * @return Amounts of tokens withdrawn
     */
    function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external returns (uint256[] memory);

    /**
     * @notice Remove liquidity in a single token
     * @param tokenAmount Amount of LP tokens to burn
     * @param i Index of token to withdraw
     * @param minAmount Minimum amount of token to receive
     * @param deadline Transaction deadline
     * @return Amount of token withdrawn
     */
    function removeLiquidityOneCoin(
        uint256 tokenAmount,
        uint256 i,
        uint256 minAmount,
        uint256 deadline
    ) external returns (uint256);

    /**
     * @notice Exchange tokens
     * @param i Index of token to sell
     * @param j Index of token to buy
     * @param dx Amount of token i to sell
     * @param minDy Minimum amount of token j to receive
     * @param deadline Transaction deadline
     * @return Amount of token j received
     */
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);

    /**
     * @notice Get virtual price (LP token price in underlying)
     * @return Virtual price scaled by 1e18
     */
    function getVirtualPrice() external view returns (uint256);

    /**
     * @notice Get current D (invariant)
     * @return Current D value
     */
    function getD() external view returns (uint256);

    /**
     * @notice Get current amplification parameter
     * @return Current A value
     */
    function getA() external view returns (uint256);
}
