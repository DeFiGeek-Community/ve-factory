// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import { Test } from "forge-std/Test.sol";

abstract contract TestBase is Test, Proxy {
    struct Function {
        bytes4 selector;
        address implementation;
    }

    mapping(bytes4 => address) internal implementations;
    Function[] internal functions;
    address internal dictionary;
    address target = address(this);

    function _use(bytes4 selector_, address impl_) internal {
        functions.push(Function(selector_, impl_));
        implementations[selector_] = impl_;
    }
    function _implementation() internal view override returns (address) {
        return implementations[msg.sig];
    }
    receive() external payable {}
}