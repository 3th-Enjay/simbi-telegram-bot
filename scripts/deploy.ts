import { ethers, run } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contract with address:", deployer.address);

  const SimbiToken = await ethers.getContractFactory("SimbiToken");
  const simbiToken = await SimbiToken.deploy();

  const deploymentTx = simbiToken.deploymentTransaction();
  if (!deploymentTx) throw new Error("Deployment transaction is null");

  const receipt = await deploymentTx.wait();
  if (!receipt) throw new Error("Deployment receipt is null");

  const contractAddress = receipt.contractAddress;
  console.log("SimbiToken deployed to:", contractAddress);

  // Optional delay to ensure the contract is fully indexed on Etherscan
  console.log("Waiting 1 minute before verification...");
  await new Promise((resolve) => setTimeout(resolve, 60000));

  try {
    console.log("Verifying contract...");
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: [],
    });
    console.log("Contract verified successfully!");
  } catch (err: any) {
    console.error("Verification failed:", err.message || err);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
// This script deploys the StudyToken contract to the Sepolia test network and verifies it on Etherscan.
// It uses Hardhat's built-in functionalities to handle deployment and verification.