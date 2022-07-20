// deploy/00_deploy_your_contract.js

const { ethers } = require("hardhat");
require("dotenv").config();

const localChainId = "31337";

// const sleep = (ms) =>
//   new Promise((r) =>
//     setTimeout(() => {
//       console.log(`waited for ${(ms / 1000).toFixed(3)} seconds`);
//       r();
//     }, ms)
//   );


module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // DEPLOY WETH (for local testing)
  // COMMENT THIS OUT WHEN DEPLOYING TO A NON-LOCAL CHAIN
  // let weth = await deploy("WETH9", {
  //   // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
  //   from: deployer,
  //   log: true,
  // });

  // MAINNET CONTRACT ADDRESSES
  // let weth = { address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" };
  // let jbDirectory = { address: "0xCc8f7a89d89c2AB3559f484E0C656423E979ac9C" };

  // RINEKBY CONTRACT ADDRESSES
  let weth = { address: "0xc778417E063141139Fce010982780140Aa0cD5Ab" };
  let jbDirectory = { address: "0x1A9b04A9617ba5C9b7EBfF9668C30F41db6fC21a" };

  let metadata = process.env.METADATA_URI;

  if (process.env.SINGLE_URI_METADATA === "true") {
    metadata = await deploy("SingleUriMetadata", {
      // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
      from: deployer,
      args: [metadata],
      log: true,
    });
  } else {
    metadata = await deploy("MultiUriMetadata", {
      // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
      from: deployer,
      args: [metadata],
      log: true,
    });
  }



  await deploy("NFTAuctionMachine", {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [
      "Banana Auction",
      "BANANA",
      25,
      44,
      metadata.address,
      weth.address,
      jbDirectory.address,
    ],
    log: true,
  });


  // Getting a previously deployed contract
  // const NFTAuctionMachine = await ethers.getContract("NFTAuctionMachine", deployer);
  /*  await YourContract.setPurpose("Hello");
  
    // To take ownership of yourContract using the ownable library uncomment next line and add the 
    // address you want to be the owner. 
    
    await YourContract.transferOwnership(
      "ADDRESS_HERE"
    );

    //const YourContract = await ethers.getContractAt('YourContract', "0xaAC799eC2d00C013f1F11c37E654e59B0429DF6A") //<-- if you want to instantiate a version of a contract at a specific address!
  */

  /*
  //If you want to send value to an address from the deployer
  const deployerWallet = ethers.provider.getSigner()
  await deployerWallet.sendTransaction({
    to: "0x34aA3F359A9D614239015126635CE7732c18fDF3",
    value: ethers.utils.parseEther("0.001")
  })
  */

  /*
  //If you want to send some ETH to a contract on deploy (make your constructor payable!)
  const yourContract = await deploy("YourContract", [], {
  value: ethers.utils.parseEther("0.05")
  });
  */

  /*
  //If you want to link a library into your contract:
  // reference: https://github.com/austintgriffith/scaffold-eth/blob/using-libraries-example/packages/hardhat/scripts/deploy.js#L19
  const yourContract = await deploy("YourContract", [], {}, {
   LibraryName: **LibraryAddress**
  });
  */

  // Verify from the command line by running `yarn verify`

  // You can also Verify your contracts with Etherscan here...
  // You don't want to verify on localhost
  // try {
  //   if (chainId !== localChainId) {
  //     await run("verify:verify", {
  //       address: YourContract.address,
  //       contract: "contracts/YourContract.sol:YourContract",
  //       constructorArguments: [],
  //     });
  //   }
  // } catch (error) {
  //   console.error(error);
  // }
};
module.exports.tags = ["NFTAuctionMachine"];
