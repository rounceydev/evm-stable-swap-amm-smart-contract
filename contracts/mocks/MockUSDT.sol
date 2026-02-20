// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20.sol";

/**
 * @title MockUSDT
 * @notice Mock USDT stablecoin for testing
 */
contract MockUSDT is MockERC20 {
    constructor() MockERC20("Mock USDT", "mUSDT", 6, 10000000 * 10**6) {}
}
