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
            collection.mint(
                MintEntry({
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
                })
            );
        }
    }

    /// @notice start using the new token rolling logic, can only be called once
    /// and by the root fork owner of the collection
    function cutover(IShellFramework collection) external {
        if (collection.readForkInt(StorageLocation.ENGINE, 0, "cutover") != 0) {
            revert InvalidCutover();
        }
        if (msg.sender != collection.getForkOwner(0)) {
            revert InvalidCutover();
        }

        collection.writeForkInt(
            StorageLocation.ENGINE,
            0,
            "cutover",
            collection.nextTokenId()
        );
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

    /// @notice Get the palette index (1-based) for a specific token
    function getPaletteIndex(IShellFramework collection, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        // new logic, select palette 7-24
        if (isCutoverToken(collection, tokenId)) {
            return selectInRange(tokenId, 7, 24);
        }

        // OG logic - only selects palette 1-6
        return selectInRange(tokenId, 1, 6);
    }

    /// @notice Get the edition index (0-based) for a specific token
    function getEditionIndex(IShellFramework collection, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        uint256 flag = getFlag(collection, tokenId);
        bool isCutover = isCutoverToken(collection, tokenId);

        // celestial = always use 0th edition
        if (flag > 2) {
            return 0;
        }

        // OG tokens always = edition 1
        if (!isCutover) {
            return 1;
        }

        // else, edition is strictly a function of the palette
        // palette will be 7-24 since this is a post-cutover token
        uint256 palette = getPaletteIndex(collection, tokenId);

        if (palette < 13) {
            return 2;
        }
        if (palette < 19) {
            return 3;
        }

        return 4;
    }

    /// @notice Get the variation for a specific token
    function getVariation(IShellFramework collection, uint256 tokenId)
        public
        view
        returns (string memory)
    {
        bool isCutover = isCutoverToken(collection, tokenId);
        uint256 flag = getFlag(collection, tokenId);

        // all celestials (old and new) roll a variation based on flag value
        if (flag > 2) {
            // 5 celestials, Z1-Z5
            return
                string.concat("Z", Strings.toString(selectInRange(flag, 1, 5)));
        }

        // OG logic
        if (!isCutover) {
            if (flag == 2) {
                // Only 1 OG cosmic
                return "X1";
            } else if (flag == 1) {
                // 4 OG mythicals, M1-M4
                return
                    string.concat(
                        "M",
                        Strings.toString(selectInRange(tokenId, 1, 4))
                    );
            }

            // 10 OG citizen, C1-C10
            return
                string.concat(
                    "C",
                    Strings.toString(selectInRange(tokenId, 1, 10))
                );
        }

        // post-cutover logic
        if (flag == 2) {
            // 4 new cosmic, X2-5
            return
                string.concat(
                    "X",
                    Strings.toString(selectInRange(tokenId, 2, 5))
                );
        } else if (flag == 1) {
            // 11 new mythicals, M5-15
            return
                string.concat(
                    "M",
                    Strings.toString(selectInRange(tokenId, 5, 15))
                );
        }

        // 15 new citizens, C11-25
        return
            string.concat(
                "C",
                Strings.toString(selectInRange(tokenId, 11, 25))
            );
    }

    function selectInRange(
        uint256 seed,
        uint256 lower,
        uint256 upper
    ) private pure returns (uint256) {
        uint256 i = uint256(keccak256(abi.encodePacked(seed))) %
            (upper - lower + 1);
        return lower + i;
    }

    /// @notice Get the name of a palette by index
    function getPaletteName(uint256 index) public pure returns (string memory) {
        if (index == 1) {
            return "Greyskull";
        } else if (index == 2) {
            return "Ancient Opinions";
        } else if (index == 3) {
            return "The Desert Sun";
        } else if (index == 4) {
            return "The Deep";
        } else if (index == 5) {
            return "The Jade Prism";
        } else if (index == 6) {
            return "Cosmic Understanding";
        } else if (index == 7) {
            return "Ancient Grudges";
        } else if (index == 8) {
            return "Radiant Beginnings";
        } else if (index == 9) {
            return "Desert Sand";
        } else if (index == 10) {
            return "Arcane Slate";
        } else if (index == 11) {
            return "The Vibrant Forest";
        } else if (index == 12) {
            return "Evening Star";
        } else if (index == 13) {
            return "Dawn";
        } else if (index == 14) {
            return "Calm Air";
        } else if (index == 15) {
            return "Solarion";
        } else if (index == 16) {
            return "Morning Sun";
        } else if (index == 17) {
            return "Emerald";
        } else if (index == 18) {
            return "Stellaris";
        } else if (index == 19) {
            return "Future Island";
        } else if (index == 20) {
            return "Scorched Emerald";
        } else if (index == 21) {
            return "Stone";
        } else if (index == 22) {
            return "The Night Sky";
        } else if (index == 23) {
            return "The Beacon";
        } else if (index == 24) {
            return "Blackskull";
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
            string.concat(
                flag > 2
                    ? "A mysterious scroll... you feel it pulsating with celestial energy. Its presence bridges the gap between old and new."
                    : flag == 2
                    ? "A mysterious scroll... you feel it pulsating with cosmic energy. Its whispers speak secrets of cosmic significance."
                    : flag == 1
                    ? "A mysterious scroll... you feel it pulsating with mythical energy. You sense its power is great."
                    : "A mysterious scroll... you feel it pulsating with energy. What secrets might it hold?",
                flag > 2
                    ? string.concat(
                        "\\n\\nEternal celestial signature: ",
                        Strings.toString(flag)
                    )
                    : "",
                isCutoverToken(collection, tokenId)
                    ? "\\n\\nThis Morph was minted in the Genesis II era."
                    : "\\n\\nThis Morph was minted in the Genesis I era.",
                "\\n\\nhttps://playgrounds.wtf"
            );
    }

    // compute the metadata image field for a given token
    function _computeImageUri(IShellFramework collection, uint256 tokenId)
        internal
        view
        override
        returns (string memory)
    {
        uint256 edition = getEditionIndex(collection, tokenId);
        uint256 palette = getPaletteIndex(collection, tokenId);
        string memory variation = getVariation(collection, tokenId);

        string memory image = string.concat(
            "S",
            Strings.toString(edition),
            "-",
            "P",
            Strings.toString(palette),
            "-",
            variation,
            ".png"
        );

        return
            string.concat(
                "ipfs://ipfs/QmeQi6Ufs4JyrMR54o9TRraKMRhp1MTL2Bn811ad8Y7kK1/",
                image
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

        Attribute[] memory attributes = new Attribute[](5);

        attributes[0] = Attribute({
            key: "Palette",
            value: getPaletteName(palette)
        });

        attributes[1] = Attribute({
            key: "Variation",
            value: getVariation(collection, tokenId)
        });

        uint256 flag = getFlag(collection, tokenId);
        attributes[2] = Attribute({
            key: "Affinity",
            value: flag > 2 ? "Celestial" : flag == 2 ? "Cosmic" : flag == 1
                ? "Mythical"
                : "Citizen"
        });

        attributes[3] = Attribute({
            key: "Era",
            value: isCutoverToken(collection, tokenId)
                ? "Genesis II"
                : "Genesis I"
        });

        attributes[4] = Attribute({
            key: "Signature",
            value: flag > 2 ? Strings.toString(flag) : "(none)"
        });

        return attributes;
    }
}
