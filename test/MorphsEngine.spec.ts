import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { metadataFromTokenURI } from "./fixtures";
import {
  MockCollection,
  MockCollection__factory,
  MockFactory,
  MockFactory__factory,
  MorphsEngine,
} from "../typechain";

describe("Morphs", function () {
  // ---
  // fixtures
  // ---

  let MockFactory: MockFactory__factory;
  let MockCollection: MockCollection__factory;
  let accounts: SignerWithAddress[];
  let factory: MockFactory;
  let erc721: MockCollection;
  let testEngine: MorphsEngine;
  let a0: string, a1: string, a2: string, a3: string;

  beforeEach(async () => {
    MockFactory = await ethers.getContractFactory("MockFactory");
    MockCollection = await ethers.getContractFactory("MockCollection");
    const MorphsEngine = await ethers.getContractFactory("MorphsEngine");
    [factory, erc721, testEngine, accounts] = await Promise.all([
      MockFactory.deploy(),
      MockCollection.deploy(),
      MorphsEngine.deploy(),
      ethers.getSigners(),
    ]);
    [a0, a1, a2, a3] = accounts.map((a) => a.address);
    await factory.registerImplementation("erc721", erc721.address);
  });

  const createCollection = async (
    name = "Test",
    symbol = "TEST",
    engine = testEngine.address,
    owner = a0
  ): Promise<MockCollection> => {
    const trx = await factory.createCollection(
      name,
      symbol,
      "erc721",
      engine,
      owner
    );
    const mined = await trx.wait();
    const address = mined.events?.[1].args?.collection;
    const collection = MockCollection.attach(address);
    return collection;
  };

  describe("MorphsEngine", () => {
    it("should return correct name", async () => {
      const resp = await testEngine.name();
      expect(resp).to.eq("morphs");
    });
    it("should mint with no flag", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "0");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(metadata.name).to.match(/^Morph #1: Scroll of/);
      expect(metadata.description).to.match(/What secrets might it hold/);
    });
    it("should mint with flag = 1", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "1");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(metadata.name).to.match(/^Morph #1: Mythical Scroll of/);
      expect(metadata.description).to.match(/mythical energy/);
    });
    it("should mint with flag = 2", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "2");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(metadata.name).to.match(/^Morph #1: Cosmic Scroll of/);
      expect(metadata.description).to.match(/cosmic energy/);
    });
    it("should have no issues minting first 100", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "0");
      let count = 0;
      while (++count < 100) {
        await testEngine.mint(collection.address, "1");
        const metadata = metadataFromTokenURI(
          await collection.tokenURI(`${count}`)
        );
        expect(metadata.name).to.match(new RegExp(`Morph #${count}`));
      }
    });
    it("should expose minting end timestamp", async () => {
      expect(await testEngine.MINTING_ENDS_AT_TIMESTAMP()).to.eq(1646114400);
    });
    it("should not allow minting after 3/1", async () => {
      // TODO
    });
    it("should have variation in attributes", async () => {
      // TODO
    });
    it("should have palette in attributes", async () => {
      // TODO
    });
    it("should have affinity in attributes", async () => {
      // TODO
    });
  });
});
