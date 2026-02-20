# EVM Stable Swap AMM

A complete Solidity-based stablecoin Automated Market Maker (AMM) smart contract inspired by Curve Finance's stableswap pools. This protocol enables efficient low-slippage swaps between stablecoins using a hybrid constant sum/product invariant.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Setup](#setup)
- [Deployment](#deployment)
- [Contact](#contact)

## ✨ Features

### Core Functionality

- **Multi-Token Pools**: Support for 2-4 token pools (default: 3 tokens - DAI, USDC, USDT)
- **Stableswap Invariant**: Hybrid constant sum/product formula for low slippage on stablecoin swaps
- **Liquidity Provision**: Add/remove liquidity with LP token minting/burning
- **Low-Slippage Swaps**: Efficient token exchanges with minimal price impact
- **Dynamic Fees**: Configurable swap fees and admin fees
- **Amplification Parameter**: Adjustable A parameter with time-based ramping
- **Virtual Price**: LP token price calculation for impermanent loss monitoring
- **Single-Token Withdrawal**: Remove liquidity in a single token (with fees)

### Technical Features

- **High Precision Math**: 1e18 precision for calculations
- **Newton's Method**: Iterative solving of invariant for swaps
- **Access Control**: Owner-only functions for parameter updates
- **Pausability**: Emergency pause functionality
- **Reentrancy Protection**: Guards on all external calls
- **Deadline Protection**: Front-running prevention via transaction deadlines

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Users / Liquidity Providers               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    StableSwap Contract                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Core Functions:                                    │    │
│  │  - addLiquidity()                                   │    │
│  │  - removeLiquidity()                                │    │
│  │  - exchange()                                       │    │
│  │  - getVirtualPrice()                                 │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  StableSwapMath Library:                            │    │
│  │  - getD() (invariant calculation)                   │    │
│  │  - getY() (output amount calculation)               │    │
│  │  - Newton's method for solving                       │    │
│  └─────────────────────────────────────────────────────┘    │
└──────┬──────────────┬──────────────┬────────────────────────┘
       │              │              │
       ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  LPToken     │ │  ERC20 Tokens│ │  Admin       │
│  (ERC-20)    │ │  (DAI/USDC/  │ │  Controls    │
│              │ │   USDT)      │ │              │
└──────────────┘ └──────────────┘ └──────────────┘
```

### Contract Components

1. **StableSwap**: Main pool contract managing liquidity and swaps
2. **LPToken**: ERC-20 token representing liquidity provider shares
3. **StableSwapMath**: Library for stableswap invariant calculations
4. **Mock Tokens**: MockDAI, MockUSDC, MockUSDT for testing

### Stableswap Invariant

The protocol uses Curve Finance's stableswap invariant formula:

```
D = A * sum(x_i) + product(x_i) ^ (n / (n * A + sum(x_i)))
```

Where:
- `D` = Invariant (total value in pool)
- `A` = Amplification parameter (adjusts curve shape)
- `x_i` = Balance of token i
- `n` = Number of tokens in pool

This creates a hybrid curve that:
- Acts like constant sum (low slippage) when pools are balanced
- Acts like constant product (higher slippage) when pools are imbalanced

## 📁 Project Structure

```
evm-stable-swap-amm/
├── contracts/
│   ├── interfaces/
│   │   └── IStableSwap.sol
│   ├── libraries/
│   │   └── StableSwapMath.sol
│   ├── tokens/
│   │   └── LPToken.sol
│   ├── StableSwap.sol
│   └── mocks/
│       ├── MockERC20.sol
│       ├── MockDAI.sol
│       ├── MockUSDC.sol
│       └── MockUSDT.sol
├── scripts/
│   └── deploy.js
├── test/
│   └── StableSwap.test.js
├── hardhat.config.js
├── helper-config.js
├── package.json
└── README.md
```

## 🚀 Setup

### Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- Git

### Installation

1. Navigate to the project directory:
```bash
cd evm-stable-swap-amm-smart-contract-1/evm-stable-swap-amm
```

2. Install dependencies:
```bash
npm install
# or
yarn install
```

3. Create a `.env` file (optional, for testnet deployment):
```bash
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

4. Compile the contracts:
```bash
npx hardhat compile
```

## 🚢 Deployment

### Local Network

1. Start a local Hardhat node:
```bash
npx hardhat node
```

2. In another terminal, deploy to localhost:
```bash
npx hardhat run scripts/deploy.js --network localhost
```

### Testnet Deployment (Sepolia)

1. Ensure your `.env` file is configured with:
   - `PRIVATE_KEY`: Your wallet private key
   - `SEPOLIA_RPC_URL`: Sepolia RPC endpoint
   - `ETHERSCAN_API_KEY`: Etherscan API key (for verification)

2. Deploy to Sepolia:
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

3. Verify contracts (optional):
```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## 📧 Contact

- Telegram: https://t.me/rouncey
- Twitter: https://x.com/rouncey_
