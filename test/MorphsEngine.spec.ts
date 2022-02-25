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
      expect(resp).to.eq("morphs-v2");
    });
    it("should mint with no flag", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "0");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(metadata.name).to.match(/^Morph #1: Scroll of/);
      expect(metadata.description).to.match(/What secrets might it hold/);
      expect(
        metadata.attributes?.find((a) => a.trait_type === "Affinity")?.value
      ).to.equal("Citizen");
    });
    it("should mint with flag = 1", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "1");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(metadata.name).to.match(/^Morph #1: Mythical Scroll of/);
      expect(metadata.description).to.match(/mythical energy/);
      expect(
        metadata.attributes?.find((a) => a.trait_type === "Affinity")?.value
      ).to.equal("Mythical");
    });
    it("should mint with flag = 2", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "2");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(metadata.name).to.match(/^Morph #1: Cosmic Scroll of/);
      expect(metadata.description).to.match(/cosmic energy/);
      expect(
        metadata.attributes?.find((a) => a.trait_type === "Affinity")?.value
      ).to.equal("Cosmic");
    });
    it("should mint with flag > 2", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "3");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(metadata.name).to.match(/^Morph #1: Celestial Scroll of/);
      expect(metadata.description).to.match(/celestial energy/);
      expect(metadata.description).to.match(/Eternal celestial signature: 3/);
      expect(
        metadata.attributes?.find((a) => a.trait_type === "Affinity")?.value
      ).to.equal("Celestial");
    });
    it("should have no issues minting first 20", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "0");
      let count = 0;
      while (++count < 20) {
        await testEngine.mint(collection.address, "1");
        const metadata = metadataFromTokenURI(
          await collection.tokenURI(`${count}`)
        );
        expect(metadata.name).to.match(new RegExp(`Morph #${count}`));
      }
    });
    it("should allow batch minting", async () => {
      const collection = await createCollection();
      await testEngine.batchMint(collection.address, 20);
      expect(await collection.nextTokenId()).to.equal("21");
      expect(await collection.balanceOf(a0)).to.equal("20");
    });
    it("should return true from isTokenCutover once cutover submitted", async () => {
      const collection = await createCollection();
      await testEngine.batchMint(collection.address, 5);
      expect(await testEngine.isCutoverToken(collection.address, "1")).to.equal(
        false
      );
      expect(await testEngine.isCutoverToken(collection.address, "5")).to.equal(
        false
      );
      // cutover --
      await testEngine.cutover(collection.address);
      expect(await testEngine.isCutoverToken(collection.address, "1")).to.equal(
        false
      );
      expect(await testEngine.isCutoverToken(collection.address, "5")).to.equal(
        false
      );
      await testEngine.batchMint(collection.address, 5);
      expect(await testEngine.isCutoverToken(collection.address, "6")).to.equal(
        true
      );
      expect(
        await testEngine.isCutoverToken(collection.address, "10")
      ).to.equal(true);
    });
    it("should revert if non-owner to cutover", async () => {
      const collection = await createCollection();
      const _testEngine = testEngine.connect(accounts[1]);
      await expect(_testEngine.cutover(collection.address)).to.be.revertedWith(
        "InvalidCutover"
      );
    });
    it("should revert if cutover attempted if already done", async () => {
      const collection = await createCollection();
      await testEngine.cutover(collection.address);
      await expect(testEngine.cutover(collection.address)).to.be.revertedWith(
        "InvalidCutover"
      );
    });
    it("should expose minting end timestamp", async () => {
      expect(await testEngine.MINTING_ENDS_AT_TIMESTAMP()).to.eq(1646114400);
    });
    it("should not allow minting after 3/1", async () => {
      // TODO
    });
    it("should have palette in attributes", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "1");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(
        metadata.attributes?.find((a) => a.trait_type === "Palette")?.value
      ).to.equal("Greyskull");
    });
    it("should have custom flag in attributes", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "420");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(
        metadata.attributes?.find((a) => a.trait_type === "Signature")?.value
      ).to.equal("420");
    });
    it("should have group in attributes", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "420");
      await testEngine.mint(collection.address, "0");
      const metadata1 = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(
        metadata1.attributes?.find((a) => a.trait_type === "Group")?.value
      ).to.equal("Group 0");
      const metadata2 = metadataFromTokenURI(await collection.tokenURI("2"));
      expect(
        metadata2.attributes?.find((a) => a.trait_type === "Group")?.value
      ).to.equal("Group 1");
    });
    it("should have custom flag as (none) if 0", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "0");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(
        metadata.attributes?.find((a) => a.trait_type === "Signature")?.value
      ).to.equal("None");
    });
    it("should cutover era in attributes", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "0");
      const metadata1 = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(
        metadata1.attributes?.find((a) => a.trait_type === "Era")?.value
      ).to.equal("Genesis I");

      await testEngine.cutover(collection.address);
      await testEngine.mint(collection.address, "0");
      const metadata2 = metadataFromTokenURI(await collection.tokenURI("2"));
      expect(
        metadata2.attributes?.find((a) => a.trait_type === "Era")?.value
      ).to.equal("Genesis II");
    });
    it("should have custom flag in description", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "123456789");
      const metadata = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(metadata.description).to.match(
        /Eternal celestial signature: 123456789/
      );
    });
    it("should have era in the description", async () => {
      const collection = await createCollection();
      await testEngine.mint(collection.address, "0");
      const metadata1 = metadataFromTokenURI(await collection.tokenURI("1"));
      expect(metadata1.description).to.match(
        /This Morph was minted in the Genesis I era./
      );
      await testEngine.cutover(collection.address);
      await testEngine.mint(collection.address, "0");
      const metadata2 = metadataFromTokenURI(await collection.tokenURI("2"));
      expect(metadata2.description).to.match(
        /This Morph was minted in the Genesis II era./
      );
    });
  });
});
