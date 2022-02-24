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
    error MintingPeriodHasEnded();

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
        uint256 cutover = collection.readForkInt(
            StorageLocation.ENGINE,
            0,
            "cutover"
        );

        return cutover != 0 && tokenId >= cutover;
    }

    /// @notice Get the palette index for a specific token
    function getPaletteIndex(IShellFramework collection, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        if (isCutoverToken(collection, tokenId)) {
            return uint256(keccak256(abi.encodePacked(tokenId))) % 6;
        }

        // TODO: keccak and mod based on number of new palettes
        return 6;
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

    // function getPalette(uint256 tokenId) public pure returns (string memory) {
    //     uint256 index = uint256(keccak256(abi.encodePacked(tokenId))) % 6;
    //     return string(abi.encodePacked("P00", Strings.toString(index + 1)));
    // }

    // function getVariation(uint256 tokenId, uint256 flag)
    //     public
    //     pure
    //     returns (string memory)
    // {
    //     if (flag >= 2) {
    //         // celestial
    //         // doing >= 2 to let curious geeks mint things with custom flag
    //         // values.
    //         // I wonder if anybody will do this? 🤔
    //         return "X001";
    //     } else if (flag == 1) {
    //         // mythical
    //         uint256 i = uint256(keccak256(abi.encodePacked(tokenId))) % 4;
    //         return string(abi.encodePacked("M00", Strings.toString(i + 1)));
    //     }

    //     // citizen
    //     uint256 index = uint256(keccak256(abi.encodePacked(tokenId))) % 10;

    //     if (index == 9) {
    //         return "C010"; // double digit case
    //     } else {
    //         return string(abi.encodePacked("C00", Strings.toString(index + 1)));
    //     }
    // }

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
                    getPaletteName(tokenId)
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

        Attribute[] memory attributes = new Attribute[](3);

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
        return attributes;
    }
}
