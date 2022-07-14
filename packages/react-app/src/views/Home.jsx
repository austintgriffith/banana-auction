import { useContractReader, useContractLoader } from "eth-hooks";
import { useEventListener } from "eth-hooks/events/useEventListener";
import { ethers } from "ethers";

import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";

import { Account, Address, AddressInput, Contract, Faucet, GasGauge, Header, Ramp, ThemeSwitch } from "../components";

import { Button, Col, Menu, Row, Input, List, Card } from "antd";

import { create } from "ipfs-http-client";
import { BufferList } from "bl";

const ipfs = create({ host: "ipfs.infura.io", port: "5001", protocol: "https" });

//const { BufferList } = require("bl");
//const ipfsAPI = require("ipfs-http-client");
//const ipfs = ipfsAPI({ host: "ipfs.infura.io", port: "5001", protocol: "https" });

/**
 * web3 props can be passed from '../App.jsx' into your local view component for use
 * @param {*} yourLocalBalance balance on current network
 * @param {*} readContracts contracts from current chain already pre-loaded using ethers contract module. More here https://docs.ethers.io/v5/api/contract/contract/
 * @returns react component
 **/
function Home({
  localChainId,
  contractConfig,
  userSigner,
  yourLocalBalance,
  readContracts,
  address,
  localProvider,
  mainnetProvider,
  tx,
  blockExplorer,
}) {
  const writeContracts = useContractLoader(userSigner, contractConfig, localChainId);

  // you can also use hooks locally in your component of choice
  // in this case, let's keep track of 'purpose' variable from our contract
  const purpose = useContractReader(readContracts, "YourContract", "purpose");

  console.log("++", address, "writeContracts", writeContracts);

  // keep track of a variable from the contract in the local React state:
  const balance = useContractReader(readContracts, "NFTAuctionMachine", "balanceOf", [address]);
  console.log("🤗 balance:", balance);

  const highestBid = useContractReader(readContracts, "NFTAuctionMachine", "highestBid");
  console.log("🤗 highestBid:", highestBid);

  const highestBidder = useContractReader(readContracts, "NFTAuctionMachine", "highestBidder");
  console.log("🤗 highestBidder:", highestBidder);

  const timeLeft = useContractReader(readContracts, "NFTAuctionMachine", "timeLeft");
  console.log("🤗 timeLeft:", timeLeft);

  // 📟 Listen for broadcast events
  const transferEvents = useEventListener(readContracts, "NFTAuctionMachine", "Transfer", localProvider, 1);
  console.log("📟 Transfer events:", transferEvents);

  const bidEvents = useEventListener(readContracts, "NFTAuctionMachine", "Bid", localProvider, 1);
  console.log("📟 Bid events:", bidEvents);

  // helper function to "Get" from IPFS
  // you usually go content.toString() after this...

  //
  // 🧠 This effect will update yourCollectibles by polling when your balance changes
  //
  const yourBalance = balance && balance.toNumber && balance.toNumber();
  const [yourCollectibles, setYourCollectibles] = useState();

  useEffect(() => {
    const updateYourCollectibles = async () => {
      const collectibleUpdate = [];
      for (let tokenIndex = 0; tokenIndex < balance; tokenIndex++) {
        try {
          console.log("GEtting token index", tokenIndex);
          const tokenId = await readContracts.NFTAuctionMachine.tokenOfOwnerByIndex(address, tokenIndex);
          console.log("tokenId", tokenId);
          const tokenURI = await readContracts.NFTAuctionMachine.tokenURI(tokenId);
          console.log("tokenURI", tokenURI);

          const ipfsHash = tokenURI.replace("https://ipfs.io/ipfs/", "");
          console.log("ipfsHash", ipfsHash);

          const jsonManifestBuffer = await getFromIPFS(ipfsHash);

          try {
            const jsonManifest = JSON.parse(jsonManifestBuffer.toString());
            console.log("jsonManifest", jsonManifest);
            collectibleUpdate.push({ id: tokenId, uri: jsonManifestBuffer.image, owner: address, ...jsonManifest });
          } catch (e) {
            console.log(e);
          }
        } catch (e) {
          console.log(e);
        }
      }
      setYourCollectibles(collectibleUpdate);
    };
    updateYourCollectibles();
  }, [address, yourBalance]);

  const [bidAmount, setBidAmount] = useState();
  const [bids, setBids] = useState();
  const [myNFTs, setMyNFTs] = useState();

  useEffect(() => {
    setMyNFTs(transferEvents.reverse().slice(0, 4));
  }, [transferEvents]);

  useEffect(() => {
    setBids(bidEvents.reverse().slice(0, 4));
  }, [bidEvents]);

  const getFromIPFS = async hashToGet => {
    for await (const file of ipfs.cat(hashToGet)) {
      const content = new BufferList(file).toString();

      return content;
    }
  };

  const [transferToAddresses, setTransferToAddresses] = useState({});

  return (
    <div>
      <div style={{ width: 640, margin: "auto", marginTop: 32, paddingBottom: 32 }}>
        <div style={{ padding: 16 }}>
          <img style={{ maxWidth: 256, padding: 32 }} src={"./banana.png"} />
          <div style={{ padding: 4 }}>Welcome to the Banana Auction Machine - a BuidlGuidl and Juicebox collab</div>
          <div style={{ padding: 4 }}>
            A banana NFT is auctioned off every 15 minutes and the proceeds are forwarded to the{" "}
            <a href="https://juicebox.money/#/v2/p/44" target="_blank">
              BuidlGuidl Juicebox
            </a>
            . <strong>The minimum bid is 0.001 ETH.</strong>
          </div>
          <div style={{ color: "#FF0000" }}>
            This contract is unaudited and yolo'd to mainnet. Please do not make large bids!
          </div>
        </div>
        <div style={{ padding: 16 }}>
          <div style={{ padding: 8, fontSize: 32 }}>
            Current Bid: Ξ{highestBid && ethers.utils.formatEther(highestBid)}
          </div>
          <div style={{ padding: 8 }}>
            <div style={{ padding: 2 }}>Highest Bidder:</div>
            <Address address={highestBidder} ensProvider={mainnetProvider} />
          </div>
          <div style={{ padding: 8 }}>Time Left: {timeLeft && timeLeft.toNumber()}s</div>
          {timeLeft && timeLeft.toNumber() > 0 ? (
            <div>
              <div style={{ padding: 8, width: 256, margin: "auto" }}>
                <Input
                  addonBefore={"Ξ"}
                  value={bidAmount}
                  onChange={e => {
                    setBidAmount(e.target.value);
                  }}
                />
              </div>

              <Button
                disabled={false}
                shape="round"
                size="large"
                onClick={() => {
                  console.log("writeContracts", writeContracts, "bidAmount", bidAmount);

                  tx(
                    writeContracts.NFTAuctionMachine.bid({
                      value: bidAmount && ethers.utils.parseEther("" + bidAmount),
                    }),
                  );
                  setBidAmount();
                }}
              >
                BID
              </Button>
            </div>
          ) : (
            <div>
              <Button
                disabled={false}
                shape="round"
                size="large"
                onClick={() => {
                  tx(writeContracts.NFTAuctionMachine.finalize());
                }}
              >
                FINALIZE
              </Button>
            </div>
          )}
        </div>
      </div>

      <div style={{ width: 640, margin: "auto", marginTop: 32, paddingBottom: 32 }}>
        <span>recent bids:</span>
        <List
          bordered
          dataSource={bids}
          renderItem={item => {
            return (
              <List.Item key={item.blockHash + "_"}>
                <Address address={item.args[0]} ensProvider={mainnetProvider} fontSize={16} />
                <br />
                Bid Ξ {item.args[1] && ethers.utils.formatEther(item.args[1])}
                <br />
              </List.Item>
            );
          }}
        />
      </div>

      <div style={{ width: 640, margin: "auto", marginTop: 32, paddingBottom: 32 }}>
        <span>your bananas:</span>
        <List
          bordered
          dataSource={myNFTs}
          renderItem={item => {
            console.log("a string");
            console.log(item);
            return (
              <div>
                <List.Item key={item.blockHash + "_"}>
                  TokenId {item.args[2].toString()}
                  <br />
                  Winner <Address address={item.args[1]} ensProvider={mainnetProvider} fontSize={16} /><br/>
                  <a
                    href={`https://opensea.io/assets/ethereum/${
                      writeContracts.NFTAuctionMachine.address
                    }/${item.args[2].toString()}`}
                  >
                    OpenSea
                  </a>
                </List.Item>
              </div>
            );
          }}
        />
      </div>
      <a style={{ paddingBottom: 64 }} href="/debug" target="_blank">
        debug contracts
      </a>
    </div>
  );
}

export default Home;
