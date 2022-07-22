# 🍌 Banana Auction Machine

> (built with 🏗 scaffold-eth)

Welcome to the Banana Auction Machine - a BuidlGuidl and Juicebox collab

In the example project, a banana NFT is auctioned off each hour and proceeds go to the BuidlGuidl Juicebox. You can change the metadata and Juicebox project that receives proceeds to fund your ideas with automated NFT auctions. 

```sh
git clone https://github.com/austintgriffith/banana-auction
```
```sh
cd banana-auction
yarn install
yarn fork 
```

Note: The contract relies on JB Protocol and WETH, so it's much easier to fork than redeploy both on a local chain. Thus the `yarn fork` in lieu of `yarn chain` above. If `yarn fork` gives you trouble, try updating the mainnet infura API key in `hardhat.config.js`. Sometimes you have to run it a few times before it works.

> in a second terminal window, start your 📱 frontend:

```sh
cd banana-auction
yarn start
```

> in a third terminal window, 🛰 deploy your contract:

```sh
cd banana-auction
yarn deploy --reset
```

📱 Open http://localhost:3000 to see the app


## Verifying contract
`yarn verify --constructor-args constructorArguments.js <CONTRACT_ADDRESS>`