const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("StableSwap", function () {
    async function deployStableSwapFixture() {
        const [owner, user1, user2, admin] = await ethers.getSigners();

        // Deploy mock tokens
        const MockDAI = await ethers.getContractFactory("MockDAI");
        const mockDAI = await MockDAI.deploy();
        await mockDAI.waitForDeployment();

        const MockUSDC = await ethers.getContractFactory("MockUSDC");
        const mockUSDC = await MockUSDC.deploy();
        await mockUSDC.waitForDeployment();

        const MockUSDT = await ethers.getContractFactory("MockUSDT");
        const mockUSDT = await MockUSDT.deploy();
        await mockUSDT.waitForDeployment();

        // Deploy LP Token
        const LPToken = await ethers.getContractFactory("LPToken");
        const lpToken = await LPToken.deploy("StableSwap LP Token", "SLP");
        await lpToken.waitForDeployment();

        // Deploy StableSwap
        const StableSwap = await ethers.getContractFactory("StableSwap");
        const coins = [mockDAI.target, mockUSDC.target, mockUSDT.target];
        const decimals = [18, 6, 6];
        const A = 100; // Amplification parameter
        const swapFee = 4000000; // 0.04%
        const adminFee = 5000000000; // 50% of swap fee

        const stableSwap = await StableSwap.deploy(
            coins,
            decimals,
            lpToken.target,
            A,
            swapFee,
            adminFee,
            admin.address
        );
        await stableSwap.waitForDeployment();

        return {
            owner,
            user1,
            user2,
            admin,
            mockDAI,
            mockUSDC,
            mockUSDT,
            lpToken,
            stableSwap,
            coins,
            decimals,
        };
    }

    describe("Deployment", function () {
        it("Should deploy with correct parameters", async function () {
            const { stableSwap, coins, mockDAI, mockUSDC, mockUSDT } = await loadFixture(
                deployStableSwapFixture
            );

            expect(await stableSwap.coins(0)).to.equal(mockDAI.target);
            expect(await stableSwap.coins(1)).to.equal(mockUSDC.target);
            expect(await stableSwap.coins(2)).to.equal(mockUSDT.target);
            expect(await stableSwap.getA()).to.equal(10000); // A * A_PRECISION
        });

        it("Should set LP token pool correctly", async function () {
            const { lpToken, stableSwap } = await loadFixture(deployStableSwapFixture);
            expect(await lpToken.pool()).to.equal(stableSwap.target);
        });
    });

    describe("Add Liquidity", function () {
        it("Should allow adding liquidity", async function () {
            const { stableSwap, mockDAI, mockUSDC, mockUSDT, lpToken, user1 } = await loadFixture(
                deployStableSwapFixture
            );

            const amounts = [
                ethers.parseUnits("1000", 18), // 1000 DAI
                ethers.parseUnits("1000", 6), // 1000 USDC
                ethers.parseUnits("1000", 6), // 1000 USDT
            ];

            // Approve tokens
            await mockDAI.connect(user1).approve(stableSwap.target, amounts[0]);
            await mockUSDC.connect(user1).approve(stableSwap.target, amounts[1]);
            await mockUSDT.connect(user1).approve(stableSwap.target, amounts[2]);

            // Add liquidity
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await stableSwap
                .connect(user1)
                .addLiquidity(amounts, 0, deadline);

            const lpBalance = await lpToken.balanceOf(user1.address);
            expect(lpBalance).to.be.gt(0);
        });

        it("Should revert if deadline exceeded", async function () {
            const { stableSwap, mockDAI, mockUSDC, mockUSDT, user1 } = await loadFixture(
                deployStableSwapFixture
            );

            const amounts = [
                ethers.parseUnits("1000", 18),
                ethers.parseUnits("1000", 6),
                ethers.parseUnits("1000", 6),
            ];

            await mockDAI.connect(user1).approve(stableSwap.target, amounts[0]);
            await mockUSDC.connect(user1).approve(stableSwap.target, amounts[1]);
            await mockUSDT.connect(user1).approve(stableSwap.target, amounts[2]);

            const deadline = Math.floor(Date.now() / 1000) - 1; // Past deadline

            await expect(
                stableSwap.connect(user1).addLiquidity(amounts, 0, deadline)
            ).to.be.revertedWith("StableSwap: deadline exceeded");
        });
    });

    describe("Remove Liquidity", function () {
        it("Should allow removing liquidity", async function () {
            const { stableSwap, mockDAI, mockUSDC, mockUSDT, lpToken, user1 } = await loadFixture(
                deployStableSwapFixture
            );

            // First add liquidity
            const amounts = [
                ethers.parseUnits("1000", 18),
                ethers.parseUnits("1000", 6),
                ethers.parseUnits("1000", 6),
            ];

            await mockDAI.connect(user1).approve(stableSwap.target, amounts[0]);
            await mockUSDC.connect(user1).approve(stableSwap.target, amounts[1]);
            await mockUSDT.connect(user1).approve(stableSwap.target, amounts[2]);

            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await stableSwap.connect(user1).addLiquidity(amounts, 0, deadline);

            const lpBalance = await lpToken.balanceOf(user1.address);
            const removeAmount = lpBalance / 2n;

            // Remove liquidity
            const minAmounts = [0, 0, 0];
            await stableSwap.connect(user1).removeLiquidity(removeAmount, minAmounts, deadline);

            const newLpBalance = await lpToken.balanceOf(user1.address);
            expect(newLpBalance).to.equal(lpBalance - removeAmount);
        });
    });

    describe("Exchange (Swap)", function () {
        it("Should allow swapping tokens", async function () {
            const { stableSwap, mockDAI, mockUSDC, mockUSDT, user1 } = await loadFixture(
                deployStableSwapFixture
            );

            // First add liquidity
            const amounts = [
                ethers.parseUnits("10000", 18),
                ethers.parseUnits("10000", 6),
                ethers.parseUnits("10000", 6),
            ];

            await mockDAI.connect(user1).approve(stableSwap.target, amounts[0]);
            await mockUSDC.connect(user1).approve(stableSwap.target, amounts[1]);
            await mockUSDT.connect(user1).approve(stableSwap.target, amounts[2]);

            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await stableSwap.connect(user1).addLiquidity(amounts, 0, deadline);

            // Perform swap: DAI -> USDC
            const swapAmount = ethers.parseUnits("100", 18);
            await mockDAI.connect(user1).approve(stableSwap.target, swapAmount);

            const balanceBefore = await mockUSDC.balanceOf(user1.address);
            await stableSwap.connect(user1).exchange(0, 1, swapAmount, 0, deadline);
            const balanceAfter = await mockUSDC.balanceOf(user1.address);

            expect(balanceAfter).to.be.gt(balanceBefore);
        });

        it("Should revert if output below minimum", async function () {
            const { stableSwap, mockDAI, mockUSDC, user1 } = await loadFixture(
                deployStableSwapFixture
            );

            // Add liquidity first
            const amounts = [
                ethers.parseUnits("10000", 18),
                ethers.parseUnits("10000", 6),
                ethers.parseUnits("10000", 6),
            ];

            await mockDAI.connect(user1).approve(stableSwap.target, amounts[0]);
            await mockUSDC.connect(user1).approve(stableSwap.target, amounts[1]);
            await mockUSDT.connect(user1).approve(stableSwap.target, amounts[2]);

            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await stableSwap.connect(user1).addLiquidity(amounts, 0, deadline);

            // Try swap with too high minimum
            const swapAmount = ethers.parseUnits("100", 18);
            await mockDAI.connect(user1).approve(stableSwap.target, swapAmount);

            await expect(
                stableSwap
                    .connect(user1)
                    .exchange(0, 1, swapAmount, ethers.parseUnits("1000000", 6), deadline)
            ).to.be.revertedWith("StableSwap: insufficient output");
        });
    });

    describe("Virtual Price", function () {
        it("Should return virtual price", async function () {
            const { stableSwap, mockDAI, mockUSDC, mockUSDT, user1 } = await loadFixture(
                deployStableSwapFixture
            );

            // Add liquidity
            const amounts = [
                ethers.parseUnits("1000", 18),
                ethers.parseUnits("1000", 6),
                ethers.parseUnits("1000", 6),
            ];

            await mockDAI.connect(user1).approve(stableSwap.target, amounts[0]);
            await mockUSDC.connect(user1).approve(stableSwap.target, amounts[1]);
            await mockUSDT.connect(user1).approve(stableSwap.target, amounts[2]);

            const deadline = Math.floor(Date.now() / 1000) + 3600;
            await stableSwap.connect(user1).addLiquidity(amounts, 0, deadline);

            const virtualPrice = await stableSwap.getVirtualPrice();
            expect(virtualPrice).to.be.gt(0);
        });
    });

    describe("Amplification Parameter", function () {
        it("Should allow ramping A", async function () {
            const { stableSwap, owner } = await loadFixture(deployStableSwapFixture);

            const futureA = 200;
            const futureTime = Math.floor(Date.now() / 1000) + 86400 * 7; // 7 days

            await stableSwap.connect(owner).rampA(futureA, futureTime);

            expect(await stableSwap.futureA()).to.equal(futureA * 100); // A_PRECISION
        });

        it("Should allow stopping A ramp", async function () {
            const { stableSwap, owner } = await loadFixture(deployStableSwapFixture);

            await stableSwap.connect(owner).stopRampA();

            const currentA = await stableSwap.getA();
            expect(await stableSwap.futureA()).to.equal(currentA);
        });
    });

    describe("Fees", function () {
        it("Should allow setting swap fee", async function () {
            const { stableSwap, owner } = await loadFixture(deployStableSwapFixture);

            const newFee = 5000000; // 0.05%
            await stableSwap.connect(owner).setSwapFee(newFee);

            expect(await stableSwap.swapFee()).to.equal(newFee);
        });

        it("Should revert if swap fee too high", async function () {
            const { stableSwap, owner } = await loadFixture(deployStableSwapFixture);

            const invalidFee = 11 * 1e6; // > 0.1%
            await expect(stableSwap.connect(owner).setSwapFee(invalidFee)).to.be.revertedWith(
                "StableSwap: swap fee too high"
            );
        });
    });

    describe("Pausability", function () {
        it("Should pause and unpause correctly", async function () {
            const { stableSwap, owner } = await loadFixture(deployStableSwapFixture);

            await stableSwap.connect(owner).pause();
            expect(await stableSwap.paused()).to.be.true;

            await stableSwap.connect(owner).unpause();
            expect(await stableSwap.paused()).to.be.false;
        });

        it("Should prevent operations when paused", async function () {
            const { stableSwap, mockDAI, mockUSDC, mockUSDT, owner, user1 } = await loadFixture(
                deployStableSwapFixture
            );

            await stableSwap.connect(owner).pause();

            const amounts = [
                ethers.parseUnits("1000", 18),
                ethers.parseUnits("1000", 6),
                ethers.parseUnits("1000", 6),
            ];

            await mockDAI.connect(user1).approve(stableSwap.target, amounts[0]);
            await mockUSDC.connect(user1).approve(stableSwap.target, amounts[1]);
            await mockUSDT.connect(user1).approve(stableSwap.target, amounts[2]);

            const deadline = Math.floor(Date.now() / 1000) + 3600;

            await expect(
                stableSwap.connect(user1).addLiquidity(amounts, 0, deadline)
            ).to.be.revertedWith("Pausable: paused");
        });
    });
});
