pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Dapp {
    address token;

    constructor(address _token) {
        token = _token;
    }

    function collectTokens(uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }
}
