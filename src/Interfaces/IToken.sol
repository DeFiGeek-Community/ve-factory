pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IToken is IERC20 {
    function decimals() external view returns (uint8);
}
