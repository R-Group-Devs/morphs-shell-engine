// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*

            ███╗   ███╗ ██████╗ ██████╗ ██████╗ ██╗  ██╗███████╗
            ████╗ ████║██╔═══██╗██╔══██╗██╔══██╗██║  ██║██╔════╝
            ██╔████╔██║██║   ██║██████╔╝██████╔╝███████║███████╗
            ██║╚██╔╝██║██║   ██║██╔══██╗██╔═══╝ ██╔══██║╚════██║
            ██║ ╚═╝ ██║╚██████╔╝██║  ██║██║     ██║  ██║███████║
            ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝

                           https://morphs.wtf

    Drifting through the immateria you find a scroll. You sense something
    mysterious, cosmic.

    You feel compelled to take it. After all, what have you got to lose...

    Designed by @polyforms_

    Dreamt up and built at Playgrounds <https://playgrounds.wtf>

    Powered by shell <https://heyshell.xyz>

*/

import "@r-group/shell-contracts/contracts/engines/ShellBaseEngine.sol";
import "@r-group/shell-contracts/contracts/engines/OnChainMetadataEngine.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MorphsEngine is ShellBaseEngine, OnChainMetadataEngine {
    /// @notice Attempted mint after minting period has ended
    error MintingPeriodHasEnded();

    /// @notice Attempted cutover for a collection that already switched, or
    /// from incorrect msg sender
    error InvalidCutover();

    /// @notice Can't mint after March 1st midnight CST
    uint256 public constant MINTING_ENDS_AT_TIMESTAMP = 1646114400;

    /// @notice Displayed on heyshell.xyz
    function name() external pure returns (string memory) {
        return "morphs-v2";
    }

    /// @notice Mint a morph!
    /// @param flag Permenantly written into the NFT. Cannot be modified after mint
    function mint(IShellFramework collection, uint256 flag)
        external
        returns (uint256)
    {
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp >= MINTING_ENDS_AT_TIMESTAMP) {
            revert MintingPeriodHasEnded();
        }

        IntStorage[] memory intData;

        // flag is written to token mint data if set
        if (flag != 0) {
            intData = new IntStorage[](1);
            intData[0] = IntStorage({key: "flag", value: flag});
        } else {
            intData = new IntStorage[](0);
        }

        uint256 tokenId = collection.mint(
            MintEntry({
                to: msg.sender,
                amount: 1,
                options: MintOptions({
                    storeEngine: false,
                    storeMintedTo: false,
                    storeTimestamp: false,
                    storeBlockNumber: false,
                    stringData: new StringStorage[](0),
                    intData: intData
                })
            })
        );

        return tokenId;
    }

    /// @notice Mint several Morphs in a single transaction (flag=0 for all)
    function batchMint(IShellFramework collection, uint256 count) external {
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp >= MINTING_ENDS_AT_TIMESTAMP) {
            revert MintingPeriodHasEnded();
        }

        StringStorage[] memory stringData = new StringStorage[](0);
        IntStorage[] memory intData = new IntStorage[](0);

        for (uint256 i = 0; i < count; i++) {
            collection.mint(MintEntry({
                to: msg.sender,
                amount: 1,
                options: MintOptions({
                    storeEngine: false,
                    storeMintedTo: false,
                    storeTimestamp: false,
                    storeBlockNumber: false,
                    stringData: stringData,
                    intData: intData
                })
            }));
        }
    }

    function cutover(IShellFramework collection) external {
        if (collection.readForkInt(StorageLocation.ENGINE, 0, "cutover") != 0) {
            revert InvalidCutover();
        }
        if (msg.sender != collection.getForkOwner(0)) {
            revert InvalidCutover();
        }

        // solhint-disable-next-line not-rely-on-time
        collection.writeForkInt(StorageLocation.ENGINE, 0, "cutover", collection.nextTokenId());
    }

    /// @notice Gets the flag value written at mint time for a specific NFT
    function getFlag(IShellFramework collection, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return
            collection.readTokenInt(StorageLocation.MINT_DATA, tokenId, "flag");
    }

    /// @notice Returns true if this token was minted after the engine cutover
    function isCutoverToken(IShellFramework collection, uint256 tokenId)
        public
        view
        returns (bool)
    {
        uint256 transitionTokenId = collection.readForkInt(
            StorageLocation.ENGINE,
            0,
            "cutover"
        );

        return transitionTokenId != 0 && tokenId >= transitionTokenId;
    }

    /// @notice Get the palette index for a specific token
    function getPaletteIndex(IShellFramework collection, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        if (isCutoverToken(collection, tokenId)) {
            // TODO: keccak and mod based on number of new palettes
            return 6;
        }

        // OG logic
        return uint256(keccak256(abi.encodePacked(tokenId))) % 6;
    }

    /// @notice Get the name of a palette by index
    function getPaletteName(uint256 index) public pure returns (string memory) {
        if (index == 0) {
            return "Greyskull";
        } else if (index == 1) {
            return "Ancient Opinions";
        } else if (index == 2) {
            return "The Desert Sun";
        } else if (index == 3) {
            return "The Deep";
        } else if (index == 4) {
            return "The Jade Prism";
        } else if (index == 5) {
            return "Cosmic Understanding";
        } else if (index == 6) {
            return "Palette 7";
        }

        return "";
    }

    function _computeName(IShellFramework collection, uint256 tokenId)
        internal
        view
        override
        returns (string memory)
    {
        uint256 flag = getFlag(collection, tokenId);

        return
            string(
                abi.encodePacked(
                    "Morph #",
                    Strings.toString(tokenId),
                    flag > 2 ? ": Celestial Scroll of " : flag == 2
                        ? ": Cosmic Scroll of "
                        : flag == 1
                        ? ": Mythical Scroll of "
                        : ": Scroll of ",
                    getPaletteName(getPaletteIndex(collection, tokenId))
                )
            );
    }

    function _computeDescription(IShellFramework collection, uint256 tokenId)
        internal
        view
        override
        returns (string memory)
    {
        uint256 flag = getFlag(collection, tokenId);

        return
            string(
                abi.encodePacked(
                    flag > 2
                        ? "A mysterious scroll... you feel it pulsating with celestial energy. It appears to be imbued with a unique signature."
                        : flag == 2
                        ? "A mysterious scroll... you feel it pulsating with cosmic energy. Its whispers speak secrets of cosmic significance."
                        : flag == 1
                        ? "A mysterious scroll... you feel it pulsating with mythical energy. You sense its power is great."
                        : "A mysterious scroll... you feel it pulsating with energy. What secrets might it hold?",
                    flag > 2
                        ? string(
                            abi.encodePacked(
                                "\\n\\nEternal celestial signature: ",
                                Strings.toString(flag)
                            )
                        )
                        : "",
                    "\\n\\nhttps://playgrounds.wtf"
                )
            );
    }

    // compute the metadata image field for a given token
    function _computeImageUri(IShellFramework collection, uint256 tokenId)
        internal
        view
        override
        returns (string memory)
    {
        uint256 flag = getFlag(collection, tokenId);

        // TODO: re-implement image path generation
        string memory image = Strings.toString(flag);

        return
            string(
                abi.encodePacked(
                    "ipfs://ipfs/QmRCKXGuM47BzepjiHu2onshPFRWb7TMVEfd4K87cszg4w/",
                    image
                )
            );
    }

    // compute the external_url field for a given token
    function _computeExternalUrl(IShellFramework, uint256)
        internal
        pure
        override
        returns (string memory)
    {
        return "https://morphs.wtf";
    }

    function _computeAttributes(IShellFramework collection, uint256 tokenId)
        internal
        view
        override
        returns (Attribute[] memory)
    {
        uint256 palette = getPaletteIndex(collection, tokenId);

        Attribute[] memory attributes = new Attribute[](4);

        attributes[0] = Attribute({
            key: "Palette",
            value: getPaletteName(palette)
        });

        attributes[1] = Attribute({
            key: "Variation",
            // TODO: re-implement variation generation
            value: "???"
        });

        uint256 flag = getFlag(collection, tokenId);
        attributes[2] = Attribute({
            key: "Affinity",
            value: flag > 2 ? "Celestial":  flag == 2 ? "Cosmic" : flag == 1 ? "Mythical" : "Citizen"
        });

        attributes[3] = Attribute({
            key: "Era",
            value: isCutoverToken(collection, tokenId) ? "Genesis II" : "Genesis I"
        });


        return attributes;
    }
}
