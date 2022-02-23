// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@r-group/shell-contracts/contracts/ShellFactory.sol";
import "@r-group/shell-contracts/contracts/ShellERC721.sol";

contract MockFactory is ShellFactory {}

contract MockCollection is ShellERC721 {}
