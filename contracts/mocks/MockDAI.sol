// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20.sol";

/**
 * @title MockDAI
 * @notice Mock DAI stablecoin for testing
 */
contract MockDAI is MockERC20 {
    constructor() MockERC20("Mock DAI", "mDAI", 18, 10000000 * 10**18) {}
}
