// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./tokens/LPToken.sol";
import "./libraries/StableSwapMath.sol";
import "./interfaces/IStableSwap.sol";

/**
 * @title StableSwap
 * @notice Curve Finance-inspired stablecoin AMM with stableswap invariant
 * @dev Supports 3-token pools with low slippage for stablecoin swaps
 */
contract StableSwap is IStableSwap, ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    uint256 private constant N_COINS = 3;
    uint256 private constant A_PRECISION = 100;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MAX_FEE = 10 * 1e6; // 0.1% max swap fee

    /// @notice LP token contract
    LPToken public lpToken;

    /// @notice Array of token addresses
    address[N_COINS] public coins;

    /// @notice Array of token decimals
    uint256[N_COINS] public decimals;

    /// @notice Current amplification parameter
    uint256 public A;

    /// @notice Target amplification parameter (for ramping)
    uint256 public futureA;

    /// @notice Timestamp when A ramp started
    uint256 public initialATime;

    /// @notice Timestamp when A ramp ends
    uint256 public futureATime;

    /// @notice Swap fee (in 1e10 units, e.g., 4000000 = 0.04%)
    uint256 public swapFee;

    /// @notice Admin fee (as fraction of swap fee, in 1e10 units)
    uint256 public adminFee;

    /// @notice Withdrawal fee (in 1e10 units)
    uint256 public withdrawFee;

    /// @notice Admin address (for collecting fees)
    address public admin;

    /// @notice Events
    event AddLiquidity(
        address indexed provider,
        uint256[N_COINS] amounts,
        uint256 lpAmount,
        uint256 totalSupply
    );
    event RemoveLiquidity(
        address indexed provider,
        uint256[N_COINS] amounts,
        uint256 lpAmount
    );
    event RemoveLiquidityOne(
        address indexed provider,
        uint256 lpAmount,
        uint256 tokenAmount,
        uint256 i
    );
    event TokenExchange(
        address indexed buyer,
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 dy
    );
    event RampA(uint256 oldA, uint256 newA, uint256 initialTime, uint256 futureTime);
    event StopRampA(uint256 currentA, uint256 time);

    modifier deadlineCheck(uint256 deadline) {
        require(block.timestamp <= deadline, "StableSwap: deadline exceeded");
        _;
    }

    constructor(
        address[N_COINS] memory _coins,
        uint256[N_COINS] memory _decimals,
        address _lpToken,
        uint256 _A,
        uint256 _swapFee,
        uint256 _adminFee,
        address _admin
    ) Ownable(msg.sender) {
        require(_admin != address(0), "StableSwap: invalid admin");
        require(_swapFee <= MAX_FEE, "StableSwap: swap fee too high");

        coins = _coins;
        decimals = _decimals;
        lpToken = LPToken(_lpToken);
        A = _A * A_PRECISION;
        futureA = A;
        swapFee = _swapFee;
        adminFee = _adminFee;
        admin = _admin;

        // Set pool in LP token
        lpToken.setPool(address(this));
    }

    /**
     * @notice Get current balances
     * @return balances Array of token balances
     */
    function getBalances() public view returns (uint256[N_COINS] memory balances) {
        for (uint256 i = 0; i < N_COINS; i++) {
            balances[i] = IERC20(coins[i]).balanceOf(address(this));
        }
    }

    /**
     * @notice Get current amplification parameter (with ramping)
     * @return Current A value
     */
    function getA() public view override returns (uint256) {
        return _getA();
    }

    /**
     * @notice Internal function to get current A (with ramping)
     */
    function _getA() internal view returns (uint256) {
        uint256 t1 = futureATime;
        uint256 A1 = futureA;

        if (block.timestamp < t1) {
            uint256 A0 = A;
            uint256 t0 = initialATime;
            // Linear interpolation
            if (A1 > A0) {
                return A0 + ((A1 - A0) * (block.timestamp - t0)) / (t1 - t0);
            } else {
                return A0 - ((A0 - A1) * (block.timestamp - t0)) / (t1 - t0);
            }
        } else {
            return A1;
        }
    }

    /**
     * @notice Get current D (invariant)
     * @return Current D value
     */
    function getD() public view override returns (uint256) {
        uint256[N_COINS] memory xp = _xp();
        return StableSwapMath.getD(xp, _getA());
    }

    /**
     * @notice Get scaled balances (normalized to 1e18)
     */
    function _xp() internal view returns (uint256[N_COINS] memory xp) {
        uint256[N_COINS] memory balances = getBalances();
        for (uint256 i = 0; i < N_COINS; i++) {
            xp[i] = balances[i] * PRECISION;
            if (decimals[i] < 18) {
                xp[i] = xp[i] * (10 ** (18 - decimals[i]));
            } else if (decimals[i] > 18) {
                xp[i] = xp[i] / (10 ** (decimals[i] - 18));
            }
        }
    }

    /**
     * @notice Add liquidity to the pool
     */
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minMintAmount,
        uint256 deadline
    ) external override nonReentrant whenNotPaused deadlineCheck(deadline) returns (uint256) {
        require(amounts.length == N_COINS, "StableSwap: invalid amounts length");

        uint256[N_COINS] memory _amounts;
        for (uint256 i = 0; i < N_COINS; i++) {
            _amounts[i] = amounts[i];
        }

        uint256[N_COINS] memory oldBalances = getBalances();
        uint256[N_COINS] memory xp = _xp();

        // Transfer tokens
        for (uint256 i = 0; i < N_COINS; i++) {
            if (_amounts[i] > 0) {
                IERC20(coins[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
            }
        }

        uint256[N_COINS] memory newBalances = getBalances();
        uint256[N_COINS] memory fees;
        uint256 D0 = StableSwapMath.getD(xp, _getA());

        // Calculate fees and new amounts
        for (uint256 i = 0; i < N_COINS; i++) {
            uint256 idealBalance = (oldBalances[i] * D0) / (StableSwapMath.getD(xp, _getA()));
            uint256 difference = 0;
            if (idealBalance > newBalances[i]) {
                difference = idealBalance - newBalances[i];
            } else {
                difference = newBalances[i] - idealBalance;
            }
            fees[i] = (withdrawFee * difference) / (10 ** 10);
            newBalances[i] -= fees[i];
        }

        // Update xp with new balances
        for (uint256 i = 0; i < N_COINS; i++) {
            xp[i] = newBalances[i] * PRECISION;
            if (decimals[i] < 18) {
                xp[i] = xp[i] * (10 ** (18 - decimals[i]));
            } else if (decimals[i] > 18) {
                xp[i] = xp[i] / (10 ** (decimals[i] - 18));
            }
        }

        uint256 D1 = StableSwapMath.getD(xp, _getA());
        uint256 lpAmount = 0;
        uint256 totalSupply = lpToken.totalSupply();

        if (totalSupply == 0) {
            lpAmount = D1;
        } else {
            uint256[N_COINS] memory newAmounts;
            for (uint256 i = 0; i < N_COINS; i++) {
                newAmounts[i] = newBalances[i] - oldBalances[i];
            }
            lpAmount = StableSwapMath.calculateLPTokens(newAmounts, xp, _getA(), totalSupply);
        }

        require(lpAmount >= minMintAmount, "StableSwap: insufficient LP tokens");

        lpToken.mint(msg.sender, lpAmount);

        emit AddLiquidity(msg.sender, _amounts, lpAmount, totalSupply + lpAmount);
        return lpAmount;
    }

    /**
     * @notice Remove liquidity from the pool
     */
    function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts,
        uint256 deadline
    )
        external
        override
        nonReentrant
        whenNotPaused
        deadlineCheck(deadline)
        returns (uint256[] memory)
    {
        require(minAmounts.length == N_COINS, "StableSwap: invalid minAmounts length");

        uint256 totalSupply = lpToken.totalSupply();
        uint256[N_COINS] memory balances = getBalances();
        uint256[N_COINS] memory amounts;

        for (uint256 i = 0; i < N_COINS; i++) {
            amounts[i] = (balances[i] * amount) / totalSupply;
            require(amounts[i] >= minAmounts[i], "StableSwap: insufficient output");
        }

        lpToken.burn(msg.sender, amount);

        for (uint256 i = 0; i < N_COINS; i++) {
            IERC20(coins[i]).safeTransfer(msg.sender, amounts[i]);
        }

        emit RemoveLiquidity(msg.sender, amounts, amount);
        return amounts;
    }

    /**
     * @notice Remove liquidity in a single token
     */
    function removeLiquidityOneCoin(
        uint256 tokenAmount,
        uint256 i,
        uint256 minAmount,
        uint256 deadline
    )
        external
        override
        nonReentrant
        whenNotPaused
        deadlineCheck(deadline)
        returns (uint256)
    {
        require(i < N_COINS, "StableSwap: invalid token index");

        uint256 totalSupply = lpToken.totalSupply();
        uint256[N_COINS] memory xp = _xp();
        uint256 D0 = StableSwapMath.getD(xp, _getA());

        uint256 dy = (xp[i] * tokenAmount) / totalSupply;
        uint256 dyFee = (dy * withdrawFee) / (10 ** 10);
        dy = dy - dyFee;

        uint256 y = StableSwapMath.getY(
            xp[i] - dy,
            _getA(),
            D0,
            i,
            0,
            xp
        );

        dy = xp[i] - y - 1;
        dy = (dy - 1) * (10 ** decimals[i]) / PRECISION;

        require(dy >= minAmount, "StableSwap: insufficient output");

        lpToken.burn(msg.sender, tokenAmount);

        IERC20(coins[i]).safeTransfer(msg.sender, dy);

        emit RemoveLiquidityOne(msg.sender, tokenAmount, dy, i);
        return dy;
    }

    /**
     * @notice Exchange tokens
     */
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    )
        external
        override
        nonReentrant
        whenNotPaused
        deadlineCheck(deadline)
        returns (uint256)
    {
        require(i != j && i < N_COINS && j < N_COINS, "StableSwap: invalid token indices");

        IERC20(coins[i]).safeTransferFrom(msg.sender, address(this), dx);

        uint256[N_COINS] memory xp = _xp();
        uint256 x = xp[i] + (dx * PRECISION / (10 ** decimals[i]));

        uint256 dy = StableSwapMath.getYD(i, j, x - xp[i], xp, _getA());
        dy = (dy - 1) * (10 ** decimals[j]) / PRECISION;

        uint256 dyFee = (dy * swapFee) / (10 ** 10);
        uint256 dyAdminFee = (dyFee * adminFee) / (10 ** 10);
        dy = dy - dyFee;

        require(dy >= minDy, "StableSwap: insufficient output");

        IERC20(coins[j]).safeTransfer(msg.sender, dy);

        if (dyAdminFee > 0) {
            IERC20(coins[j]).safeTransfer(admin, dyAdminFee);
        }

        emit TokenExchange(msg.sender, i, j, dx, dy);
        return dy;
    }

    /**
     * @notice Get virtual price (LP token price in underlying)
     */
    function getVirtualPrice() external view override returns (uint256) {
        uint256 totalSupply = lpToken.totalSupply();
        if (totalSupply == 0) {
            return PRECISION;
        }
        uint256 D = getD();
        return (D * PRECISION) / totalSupply;
    }

    /**
     * @notice Ramp amplification parameter
     */
    function rampA(uint256 _futureA, uint256 _futureTime) external onlyOwner {
        require(block.timestamp >= futureATime, "StableSwap: previous ramp not finished");
        require(_futureTime >= block.timestamp + 86400, "StableSwap: ramp time too short");

        uint256 currentA = _getA();
        _futureA = _futureA * A_PRECISION;

        require(_futureA > 0 && _futureA < 1e6, "StableSwap: invalid A");

        initialATime = block.timestamp;
        futureATime = _futureTime;
        A = currentA;
        futureA = _futureA;

        emit RampA(currentA, _futureA, initialATime, futureATime);
    }

    /**
     * @notice Stop A ramping
     */
    function stopRampA() external onlyOwner {
        uint256 currentA = _getA();
        A = currentA;
        futureA = currentA;
        initialATime = block.timestamp;
        futureATime = block.timestamp;

        emit StopRampA(currentA, block.timestamp);
    }

    /**
     * @notice Set swap fee
     */
    function setSwapFee(uint256 _swapFee) external onlyOwner {
        require(_swapFee <= MAX_FEE, "StableSwap: swap fee too high");
        swapFee = _swapFee;
    }

    /**
     * @notice Set admin fee
     */
    function setAdminFee(uint256 _adminFee) external onlyOwner {
        require(_adminFee <= 10 ** 10, "StableSwap: admin fee too high");
        adminFee = _adminFee;
    }

    /**
     * @notice Set withdrawal fee
     */
    function setWithdrawFee(uint256 _withdrawFee) external onlyOwner {
        require(_withdrawFee <= 10 ** 10, "StableSwap: withdraw fee too high");
        withdrawFee = _withdrawFee;
    }

    /**
     * @notice Set admin address
     */
    function setAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "StableSwap: invalid admin");
        admin = _admin;
    }

    /**
     * @notice Pause all operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause all operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
