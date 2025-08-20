// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract SimpleStorage {
    uint256 private value;
    address public owner;

    event ValueChanged(address indexed setter, uint256 newValue);

    constructor(uint256 initialValue) {
        owner = msg.sender;
        value = initialValue;
        emit ValueChanged(msg.sender, initialValue);
    }

    function get() external view returns (uint256) {
        return value;
    }

    function set(uint256 newValue) external {
        value = newValue;
        emit ValueChanged(msg.sender, newValue);
    }
}
