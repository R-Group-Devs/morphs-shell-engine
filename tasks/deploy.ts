import { task } from "hardhat/config";

task("deploy", "Deploy a contract")
  .addParam<string>("contract", "Contract to deploy")
  .setAction(async ({ contract }, { ethers, run, network }) => {
    console.log("compiling all contracts ...");
    await run("compile");

    const ContractFactory: any = await ethers.getContractFactory(contract);

    console.log(`Deploying ${contract} ...`);
    const deployed = await ContractFactory.deploy();
    await deployed.deployed();
    const address = deployed.address;

    console.log("\n\n---");
    console.log(`🐚 ${contract}: ${address}`);
    console.log("---\n\n");

    if (network.name !== "localhost" && network.name !== "hardhat") {
      console.log("waiting 60 seconds before attempting to verify ...");
      await new Promise((resolve) => setTimeout(resolve, 60 * 1000));

      console.log("verifying...");
      try {
        await run("verify:verify", {
          address: deployed.address,
          constructorArguments: [],
        });
      } catch (err) {
        console.warn("Verfication error:", err);
      }
    }

    return address;
  });
