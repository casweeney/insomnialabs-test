// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {MultiUtilityNFT} from "../../src/MulitiUtilityNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { Base } from "../Base.t.sol";

contract MultiUtilityNFTUnitTest is Base {
    function testInitialState() public view {
        assertEq(address(nft.paymentToken()), address(paymentToken));
        assertEq(nft.sablierContractAddress(), address(sablier));
        assertEq(nft.fullMintPrice(), FULL_MINT_PRICE);
        assertEq(nft.discountedMintPrice(), DISCOUNTED_MINT_PRICE);
        assertEq(uint(nft.currentPhase()), uint(MultiUtilityNFT.MintingPhase.InActive));
    }

    function testSetPhase() public {
        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase1);

        assertEq(uint(nft.currentPhase()), uint(MultiUtilityNFT.MintingPhase.Phase1));
        vm.stopPrank();
    }

    function testSetPhase_NonOwner_Reverts() public {
        vm.prank(freeMintUser);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, freeMintUser));
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase1);
    }
}
