// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    // 1,000 tokens with 18 decimals
    uint256 private constant INITIAL_SUPPLY = 1000 * 10 ** 18;

    constructor() ERC20("MyToken", "MTK") Ownable(msg.sender) {
        // Mint initial supply to deployer
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// @notice Owner-only faucet for testing
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
