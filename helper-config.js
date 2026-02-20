const networkConfig = {
  1337: {
    name: "localhost",
    initialA: 100, // Amplification parameter
    swapFee: 4000000, // 0.04% in 1e10 units
    adminFee: 5000000000, // 50% of swap fee to admin (in 1e10 units)
    withdrawFee: 0, // No withdrawal fee
  },
  11155111: {
    name: "sepolia",
    initialA: 100,
    swapFee: 4000000,
    adminFee: 5000000000,
    withdrawFee: 0,
  },
};

const developmentChains = ["hardhat", "localhost"];

module.exports = {
  networkConfig,
  developmentChains,
};
