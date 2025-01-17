// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {MultiUtilityNFT} from "../../src/MulitiUtilityNFT.sol";
import {PaymentToken} from "../../src/mocks/PaymentToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { Base } from "../Base.t.sol";

contract MulitiUtilityNFTTest is Base {
    function testCreateLockedVesting() public {
        string memory fork_url = vm.envString("MAINNET_FORK_URL");
        uint256 mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);

        vm.startPrank(owner);
        paymentToken = new PaymentToken();
        nft = new MultiUtilityNFT(
            address(paymentToken),
            0x3962f6585946823440d274aD7C719B02b49DE51E, // Ethereum Mainnet Sablier V2 address
            FULL_MINT_PRICE,
            DISCOUNTED_MINT_PRICE
        );
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase3);
        vm.stopPrank();

        vm.startPrank(freeMintUser);
        paymentToken.mint(FULL_MINT_PRICE);
        paymentToken.approve(address(nft), FULL_MINT_PRICE);
        nft.mintWithoutDiscount();
        vm.stopPrank();

        uint256 initialContractBalance = paymentToken.balanceOf(address(nft));
        assertEq(initialContractBalance, FULL_MINT_PRICE, "Incorrect contract balance before stream creation");

        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Vesting);
        vm.expectEmit(false, false, false, false);
        emit VestingStreamCreated(0);
        nft.createLockedVesting();
        
        vm.stopPrank();
    }

    function testCreateLockedVesting_NoBalance_Reverts() public {
        string memory fork_url = vm.envString("MAINNET_FORK_URL");
        uint256 mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);

        vm.startPrank(owner);
        paymentToken = new PaymentToken();
        nft = new MultiUtilityNFT(
            address(paymentToken),
            0x3962f6585946823440d274aD7C719B02b49DE51E,
            FULL_MINT_PRICE,
            DISCOUNTED_MINT_PRICE
        );

        nft.setPhase(MultiUtilityNFT.MintingPhase.Vesting);
        
        vm.expectRevert("No tokens to vest");
        nft.createLockedVesting();
        vm.stopPrank();
    }

    

    function testWithdrawLockedVestedTokens() public {
        string memory fork_url = vm.envString("MAINNET_FORK_URL");
        uint256 mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);

        vm.startPrank(owner);
        paymentToken = new PaymentToken();
        nft = new MultiUtilityNFT(
            address(paymentToken),
            0x3962f6585946823440d274aD7C719B02b49DE51E,
            FULL_MINT_PRICE,
            DISCOUNTED_MINT_PRICE
        );
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase3);
        vm.stopPrank();

        vm.startPrank(freeMintUser);
        paymentToken.mint(FULL_MINT_PRICE);
        paymentToken.approve(address(nft), FULL_MINT_PRICE);
        nft.mintWithoutDiscount();
        vm.stopPrank();

        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Vesting);
        nft.createLockedVesting();

        // Warp time past cliff period
        vm.warp(block.timestamp + 721 days); // Past the total duration of 720 days

        uint256 lockCountId = nft.lockCreationCount();
        uint256 lockId = nft.getLockId(lockCountId);
        uint256 balanceBefore = paymentToken.balanceOf(owner);

        vm.expectEmit(true, false, false, false);
        emit VestingTokensWithdrawn(lockId, 0);
        nft.withdrawLockedVestedTokens(lockId);

        uint256 balanceAfter = paymentToken.balanceOf(owner);
        assertTrue(balanceAfter > balanceBefore, "Balance should increase after withdrawal");

        vm.stopPrank();
    }

    function testWithdrawLockedVestedTokens_NotOwner_Reverts() public {
        string memory fork_url = vm.envString("MAINNET_FORK_URL");
        uint256 mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);

        vm.startPrank(owner);
        paymentToken = new PaymentToken();
        nft = new MultiUtilityNFT(
            address(paymentToken),
            0x3962f6585946823440d274aD7C719B02b49DE51E,
            FULL_MINT_PRICE,
            DISCOUNTED_MINT_PRICE
        );

        nft.setPhase(MultiUtilityNFT.MintingPhase.Vesting);

        vm.stopPrank();

        vm.startPrank(freeMintUser);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, freeMintUser));
        nft.withdrawLockedVestedTokens(1);
        vm.stopPrank();
    }
}
