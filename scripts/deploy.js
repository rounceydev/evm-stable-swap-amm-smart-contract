const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

    // Deploy Mock Tokens
    console.log("\n=== Deploying Mock Tokens ===");
    const MockDAI = await ethers.getContractFactory("MockDAI");
    const mockDAI = await MockDAI.deploy();
    await mockDAI.waitForDeployment();
    console.log("MockDAI deployed to:", mockDAI.target);

    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    const mockUSDC = await MockUSDC.deploy();
    await mockUSDC.waitForDeployment();
    console.log("MockUSDC deployed to:", mockUSDC.target);

    const MockUSDT = await ethers.getContractFactory("MockUSDT");
    const mockUSDT = await MockUSDT.deploy();
    await mockUSDT.waitForDeployment();
    console.log("MockUSDT deployed to:", mockUSDT.target);

    // Deploy LP Token
    console.log("\n=== Deploying LP Token ===");
    const LPToken = await ethers.getContractFactory("LPToken");
    const lpToken = await LPToken.deploy("StableSwap LP Token", "SLP");
    await lpToken.waitForDeployment();
    console.log("LPToken deployed to:", lpToken.target);

    // Deploy StableSwap
    console.log("\n=== Deploying StableSwap ===");
    const StableSwap = await ethers.getContractFactory("StableSwap");
    const coins = [mockDAI.target, mockUSDC.target, mockUSDT.target];
    const decimals = [18, 6, 6];
    const A = 100; // Amplification parameter
    const swapFee = 4000000; // 0.04% in 1e10 units
    const adminFee = 5000000000; // 50% of swap fee to admin

    const stableSwap = await StableSwap.deploy(
        coins,
        decimals,
        lpToken.target,
        A,
        swapFee,
        adminFee,
        deployer.address // admin
    );
    await stableSwap.waitForDeployment();
    console.log("StableSwap deployed to:", stableSwap.target);

    console.log("\n=== Deployment Summary ===");
    console.log("Mock Tokens:");
    console.log("  DAI:", mockDAI.target);
    console.log("  USDC:", mockUSDC.target);
    console.log("  USDT:", mockUSDT.target);
    console.log("\nLP Token:", lpToken.target);
    console.log("StableSwap Pool:", stableSwap.target);
    console.log("\nPool Parameters:");
    console.log("  Amplification (A):", A);
    console.log("  Swap Fee: 0.04%");
    console.log("  Admin Fee: 50% of swap fee");

    console.log("\n=== Next Steps ===");
    console.log("1. Add liquidity: stableSwap.addLiquidity([amounts], minMintAmount, deadline)");
    console.log("2. Swap tokens: stableSwap.exchange(i, j, dx, minDy, deadline)");
    console.log("3. Remove liquidity: stableSwap.removeLiquidity(amount, minAmounts, deadline)");
    console.log("4. Check virtual price: stableSwap.getVirtualPrice()");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
