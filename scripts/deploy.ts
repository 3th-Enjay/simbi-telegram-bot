import { ethers, run } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with address:", deployer.address);

  // Deploy StudyToken
  const StudyToken = await ethers.getContractFactory("StudyToken");
  const studyToken = await StudyToken.deploy();

  const tokenTx = studyToken.deploymentTransaction();
  if (!tokenTx) throw new Error("StudyToken deployment transaction is null");
  const tokenReceipt = await tokenTx.wait();
  if (!tokenReceipt || !tokenReceipt.contractAddress)
    throw new Error("StudyToken deployment failed");
  const studyTokenAddress = tokenReceipt.contractAddress;
  console.log("✅ StudyToken deployed to:", studyTokenAddress);

  // Deploy StudyAchievements
  const StudyAchievements = await ethers.getContractFactory("StudyAchievements");
  const studyAchievements = await StudyAchievements.deploy();

  const achievementsTx = studyAchievements.deploymentTransaction();
  if (!achievementsTx) throw new Error("StudyAchievements deployment transaction is null");
  const achievementsReceipt = await achievementsTx.wait();
  if (!achievementsReceipt || !achievementsReceipt.contractAddress)
    throw new Error("StudyAchievements deployment failed");
  const studyAchievementsAddress = achievementsReceipt.contractAddress;
  console.log("✅ StudyAchievements deployed to:", studyAchievementsAddress);

  // Optional delay before verification

  console.log("Waiting 1 minute before verification...");
  await new Promise((resolve) => setTimeout(resolve, 60000));

  // Verify StudyToken
  try {
    console.log("Verifying StudyToken...");
    await run("verify:verify", {
      address: studyTokenAddress,
      constructorArguments: [],
    });
    console.log("✅ StudyToken verified!");
  } catch (err: any) {
    console.error("❌ StudyToken verification failed:", err.message || err);
  }

  // Verify StudyAchievements
  try {
    console.log("Verifying StudyAchievements...");
    await run("verify:verify", {
      address: studyAchievementsAddress,
      constructorArguments: [],
    });
    console.log("✅ StudyAchievements verified!");
  } catch (err: any) {
    console.error("❌ StudyAchievements verification failed:", err.message || err);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
