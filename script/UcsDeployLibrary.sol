// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Dictionary} from "@ucs/dictionary/Dictionary.sol";
import {Proxy} from "@ucs/proxy/Proxy.sol";
import {FeeDistributorFacade} from "src/interfaces/FeeDistributorFacade.sol";
import {IDictionary} from "@ucs/dictionary/interfaces/IDictionary.sol";

library UcsDeployLibrary {
    function use(address dictionary, bytes4 selector, address target) internal {
        IDictionary(dictionary).setImplementation(selector, target);
    }

    function useFacade(address dictionary, address facade) internal {
        IDictionary(dictionary).upgradeFacade(facade);
    }

    function deployProxy(address dictionary, bytes memory initializerData) internal returns (address) {
        Proxy proxy = new Proxy(dictionary, initializerData);
        return address(proxy);
    }

    function deployDictionary(address admin) internal returns (address) {
        Dictionary dictionary = new Dictionary(admin);
        return address(dictionary);
    }
}
