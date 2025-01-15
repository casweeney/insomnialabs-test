// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Sablier {
    struct Stream {
        address recipient;
        uint256 deposit;
        address tokenAddress;
        uint256 startTime;
        uint256 stopTime;
        bool exists;
    }

    mapping(uint256 => Stream) public streams;
    uint256 public nextStreamId = 1;

    function createStream(
        address recipient,
        uint256 deposit,
        address tokenAddress,
        uint256 startTime,
        uint256 stopTime
    ) external returns (uint256) {
        require(recipient != address(0), "recipient is zero address");
        require(deposit > 0, "deposit is zero");
        require(startTime >= block.timestamp, "start time before block.timestamp");
        require(stopTime > startTime, "stop time before start time");

        require(
            IERC20(tokenAddress).transferFrom(msg.sender, address(this), deposit),
            "token transfer failed"
        );

        streams[nextStreamId] = Stream({
            recipient: recipient,
            deposit: deposit,
            tokenAddress: tokenAddress,
            startTime: startTime,
            stopTime: stopTime,
            exists: true
        });

        uint256 currentStreamId = nextStreamId;
        nextStreamId += 1;
        return currentStreamId;
    }

    function withdrawFromStream(
        uint256 streamId,
        uint256 amount
    ) external returns (bool) {
        Stream storage stream = streams[streamId];
        require(stream.exists, "stream does not exist");
        require(msg.sender == stream.recipient, "caller is not the recipient");
        require(amount <= calculateStreamedAmount(streamId), "amount exceeds balance");

        require(
            IERC20(stream.tokenAddress).transfer(msg.sender, amount),
            "token transfer failed"
        );

        return true;
    }

    function balanceOf(
        uint256 streamId,
        address who
    ) external view returns (uint256) {
        Stream storage stream = streams[streamId];
        require(stream.exists, "stream does not exist");
        require(who == stream.recipient, "who is not recipient");
        
        return calculateStreamedAmount(streamId);
    }

    function calculateStreamedAmount(uint256 streamId) internal view returns (uint256) {
        Stream storage stream = streams[streamId];
        
        if (block.timestamp <= stream.startTime) {
            return 0;
        }

        if (block.timestamp >= stream.stopTime) {
            return stream.deposit;
        }

        uint256 timeDelta = stream.stopTime - stream.startTime;
        uint256 elapsedTime = block.timestamp - stream.startTime;
        
        return (stream.deposit * elapsedTime) / timeDelta;
    }

    function streamExists(uint256 streamId) external view returns (bool) {
        return streams[streamId].exists;
    }
}