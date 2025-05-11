import { ethers, run } from "hardhat";

async function main() {
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  
  try {
    // 1. Deploy StudyAchievements contract
    console.log("\n1. Deploying StudyAchievements...");
    const StudyAchievements = await ethers.getContractFactory("StudyAchievements");
    
    // Set your NFT metadata base URI (empty for now)
    const baseURI = "";
    
    // Deploy the contract with the base URI
    const studyAchievements = await StudyAchievements.deploy(baseURI);
    const deploymentTx = studyAchievements.deploymentTransaction();
    if (deploymentTx) {
      await deploymentTx.wait();  // Wait for the deployment transaction to complete
    } else {
      throw new Error("Deployment transaction is null.");
    }
    
    const studyAchievementsAddress = await studyAchievements.getAddress();
    console.log("✅ StudyAchievements deployed to:", studyAchievementsAddress);
    
    // 2. Deploy SimbiToken contract
    console.log("\n2. Deploying SimbiToken...");
    const SimbiToken = await ethers.getContractFactory("SimbiToken");
    const simbiToken = await SimbiToken.deploy();
    const simbiDeploymentTx = simbiToken.deploymentTransaction();
    if (simbiDeploymentTx) {
      await simbiDeploymentTx.wait();
    } else {
      throw new Error("SimbiToken deployment transaction is null.");
    }
    
    const simbiTokenAddress = await simbiToken.getAddress();
    console.log("✅ SimbiToken deployed to:", simbiTokenAddress);
    
    // 3. Verify contracts (optional)
    console.log("\n3. Waiting 30 seconds before verification...");
    await new Promise(resolve => setTimeout(resolve, 30000));
    
    try {
      console.log("\nVerifying StudyAchievements...");
      await run("verify:verify", {
        address: studyAchievementsAddress,
        constructorArguments: [baseURI],
      });
      
      console.log("\nVerifying SimbiToken...");
      // FIX: Remove constructor arguments or explicitly set to empty array
      await run("verify:verify", {
        address: simbiTokenAddress,
        // Option 1: Remove the constructorArguments property entirely
        // Option 2: Explicitly set to empty array
        constructorArguments: [],
      });
      
      console.log("✅ Verification successful!");
    } catch (error) {
      console.log("⚠️ Verification failed:", error instanceof Error ? error.message : error);
    }
    
    // 4. Print summary
    console.log("\n4. Deployment complete!");
    console.log(`
    StudyAchievements: ${studyAchievementsAddress}
    SimbiToken: ${simbiTokenAddress}
    ${baseURI ? `Base URI: ${baseURI}` : ''}
    
    Next steps:
    1. Fund the contract with ETH if needed
    2. Grant MINTER_ROLE to authorized addresses
    3. Call mintAchievementNFT() to create NFTs
    `);
  } catch (error) {
    console.error("Deployment failed:", error);
  }
}

main().catch((error) => {
  console.error("Deployment failed:", error);
  process.exitCode = 1;
});