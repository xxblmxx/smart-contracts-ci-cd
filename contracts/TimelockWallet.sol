// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title TimelockWallet
/// @notice Holds ETH for a fixed delay, only the designated owner can withdraw once unlocked.
contract TimelockWallet {
    /// @notice Address that can withdraw after the delay
    address public owner;

    /// @notice UNIX timestamp after which funds become withdrawable
    uint256 public releaseTime;

    /// @param _owner         The beneficiary who can withdraw
    /// @param _delaySeconds  Seconds to wait before funds unlock
    constructor(address _owner, uint256 _delaySeconds) payable {
        require(_owner != address(0), "Invalid owner");
        owner = _owner;
        releaseTime = block.timestamp + _delaySeconds;
    }

    /// @notice Withdraw all ETH in this contract to the owner once unlocked
    function withdraw() external {
        require(msg.sender == owner, "Timelock: caller is not owner");
        require(block.timestamp >= releaseTime, "Timelock: not yet unlocked");
        payable(owner).transfer(address(this).balance);
    }

    /// @notice Fallback to receive ETH into the timelock
    receive() external payable {}
}
