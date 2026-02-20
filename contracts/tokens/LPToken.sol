// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LPToken
 * @notice ERC-20 token representing liquidity provider shares in the pool
 */
contract LPToken is ERC20, Ownable {
    /// @notice The pool contract that can mint/burn LP tokens
    address public pool;

    /// @notice Events
    event PoolUpdated(address indexed oldPool, address indexed newPool);

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {}

    /**
     * @notice Sets the pool address (can only be set once)
     * @param _pool The pool contract address
     */
    function setPool(address _pool) external onlyOwner {
        require(_pool != address(0), "LPToken: invalid pool");
        require(pool == address(0), "LPToken: pool already set");
        pool = _pool;
        emit PoolUpdated(address(0), _pool);
    }

    /**
     * @notice Mints LP tokens (only callable by pool)
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == pool, "LPToken: only pool can mint");
        _mint(to, amount);
    }

    /**
     * @notice Burns LP tokens (only callable by pool)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external {
        require(msg.sender == pool, "LPToken: only pool can burn");
        _burn(from, amount);
    }
}
